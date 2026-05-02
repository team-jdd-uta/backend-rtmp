#!/bin/sh
set -e
: "${RTMP_CALLBACK_SECRET:=rtmp-dev-secret}"
export RTMP_CALLBACK_SECRET
envsubst '${RTMP_CALLBACK_SECRET}' \
  < /etc/nginx/nginx.conf.template \
  > /etc/nginx/nginx.conf
exec nginx -g 'daemon off;'
