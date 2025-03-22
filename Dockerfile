# FROM nginx:1.27.3-alpine
FROM nginx:alpine

RUN rm /etc/nginx/nginx.conf

# COPY ./nginx.conf /etc/nginx/conf.d/default.conf
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./proxy.crt /etc/ssl/certs/
COPY ./proxy.key /etc/ssl/private/
COPY ./bhenning.fullchain.pem /etc/ssl/certs/
COPY ./bhenning.privkey.pem /etc/ssl/private/
COPY ./brianhenning.fullchain.pem /etc/ssl/certs/
COPY ./brianhenning.privkey.pem /etc/ssl/private/

RUN mkdir -p /usr/local/share/ca-certificates
COPY ./rootCA.pem /usr/local/share/ca-certificates/rootCA.pem
RUN apk update
RUN apk add -q --no-cache ca-certificates
RUN update-ca-certificates

# ENTRYPOINT ["/bin/sh", "-c" , "echo 127.0.0.1 proxy.bhenning.com >> /etc/hosts && exec nginx -g 'daemon off;'" ]
