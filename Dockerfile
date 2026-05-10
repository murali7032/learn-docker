FROM docker.io/redhat/ubi9:latest

RUN dnf install nginx -y

# RHEL/nginx package default root is /usr/share/nginx/html (not /var/www/html).
COPY index.html /usr/share/nginx/html/index.html

ARG REDHAT_VERSION

ENV REDHAT_VERSION=${REDHAT_VERSION}

WORKDIR /app

EXPOSE 80

# Run as root so nginx can bind :80 and write logs/cache dirs under /var/log/nginx and /var/lib/nginx.
# For production, use a non-root pattern (custom config on 8080 + chowned dirs, or official nginx image).
ENTRYPOINT ["nginx", "-g", "daemon off;"]
