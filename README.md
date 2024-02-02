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

A client is provided to interact with mkit server.

```
Usage: mkitc <command> [options]

Micro k8s on Ruby - a simple tool to mimic a (very) minimalistic k8 cluster

Commands:

ps         show services status (alias for status)
status     show services status
start      start service
stop       stop service
restart    restart service
create     create new service
update     update service
version    prints mkit server version
proxy      haproxy status and control

Run 'mkitc help <command>' for specific command information.
```

Example:

```
$ mkitc ps postgres
+----+----------+---------------+----------+--------------+---------+
| id |   name   |     addr      |  ports   |     pods     | status  |
+----+----------+---------------+----------+--------------+---------+
| 2  | postgres | 10.210.198.10 | tcp/4532 | 49b5e4c8f247 | RUNNING |
+----+----------+---------------+----------+--------------+---------+
```
The service `postgres` is available on IP `10.210.198.10:5432`

## Configuration

On startup, configuration files on `config` directory will be copied to `/etc/mkit`. HAProxy config directory and control commands are defined on `mkit_config.yml`

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
  ports:  # haproxy port mapping
          #   <external_port>:[internal_port]:<tcp|http>:[round_robin (default)|leastconn]
          # to define a range on `external_port`, leave `internal_port` blank
          #   - 5000-5100::tcp:round_robin
          # range on `internal_port` is not supported 
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

## Development

* build the gem
  * `rake package`
* console
  * `rake console`

# Thanks

For my kids. :) 
