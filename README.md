## docker-immich

[![docker hub](https://img.shields.io/badge/docker_hub-link-blue?style=for-the-badge&logo=docker)](https://hub.docker.com/r/hydaz/immich) ![docker image size](https://img.shields.io/docker/image-size/hydaz/immich?style=for-the-badge&logo=docker) [![auto build](https://img.shields.io/badge/docker_builds-automated-blue?style=for-the-badge&logo=docker?color=d1aa67)](https://github.com/hydazz/docker-immich/actions?query=workflow%3A"Auto+Builder+CI")

This is a highly experimental adaptation of immich that runs in a single container (except postgres).
My main goal is to have a single image for unraid environments (screw docker-compose). i also hope to keep the size of this image to a minimum.

todo:
validate supplied variables
attempt to shrink the image (anything is better than 1GB compressed :0)

## Usage

```bash
docker run -d \
  --name=immich \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Australia/Melbourne \
  -e DB_HOSTNAME=192.168.1.2 \ # postgres host
  -e DB_USERNAME=postgres \ # postgres username
  -e DB_PASSWORD=postgres \ # postgres password
  -e DB_DATABASE_NAME=immich \ # postgres db name
  -e JWT_SECRET= \ # run openssl rand -base64 128
  -p 2283:8080 \
  -v <path to appdata>:/config \ # appdata mainly for logs - i was hoping to get postgres into the image as well but seems like a mission
  --restart unless-stopped \
  hydaz/immich
```
