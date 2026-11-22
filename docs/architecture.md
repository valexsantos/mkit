# Architecture

MKIt is a Sinatra REST API (`mkitd`) that deploys containers as services/pods, with HAProxy as ingress, an internal
DNS and a SQLite database (ActiveRecord). `mkit` is the command line client of that API.

## Processes and entry points

* `bin/mkitd`: the server. Mounts `ServicesController`, `MkitJobsController` and `MkitController` as Rack
  middleware around `Sinatra::Application`.
* `bin/mkit`: the client, in `lib/mkit/client/*` (HTTP, unix socket and websocket clients). Commands are declared in
  `lib/mkit/client/commands.yaml`.

## Startup

`MKIt.startup` (`lib/mkit.rb`):

1. `configure`: config dir, SSL, default config copy, self-signed certificate, HAProxy dir; the container runtime is
   configured here (`Container::Registry.configure_from`).
2. DB connection and migrations, default configs.
3. Brings up the host interface (`MKIt::Interface`).
4. Registers the singletons in a `Dry::Container` (`MKIt::System`: `job_manager`, `mkit_dns`, `container_listener`),
   then the workers and sagas.
5. Starts the job manager and the container event listener, then `restore_operation` (recreates the service
   networks, recomputes the services status and restarts HAProxy).

## Async job pipeline

API controllers and the container event listener enqueue `MkitJob` rows (DB backed) with a `topic`. `JobManager`
polls `MkitJob.take` in a thread and hands each job to every worker registered for its topic (`do_the(job)`).

* Workers (`lib/mkit/workers/`, subclasses of `AWorker`) and sagas (`lib/mkit/sagas/`, subclasses of `ASaga`, e.g.
  create/destroy pod) declare their topics in `topics` and register themselves in `initialize`.
* New ones are added in `WorkerManager` / `SagaManager.register_workers`.

## Models

`lib/mkit/app/model/`: `Service` (owns ports, config, resources, ingress with frontends/backends), `Pod`, `Volume`,
`Lease`/`Pool` (IP allocation in the MKIt network, `10.210.198.0/24` by default), `DnsHost`...

Every service gets a dedicated IP on a host interface. The HAProxy configuration is generated from the ERB templates in
`lib/mkit/app/templates/haproxy` into `haproxy.config_dir` (helpers in `app/helpers/haproxy.rb`).

## Container runtime

`lib/mkit/container/`. Everything talks to the runtime through `MKIt::Container::Registry.api`:

```
Container::Api             groups the resources below
 ├─ Containers             run/start/stop/remove/find/exec/logs/log_path/follow_logs/attach_exec
 ├─ Networks               create/find/exists?/attach/detach/remove
 ├─ Volumes                create/find/remove
 └─ Events                 each { |event| }
Container::Docker::*       implementation over the Docker Engine API
Container::Http::UnixClient  generic JSON/HTTP client over a unix socket
```

* The contracts speak **runtime neutral value objects**, never raw runtime payloads: `containers.find` returns a
  `Container::Info` (id, name, `running?`, `tty?`, `ip_on(network)`, exit code, oom, error), `events.each` yields
  `Container::Event`s (kind, action, container id/name, exit code) and pods are described by a `Container::Spec`.
  `Docker::Mapper` and `Docker::Payload` translate from/to the Engine API.
* Runtime and socket come from `mkit.container.{runtime,socket}` (default `docker`; the legacy `mkit.docker.socket`
  is still read).
* Errors are `Container::Error` (with the HTTP `status` when there is one), `NotFound` and `ExecFailed`.
* Listeners (`lib/mkit/pods/`) and sagas receive the containers api by constructor injection, models use
  `Registry.api`.
* To add a runtime (e.g. Podman): implement the four contracts, add a builder to `Registry::BUILDERS` and run
  `spec/container/contracts_spec.rb` against the new classes.

## Pod state is event driven

`ContainerListener` consumes the runtime events in **a single consumer thread**: a handler must never block or sleep.

* `container start` and `network connect` call `Pod#sync_ip(info)`: it stores the ip, updates the DNS and publishes
  `pod_ip_updated`, which makes the `PodWorker` request a new proxy config. There is no polling.
  * a container that no longer exists clears the pod ip (and its DNS record, the DNS server cannot answer with an
    empty address);
  * a container that exists without an ip (stopped, not started yet) keeps the last ip: a stopped pod still counts;
  * the pod is **saved before** the job is published, the worker reads the ip from the database.
* `container die` and `oom` log why the container ended (exit code, oom, runtime error, last output lines).
  `CreatePodSaga` logs why a container could not be created or started.
* `PodReconciler` re-syncs every pod (container id, ip) with the runtime before each subscription to the event
  stream, that is on startup and after every reconnect, and publishes a single `update_proxy_config` per changed
  service. It recovers the events lost while the stream was down.

## HAProxy configuration

A service only has a HAProxy config file while it has **at least one pod with an ip**. `Service#proxy_pods` are the
pods the template renders, `Service#routable?` tells whether there is any; `HAProxyWorker` writes the file and
reloads, or deletes the file when the service is not routable (an invalid file would make HAProxy reject the whole
configuration).

## Repairing a service

`mkit start` and `mkit restart` (stop + start) repair a service: `Service#start` recreates the network and the pods
missing to reach `min_replicas` (`spawn_pods`), and `Pod#start` recreates a container that was removed from outside
(publishing `create_pod_saga`) instead of doing nothing.

## Configuration

Server: `mkit_config.yml` (HAProxy control commands, network, container runtime, DB env, authorized `clients` ids),
`database.yml`, `mkitd_config.sh`; defaults in `config/` and `lib/mkit/config/`. Client: `~/.mkit/mkitc_config.yml`
(`mkit init` registers a client id). Service definitions are YAML, see `samples/apps/`.
