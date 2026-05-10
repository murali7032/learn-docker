FROM docker.io/redhat/ubi9:latest

RUN dnf install nginx -y

# RHEL/nginx package default root is /usr/share/nginx/html (not /var/www/html).
COPY index.html /usr/share/nginx/html/index.html

WORKDIR /app

EXPOSE 80

ENTRYPOINT ["nginx", "-g", "daemon off;"]
