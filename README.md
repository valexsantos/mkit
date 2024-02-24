# MKIt - Micro Kubernetes on Ruby

This is micro kubernetes(tm) on Ruby(tm), a simple tool to deploy containers to mimic a (very) minimalistic k8 cluster with a nice REST API.

It's also a frontend for `docker`, providing an easier way for your services to be locally available, without the need to care about local `ports` availability.

It contains an internal DNS and uses HAProxy for routing/balancing/fail-over for Pods access.
The database is a simple sqlite3 db and the server is a Sinatra based application.

A client is also included to access the API, e.g. `mkitc ps`.

The daemon is responsible for HAProxy pods routing configuration. It also provides the cluster DNS and manages the internal host interface and the docker instances. 

## Requirements

* Ruby
* HAProxy
* Docker
* Linux (iproute2 package)

**Note:** in order to have **ssl support**, you must install `openssl-dev` libs (e.g. `libssl-dev`) prior to install MKIt gem.

## Install

This is a simple ruby gem, so to install execute:
```
# gem install mkit
```

## Configuration

### Server configuration

On startup, [the server configuration](config) will be created on `/etc/mkit`.

The server will available by default on `https://localhost:4567` but you can configure server startup parameters on `/etc/mkit/mkitd_config.sh`

Please check [systemd](samples/systemd) or [daemontools](samples/daemontools) directories for more details.

```
# /etc/mkit/mkitd_config.sh
#
# mkitd server options (for systemd unit | daemontools)
#
OPTIONS=""
# e.g. OPTIONS="-b 0.0.0.0"
```
HAProxy config directory and control commands are defined on [mkit_config.yml](config/mkit_config.yml)

```
# /etc/mkit/mkit_config.yml - mkit server configuration file. 
mkit:
  my_network:
    ip: 10.210.198.1
  haproxy:
    config_dir: /etc/haproxy/haproxy.d
    ctrl:
      start:   systemctl start   haproxy
      stop:    systemctl stop    haproxy
      reload:  systemctl reload  haproxy
      restart: systemctl restart haproxy
      status:  systemctl status  haproxy
  database:
    env: development
  clients:
    - id: client_1_id
    - id: client_2_id
    - ...
```

You must configure `haproxy` to use config directory. for example on Ubuntu:

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

#### Authorization

To access MKIt server API, you must add each client `id` to server configuration:

```
# /etc/mkit/mkit_config.yml - mkit server configuration file. 
mkit:
  my_network:
...
  clients:
    - id: client_1_id
    - id: client_2_id
    - ...
```

### Client configuration

On `mkitc` first call, default configuration will be copied to `$HOME/.mkit` with `local`default profile set.

You must call `mkitc init` to initialize client configuration.

Client identification key (`my_id`) will be generated, printed out to console and saved to the client's configuration file.

You may edit the local configuration file to add more servers and change active profile with `$mkitc profile set <profile_name>`, e.g. `$mkitc profile set server_2`

```
# ~/.mkit/mkitc_config.yml
mkit:
  local: 
    server.uri: https://localhost:4567
  server_2:  # you can add more servers. change the client active profile with mkitc profile command
    server.uri: https://192.168.29.232:4567
my_id: unique_id # this id is generated running mkitc init
```

### Service

```
service:
  name: rabbitmq # unique
  image: rabbitmq:3-management-alpine # image
  network: bridge # docker network - it will be created if it does not exists
  ports:  # haproxy port mapping
          #   <external_port>:[internal_port]:<tcp|http>:[round_robin (default)|leastconn]
          # to define a range on `external_port`, leave `internal_port` blank
          #   - 5000-5100::tcp:round_robin
          #   range on `internal_port` is not supported
          # ssl suport
          #   <external_port>:[internal_port]:<tcp|http>:round_robin|leastconn[:ssl[,<cert.pem>(mkit.pem default)>]]
          #   e.g.
          #  - 443:80:http:round_robin:ssl # uses mkitd default crt file (mkit.pem)
          #  - 443:80:http:round_robin:ssl,/etc/pki/foo.pem # custom crt file full path
    - 5672:5672:tcp:round_robin
    - 80:15672:http:round_robin
  resources:
    min_replicas: 1 # default value
    max_replicas: 1 # default value
  volumes:
    - docker://mkit_rabbitmq_data:/var/lib/rabbitmq # a docker volume - it will be created if it does not exists
    - /var/log/rabbitmq/logs:/var/log/rabbitmq # a local volume
  environment:
    RABBITMQ_DEFAULT_USER: admin
    RABBITMQ_DEFAULT_PASS: admin
    RABBITMQ_DEFAULT_VHOST: mkit
```

## Running

The `mkitd server daemon` requires `root` user (due to `ip` and `haproxy`).
After installing the gem, server and client will be available on host.
```
# mkitd  --help
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

There's also samples for [systemd](samples/systemd) and [daemontools](samples/daemontools) as well for some miscellaneous [spps](samples/apps).

### Accessing the API

A client is provided to interact with MKIt server.

Run `mkitc help` for a list of current supported commands.

```
Usage: mkitc <command> [options]

Micro k8s on Ruby - a simple tool to mimic a (very) minimalistic k8 cluster

Commands:

init       init mkit client
ps         show services status (alias for status)
status     show services status
logs       prints service logs
start      start service
stop       stop service
restart    restart service
create     create new service
update     update service
rm         remove service
version    prints mkit server version
proxy      haproxy status and control
profile    mkit client configuration profile

Run 'mkitc help <command>' for specific command information.
```

Example:

```
$ mkitc ps
+----+-------+---------------+-------------------+--------------+---------+
| id | name  |     addr      |       ports       |     pods     | status  |
+----+-------+---------------+-------------------+--------------+---------+
| 1  | mongo | 10.210.198.10 | tcp/27017         | 106e2b59cb11 | RUNNING |
| 2  | nexus | 10.210.198.11 | http/80,https/443 | 68e239e5102a | RUNNING |
+----+-------+---------------+-------------------+--------------+---------+
```
The service `mongo` is available on IP `10.210.198.10:27017`
The service `nexus` is available on IP `10.210.198.11:80` and on port `443` with ssl.

## Development

* build the gem
  * `rake package`
* console
  * `rake console`

# Thanks

For my kids. :) 
