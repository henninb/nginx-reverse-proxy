#!/bin/sh

echo set -gx DOCKER_HOST tcp://192.168.10.10:2375
echo export DOCKER_HOST=tcp://192.168.10.10:2375
echo export DOCKER_HOST=ssh://henninb@192.168.10.10
#
docker context create remote --docker "host=ssh://henninb@192.168.10.10"
echo docker context use remote
docker context ls

docker build -t nginx-reverse-proxy .

docker save nginx-reverse-proxy | docker --context remote load

echo export DOCKER_HOST=ssh://henninb@192.168.10.10
# export DOCKER_HOST=tcp://192.168.10.10:2375
export DOCKER_HOST=ssh://192.168.10.10
docker rm -f nginx-reverse-proxy
docker run --name=nginx-reverse-proxy -h nginx-reverse-proxy -h nginx-reverse-proxy --restart unless-stopped -p 443:443 -d nginx-reverse-proxy
docker ps -a
# docker rm -f nginx-reverse-proxy

exit 0
