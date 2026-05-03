FROM alfg/nginx-rtmp:v1.6.0

RUN apk add --no-cache gettext

COPY nginx/nginx.conf /etc/nginx/nginx.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 1935 80

ENTRYPOINT ["/docker-entrypoint.sh"]
