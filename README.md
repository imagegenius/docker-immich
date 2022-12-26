## docker-immich

[![docker hub](https://img.shields.io/badge/docker_hub-link-blue?style=for-the-badge&logo=docker)](https://hub.docker.com/r/hydaz/immich) ![docker image size](https://img.shields.io/docker/image-size/hydaz/immich?style=for-the-badge&logo=docker) [![auto build](https://img.shields.io/badge/docker_builds-automated-blue?style=for-the-badge&logo=docker?color=d1aa67)](https://github.com/hydazz/docker-immich/actions?query=workflow%3A"Auto+Builder+CI")

This is a highly experimental adaptation of immich that runs in a single container (except postgres).
My main goal is to have a single image for unraid environments (screw docker-compose). i also hope to keep the size of this image to a minimum.

## Usage

all variables listed here are required to be valid and present otherwise things will get messy
```bash
docker run -d \
  --name=immich \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Australia/Melbourne \
  -e DB_HOSTNAME=192.168.1.2 \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=localhost \ # redis is build in, dont change
  -e JWT_SECRET=somelongsecret \
  -e NODE_ENV=production \ # dont change
  -p 8080:8080 \
  -v <path to appdata>:/config \ # appdata mainly for longs - i was hoping to get postgres into the image as well but seems like a mission
  --restart unless-stopped \
  hydaz/immich
```
