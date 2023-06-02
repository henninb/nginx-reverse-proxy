FROM nginx:1.23.4-alpine

RUN rm /etc/nginx/nginx.conf

# COPY ./nginx.conf /etc/nginx/conf.d/default.conf
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./proxy.crt /etc/ssl/certs/
COPY ./proxy.key /etc/ssl/private/

# ENTRYPOINT ["/bin/sh", "-c" , "echo 127.0.0.1 proxy.bhenning.com >> /etc/hosts && exec nginx -g 'daemon off;'" ]
