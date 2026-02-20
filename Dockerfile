# FROM nginx:1.27.3-alpine
FROM nginx:alpine

RUN rm /etc/nginx/nginx.conf

# COPY ./nginx.conf /etc/nginx/conf.d/default.conf
COPY ./nginx.conf /etc/nginx/nginx.conf
# COPY ./proxy.crt /etc/ssl/certs/
# COPY ./proxy.key /etc/ssl/private/

COPY --chmod=644 ./bhenning.fullchain.pem /etc/ssl/certs/
COPY --chmod=644 ./brianhenning.fullchain.pem /etc/ssl/certs/

COPY --chmod=640 --chown=root:nginx ./bhenning.privkey.pem /etc/ssl/private/
COPY --chmod=640 --chown=root:nginx ./brianhenning.privkey.pem /etc/ssl/private/

# RUN mkdir -p /usr/local/share/ca-certificates
# COPY ./rootCA.pem /usr/local/share/ca-certificates/rootCA.pem
RUN apk update
RUN apk add -q --no-cache ca-certificates libcap

# Allow nginx binary to bind to privileged ports as nonroot
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Ensure nginx user can write to temp/cache directories
RUN chown -R nginx:nginx /var/cache/nginx /var/run

USER nginx

# ENTRYPOINT ["/bin/sh", "-c" , "echo 127.0.0.1 proxy.bhenning.com >> /etc/hosts && exec nginx -g 'daemon off;'" ]
