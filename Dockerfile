FROM docker.io/redhat/ubi9:latest

RUN useradd appuser

RUN dnf install nginx -y

# RHEL/nginx package default root is /usr/share/nginx/html (not /var/www/html).
COPY index.html /usr/share/nginx/html/index.html

ARG REDHAT_VERSION

ENV REDHAT_VERSION=${REDHAT_VERSION}

WORKDIR /app

EXPOSE 80

USER appuser

ENTRYPOINT ["nginx", "-g", "daemon off;"]
