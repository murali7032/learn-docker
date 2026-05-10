# learn-docker

Small **nginx on UBI 9** image used to practice **Dockerfiles**, **builds**, and **containers**. This document explains how the `Dockerfile` works, the theory behind each instruction, and common commands for builds and runtime.

---

## Concepts (theory)

### Image vs container

- **Image** — read-only template built from a `Dockerfile` (layers + metadata). Think: a **class**.
- **Container** — a running (or stopped) instance of an image with its own filesystem/network/process namespace. Think: an **object**.

### Dockerfile role

A **Dockerfile** is a declarative script: each instruction adds a **layer** (cached when inputs unchanged). The **build context** is the directory sent to the daemon (usually `.`); only files in context can be `COPY`/`ADD`’d unless you use remote URLs in `ADD`.

### Layer caching

Order instructions from **least often changing** → **most often changing** (e.g. install packages before copying app code) so rebuilds stay fast. Changing an early line invalidates cache for all following steps.

### `ENTRYPOINT` vs `CMD`

- **`ENTRYPOINT`** — main executable; harder for users to replace; extra `docker run` args are **appended** as arguments to the entrypoint (unless you use `--entrypoint`).
- **`CMD`** — default arguments to the entrypoint, or default command if entrypoint is the shell form.

This project uses **`ENTRYPOINT ["nginx", "-g", "daemon off;"]`** so the container’s primary process is **nginx** in the foreground (correct for Docker: PID 1 should stay in foreground).

### Ports

- **`EXPOSE 80`** — documents intent; **does not publish** the port to the host. You still need **`-p host:container`** on `docker run` to reach the app from your laptop.

### Users and port 80

The container runs **nginx as root** (default user in this image) so it can **bind port 80** and write under **`/var/log/nginx`** and **`/var/lib/nginx`**. Running nginx as a **non-root** user without fixing ownership and cache paths causes **immediate exit** with permission errors in `docker logs`.

---

## This project’s `Dockerfile` (walkthrough)

```dockerfile
FROM docker.io/redhat/ubi9:latest
```

**`FROM`** — base image; every Dockerfile starts here. UBI 9 is Red Hat’s universal base image (RHEL-compatible).

```dockerfile
RUN dnf install nginx -y
```

**`RUN`** — install nginx into the image (build time).

```dockerfile
COPY index.html /usr/share/nginx/html/index.html
```

**`COPY`** — copies from **build context** into the image. On RHEL/nginx packages, the default document root is **`/usr/share/nginx/html`**, not `/var/www/html`. Putting `index.html` here makes nginx serve your page instead of the default test page.

```dockerfile
ARG REDHAT_VERSION
ENV REDHAT_VERSION=${REDHAT_VERSION}
```

- **`ARG`** — build-time variable (can be passed with `--build-arg`). Not available at runtime unless copied into **`ENV`** or a file.
- **`ENV`** — runtime environment variable inside the container (and visible to child processes).

```dockerfile
WORKDIR /app
```

**`WORKDIR`** — creates directory if needed and sets default working directory for later `RUN`, `CMD`, `ENTRYPOINT`, and `docker exec` defaults.

```dockerfile
EXPOSE 80
```

**`EXPOSE`** — documents that the app listens on 80 inside the container.

```dockerfile
ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

**`ENTRYPOINT` (exec form)** — PID 1 is `nginx` with the given flags; keeps nginx in foreground.

---

## Dockerfile instruction cheat sheet

| Instruction | When it runs | Purpose |
|-------------|--------------|---------|
| `FROM` | Build | Base image |
| `RUN` | Build | Shell commands (packages, compile) |
| `COPY` | Build | Copy files from context into image (preferred over `ADD` for plain files) |
| `ADD` | Build | Like `COPY` + tar auto-extract + URLs (use sparingly) |
| `WORKDIR` | Build | Set working directory |
| `ENV` | Build + runtime | Environment variables |
| `ARG` | Build only | Build arguments (`--build-arg`) |
| `EXPOSE` | Metadata | Document ports (no publish by itself) |
| `VOLUME` | Metadata/runtime | Declare mount points |
| `USER` | Build + runtime | User for processes |
| `ENTRYPOINT` / `CMD` | Runtime default | Process and args |

---

## Commands: build

From this directory (`Docker/learn-docker`):

```bash
# Standard build, tag as myfirstimage:v1
docker build -t myfirstimage:v1 .

# No cache (debug Dockerfile changes)
docker build --no-cache -t myfirstimage:v1 .

# Pass build-arg (matches ARG REDHAT_VERSION)
docker build -t myfirstimage:v1 --build-arg REDHAT_VERSION=9.4 .

# Build for another platform (e.g. from Apple Silicon to amd64)
docker build -t myfirstimage:v1 --platform linux/amd64 .
```

Inspect what you built:

```bash
docker image ls myfirstimage
docker image history myfirstimage:v1
docker inspect myfirstimage:v1 --format '{{json .Config.Entrypoint}} {{json .Config.Env}}'
```

---

## Commands: run containers

**Important:** Docker CLI flags (`-p`, `--name`, `-d`, `-e`, …) must appear **before** the image name. Anything **after** the image name is passed as **arguments to the entrypoint** (here: extra `nginx` args—not what you want for `-p` / `--name`).

```bash
# Foreground (see logs in terminal; Ctrl+C stops)
docker run --rm -p 8080:80 myfirstimage:v1

# Detached + name + publish
docker run -d -p 8080:80 --name mkreddy myfirstimage:v1

# Override entrypoint temporarily (debug shell)
docker run --rm -it --entrypoint bash myfirstimage:v1

# Pass environment at run time
docker run --rm -p 8080:80 -e REDHAT_VERSION=9 myfirstimage:v1
```

Lifecycle and inspection:

```bash
docker ps
docker ps -a
docker logs mkreddy
docker logs -f mkreddy
docker exec -it mkreddy bash   # if bash exists and user can access
docker stop mkreddy
docker rm mkreddy
```

---

## Commands: cleanup and disk

```bash
docker container prune    # remove stopped containers
docker image prune        # dangling images
docker system df          # disk usage
docker rmi myfirstimage:v1
```

---

## Troubleshooting (this lab)

1. **Default nginx page instead of `index.html`** — wrong path: use **`/usr/share/nginx/html`** for RHEL `nginx` package (this repo’s `Dockerfile` already does).
2. **`nginx: invalid option: "-"`** — you ran `docker run myfirstimage:v1 --name x -p ...` (flags after image). Move **all** Docker flags **before** the image name.
3. **Permission denied on `/var/log/nginx` or `/var/lib/nginx/tmp`** — nginx was running as a user without rights to those paths, or could not bind port 80; this lab image runs as **root** inside the container so nginx starts cleanly.

---

## Optional: `.dockerignore`

Add a `.dockerignore` file next to the `Dockerfile` to exclude files from the build context (smaller uploads, fewer accidental secrets):

```
.git
*.md
```

---

## Official references

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [docker build CLI](https://docs.docker.com/reference/cli/docker/build/)
- [docker run CLI](https://docs.docker.com/reference/cli/docker/container/run/)
