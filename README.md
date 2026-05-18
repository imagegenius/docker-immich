# [imagegenius/immich](https://github.com/imagegenius/docker-immich)

[![GitHub Release](https://img.shields.io/github/release/imagegenius/docker-immich.svg?color=007EC6&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/imagegenius/docker-immich/releases)
[![GitHub Package Repository](https://shields.io/badge/GitHub%20Package-blue?logo=github&logoColor=ffffff&style=for-the-badge)](https://github.com/imagegenius/docker-immich/packages)

Immich is a high performance self-hosted photo and video backup solution.

[![immich](https://raw.githubusercontent.com/immich-app/immich/main/design/immich-logo-inline-dark.png)](https://immich.app/)

## Variants

| Tag        | Description                         | Platforms    |
| ---------- | ----------------------------------- | ------------ |
| `latest`   | Ubuntu + ML (CPU)                   | amd64, arm64 |
| `noml`     | Ubuntu, ML disabled (smaller image) | amd64, arm64 |
| `cuda`     | Ubuntu + ML with NVIDIA CUDA        | amd64        |
| `openvino` | Ubuntu + ML with Intel OpenVINO     | amd64        |

Pin a specific upstream Immich release with the semver tag, optionally with the variant suffix:

```
ghcr.io/imagegenius/immich:2.7.5
ghcr.io/imagegenius/immich:2.7.5-cuda
```

## Requirements

- **PostgreSQL**: Version 14-17 with [VectorChord](https://github.com/tensorchord/VectorChord) — use [`ghcr.io/immich-app/postgres`](https://github.com/immich-app/base-images/pkgs/container/postgres) to skip extension setup.
- **Valkey/Redis**: External or via docker mod (see below). SSL Postgres via `DB_URL`.

### Docker Mod for Redis

- Set `DOCKER_MODS=imagegenius/mods:universal-redis`
- Set `REDIS_HOSTNAME=localhost`

## Usage

### Docker Compose

```yaml
---
services:
  immich:
    image: ghcr.io/imagegenius/immich:latest
    container_name: immich
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - DB_HOSTNAME=192.168.1.x
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgres
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=192.168.1.x
      - DB_PORT=5432 #optional
      - REDIS_PORT=6379 #optional
      - REDIS_PASSWORD= #optional
      - SERVER_HOST=0.0.0.0 #optional
      - SERVER_PORT=8080 #optional
      - MACHINE_LEARNING_HOST=0.0.0.0 #optional
      - MACHINE_LEARNING_PORT=3003 #optional
      - MACHINE_LEARNING_WORKERS=1 #optional
      - MACHINE_LEARNING_WORKER_TIMEOUT=120 #optional
    volumes:
      - path_to_appdata:/config
      - path_to_photos:/photos
      - path_to_libraries:/libraries #optional
    ports:
      - 8080:8080
    restart: unless-stopped

  valkey:
    image: valkey/valkey:8-bookworm
    container_name: valkey
    ports:
      - 6379:6379

  postgres14:
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
    container_name: postgres14
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: immich
      # Uncomment if not on SSDs:
      # DB_STORAGE_TYPE: 'HDD'
    volumes:
      - path_to_postgres:/var/lib/postgresql/data
    ports:
      - 5432:5432
```

## Parameters

| Parameter                                | Function                                                                                     |
| ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| `-p 8080`                                | WebUI Port                                                                                   |
| `-e PUID=1000`                           | UID for permissions — see below                                                              |
| `-e PGID=1000`                           | GID for permissions — see below                                                              |
| `-e TZ=Etc/UTC`                          | Timezone, see [this list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) |
| `-e DB_HOSTNAME=192.168.1.x`             | PostgreSQL host                                                                              |
| `-e DB_USERNAME=postgres`                | PostgreSQL username                                                                          |
| `-e DB_PASSWORD=postgres`                | PostgreSQL password                                                                          |
| `-e DB_DATABASE_NAME=immich`             | PostgreSQL database                                                                          |
| `-e REDIS_HOSTNAME=192.168.1.x`          | Redis/Valkey host                                                                            |
| `-e DB_PORT=5432`                        | PostgreSQL port                                                                              |
| `-e REDIS_PORT=6379`                     | Redis port                                                                                   |
| `-e REDIS_PASSWORD=`                     | Redis password                                                                               |
| `-e SERVER_HOST=0.0.0.0`                 | Immich server bind host                                                                      |
| `-e SERVER_PORT=8080`                    | Immich server port                                                                           |
| `-e MACHINE_LEARNING_HOST=0.0.0.0`       | ML server bind host                                                                          |
| `-e MACHINE_LEARNING_PORT=3003`          | ML server port                                                                               |
| `-e MACHINE_LEARNING_WORKERS=1`          | ML worker count                                                                              |
| `-e MACHINE_LEARNING_WORKER_TIMEOUT=120` | ML worker timeout                                                                            |
| `-v /config`                             | App config; ML model cache (~1.5GB with defaults)                                            |
| `-v /photos`                             | Immich photo library                                                                         |
| `-v /libraries`                          | External libraries to track                                                                  |

## Hardware Acceleration

### Intel (QSV / OpenVINO)

- Mount `/dev/dri` into the container (`--device=/dev/dri:/dev/dri`).
- For OpenVINO, verify [CPU support](https://docs.openvino.ai/2024/about-openvino/system-requirements.html); also add `--device-cgroup-rule='c 189:* rmw' -v /dev/bus/usb:/dev/bus/usb`.

### NVIDIA (CUDA)

1. Install the [NVIDIA container toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
2. Run with `--runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all` or `--gpus=all`.

## Existing Libraries

- Mount the library folder at `/libraries` (or `/libraries/<user>` for multi-user).
- In Immich admin settings, register `/libraries` (or per-user) as an external path.
- In account settings, add a library pointing to `/libraries` or `/libraries/<user>`.

## User / Group IDs & umask

Set `PUID=1000` `PGID=1000` to match volume ownership on the host (`id user` to find yours). Optionally `UMASK=022` (works subtractively, not additively).

## Updating

```bash
docker pull ghcr.io/imagegenius/immich:latest
docker stop immich && docker rm immich
# recreate with the same docker run parameters
docker image prune  # optional: remove dangling images
```

Or with compose: `docker compose pull && docker compose up -d`.

## Support

- Issues: <https://github.com/imagegenius/docker-immich/issues>
- Immich: <https://immich.app>

## How this image is built

This repo is built with GitHub Actions, based on the workflow shape from [home-operations/containers](https://github.com/home-operations/containers).

- The container starts from [linuxserver/docker-baseimage-ubuntu](https://github.com/linuxserver/docker-baseimage-ubuntu).
- Immich's upstream media dependency scripts run in this Dockerfile, then the app and variant stages build on top.
- Variants are selected by [`docker-bake.hcl`](docker-bake.hcl).
- s6-overlay bits live under [`root/`](root).
- Renovate tracks Immich and build input bumps from the bake annotations.
