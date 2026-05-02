FROM alfg/nginx-rtmp:latest

COPY nginx/nginx.conf /etc/nginx/nginx.conf

EXPOSE 1935 80

ENTRYPOINT ["nginx", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
