## docker-immich

[![docker hub](https://img.shields.io/badge/docker_hub-link-blue?style=for-the-badge&logo=docker)](https://hub.docker.com/r/hydaz/immich) ![docker image size](https://img.shields.io/docker/image-size/hydaz/immich?style=for-the-badge&logo=docker) [![auto build](https://img.shields.io/badge/docker_builds-automated-blue?style=for-the-badge&logo=docker?color=d1aa67)](https://github.com/hydazz/docker-immich/actions?query=workflow%3A"Auto+Builder+CI")

**This image has been adapted from [immich-app/immich](https://github.com/immich-app/immich/)**

[Immich](https://immich.app/) - High performance self-hosted photo and video backup solution

This is a highly experimental adaptation of Immich that runs in a single container (except Postgres).
My main goal is to have a single image for Unraid environments (screw docker-compose). I also hope to keep the size of this image to a minimum.

I have tested this image with over 15000 photos/videos using `immich upload` with no issues.

You will need to create a Postgres 14 container to use with Immich

Todo:

- [x] Validate supplied variables
- [ ] Attempt to shrink the image (anything is better than 1GB compressed :0)
- [x] Cleanup container scripts
- [x] Migrate to s6v3

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

[![template](https://img.shields.io/badge/unraid_template-ff8c2f?style=for-the-badge&logo=docker?color=d1aa67)](https://github.com/hydazz/docker-templates/blob/main/hydaz/immich.xml)

## Upgrading Immich

To upgrade, all you have to do is pull the latest Docker image. We automatically check for Immich updates daily. When a new version is released, we build and publish an image both as a version tag and on `:latest`.
