# MKIt - Micro Kubernetes on Ruby

This is micro kubernetes(tm) on Ruby(tm), a simple tool to deploy containers to mimic a (very) minimalistic k8 cluster with a nice REST API.

It contains an internal DNS and uses HAProxy for routing/balancing/fail-over for Pods access.
The database is a simple sqlite3 db and the server is a Sinatra based application.

A client is also included to access the API, e.g. `mkitc ps`.

The daemon is responsible for HAProxy pods routing configuration. It also provides the cluster DNS and manages the internal host interface and the docker instances. 

## Requirements

* Ruby
* HAProxy
* Docker
* Linux (iproute2 package)

## Install

This is a simple ruby gem, so to install run
```
# gem install mkit
```

## Running

The `daemon` requires `root` user (due to `ip` and `haproxy`), you can run it directly on the repository root...

```
# ./mkitd  --help
Usage: mkitd [options]
    -c config-dir                    set the config dir (default is /etc/mkit)
    -p port                          set the port (default is 4567)
    -b bind                          specify bind address (e.g. /tmp/app.sock)
    -s server                        specify rack server/handler
    -q                               turn on quiet mode (default is off)
    -x                               turn on the mutex lock (default is off)
    -e env                           set the environment (default is development)
    -o addr                          set the host (default is (env == 'development' ? 'localhost' : '0.0.0.0'))
   
```

or after the `gem install mkit-<version>.gem`. The server and client will be installed on host.

```
# mkitd
...
 0.65s     info: MKIt is up and running! [ec=0xbe0] [pid=45804] [2023-12-29 15:46:04 +0000]
```

There's also samples on the samples dir, for daemontools and systemd.

### Accessing the API

* Create new service
  * `mkitc create samples/apps/rabbitmq.yml`
* Update service
  * `mkitc update samples/apps/rabbitmq.yml`
* Get service
  * `mkitc ps {id|service_name}`
* Delete service
  * `mkitc rm {id|service_name}`
* List services
  * `mkitc ps [-v (verbose)]`
* Control service
  * `mkitc start {id|service_name}`
  * `mkitc stop {id|service_name}`

Example:

```
$ mkitc ps postgres
id      name                 addr             ports                      status
4       postgres             10.210.198.10    tcp/5432                   RUNNING
  pods
    id      pod_id            pod_name          pod_ip            status
    19      4ce31a007211      5d148a16f3aa      172.17.0.2        RUNNING
```
The service `postgres` is available on IP `10.210.198.10:5432`

## Configuration

On startup, configuration files on `config` directory will be copied to `/etc/mkit`. HAProxy config dir and control commands are defined on `mkit_config.yml`

You must configure `haproxy` to use config directory. e.g. on Ubuntu

```
# /etc/default/haproxy

# Defaults file for HAProxy
#
# This is sourced by both, the initscript and the systemd unit file, so do not
# treat it as a shell script fragment.

# Change the config file location if needed
CONFIG="/etc/haproxy/haproxy.d"

# Add extra flags here, see haproxy(1) for a few options
#EXTRAOPTS="-de -m 16"
```

### Service

```
service:
  name: rabbitmq # unique
  image: rabbitmq:3-management-alpine # image
  network: bridge # docker network - it will be created if it does not exists
  ports:  # haproxy port mapping: <external_port>|<internal_port>|<tcp|http>|round_robin
    - 5672:5672:tcp:round_robin
    - 80:15672:http:round_robin
  resources:
    max_replicas: 1
    min_replicas: 1
  volumes:
    - docker://mkit_rabbitmq_data:/var/lib/rabbitmq # a docker volume - it will be created if it does not exists
    - /var/log/rabbitmq/logs:/var/log/rabbitmq # a local volume
  environment:
    RABBITMQ_DEFAULT_USER: admin
    RABBITMQ_DEFAULT_PASS: admin
    RABBITMQ_DEFAULT_VHOST: mkit
```

## Development

* build the gem
  * `rake package`
* console
  * `rake console`

# Thanks

For my kids. :) 
