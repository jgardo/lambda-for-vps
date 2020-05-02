# Lambda-for-vps
Simple service forwarding request to docker containers. If there is a request to container and container is down, it's starting it on demand. After serving request it's scheduled to be killed after some time of idle.

## Requirements
This service requires `docker` and `docker-compose`.
It uses local docker instance and it's local `/var/run/docker.sock` to administrate containers.

It depends on [`portainer`](https://www.portainer.io/) and [`openresty` (`nginx`)](https://openresty.org/en/)

## User guide

`Lambda-for-vps` (shortcut `L4v`) starts by executing command

    docker-compose -f docker-compose.yml up

 in root of project.

By default services managed by `L4v` are lazy loaded, so on startup there are no additional actions.

On first request to service there are few steps to do:

1. (if necessary) Initialize local environment to manage docker.

    `L4v` uses `portainer` to manage containers. So firstly `L4v` initializes admin using environments `portainerLogin` which is default `admin` and `portainerPassword` with default `adminpassword`. It also creates `local` "portainer endpoint".
If you want to check what's inside `portainer` it's available on port `9000`. 

2. (if necessary) Deploy given `docker-compose.yml` configured for this request.
3. Making sure that requested endpoint is up. If it's not, then it restarts all containers within `docker-compose.yml` configured for this request.
4. (if necessary) Wait configured amount of seconds, so all containers can be started and initialzed.
5. Serving request.
6. Schedule killing all services after configured amount of seconds. If there are another request services will be killed amount of seconds after last request.
7. If time is up, there are sended `docker stop` to all containers within `docker-compose.yml`.

## Developer guide

By default there is an example of configuration for simple `hello-world` docker instance.

After startup example `hello-world` is available at [http://localhost:80/hello-world](http://localhost:80/hello-world). It can take a while because docker image have to be downloaded, extracted and launched. However next request should take less time.

Docker configuration is placed in file `config/app/hello-world/docker-compose.yml`.

`L4v` is based on `OpenResty` project, which is a kind of wrapper for `nginx`. So configuration of endpoints are given in file `config/nginx/conf.d/default.conf`.

Example `hello-world` application has such entry in `default.conf`

    location /hello-world {
        # MIME type determined by default_type:
        default_type 'text/plain';
        set $ip "";
        set $port "8080";
        access_by_lua_file /hello-world/hello-world-app.lua;
        proxy_pass http://$ip:$port/;
    }

Setting `ip` are crucial, because `ip` depends on inner docker container `ip` and is evaluated during startup.

Whole administration of request is in line `access_by_lua_file /hello-world/hello-world-app.lua;`. It's execution maintenance of whole `docker-compose` life.

By default such maintenance looks like that:

    local initializer = require('initializer')
    local killer = require('killer')

    local initParams = {
        stackName = "hello", -- informative name of app used in Portainer
        afterRestartSleep = 2, -- constant time in seconds to wait for 
                        -- initialization of container after starting it
        killAfter = 15, -- time in seconds to kill all containers in docker-compose 
                        -- after last request
        dockerComposeFilePath = "/hello-world/docker-compose.yml" 
                        -- path to docker-compose.yml file to be deployed 
    }
    initializer.init(initParams);
    initializer.updateTimeToKill(initParams);

    killer.scheduleKilling(initParams)

Crucial part of this snippet is definition of `initParams`. Rest may remain unchanged.
