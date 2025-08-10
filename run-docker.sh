#!/bin/sh

echo set -gx DOCKER_HOST tcp://192.168.10.10:2375
echo export DOCKER_HOST=tcp://192.168.10.10:2375
echo export DOCKER_HOST=ssh://henninb@192.168.10.10

# doas cp /etc/letsencrypt/live/finance.bhenning.com/privkey.pem finance.bhenning.privkey.pem
# doas cp /etc/letsencrypt/live/finance.bhenning.com/fullchain.pem finance.bhenning.fullchain.pem
# doas chown henninb:henninb *.pem

docker context create remote --docker "host=ssh://henninb@192.168.10.10"
# echo docker context use remote
# docker context ls

docker build -t nginx-reverse-proxy .

# docker save nginx-reverse-proxy | docker --context remote load

# echo export DOCKER_HOST=ssh://henninb@192.168.10.10
# export DOCKER_HOST=tcp://192.168.10.10:2375
# export DOCKER_HOST=ssh://192.168.10.10
docker rm -f nginx-reverse-proxy
docker run --name=nginx-reverse-proxy -h nginx-reverse-proxy --restart unless-stopped -p 2223:2223 -p 443:443 -d nginx-reverse-proxy
#
# docker rm -f nginx-reverse-proxy
docker commit nginx-reverse-proxy nginx-reverse-proxy
docker save nginx-reverse-proxy | docker --context remote load
export DOCKER_HOST=ssh://192.168.10.10
docker rm -f nginx-reverse-proxy
docker run --name=nginx-reverse-proxy -h nginx-reverse-proxy --restart unless-stopped -p 2223:2223 -p 443:443 -d nginx-reverse-proxy
docker ps -a

exit 0
