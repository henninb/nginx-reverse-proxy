#!/bin/sh

openssl x509 -enddate -noout -in /home/henninb/projects/github.com/henninb/nginx-reverse-proxy/bhenning.fullchain.pem
openssl x509 -enddate -noout -in /home/henninb/projects/github.com/henninb/nginx-reverse-proxy/brianhenning.fullchain.pem

exit 0
