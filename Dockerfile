FROM docker.io/redhat/ubi9:latest

RUN dnf install nginx curl -y

COPY index.html /var/www/html/index.html

WORKDIR /app

EXPOSE 80

ENTRYPOINT ["nginx", "-g", "daemon off;"]
