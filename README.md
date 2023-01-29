<!-- DO NOT EDIT THIS FILE MANUALLY  -->

# [imagegenius/immich](https://github.com/imagegenius/docker-immich)

[![GitHub Release](https://img.shields.io/github/release/imagegenius/docker-immich.svg?color=007EC6&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/imagegenius/docker-immich/releases)
[![GitHub Package Repository](https://shields.io/badge/GitHub%20Package-blue?logo=github&logoColor=ffffff&style=for-the-badge)](https://github.com/imagegenius/docker-immich/packages)
[![Docker Hub](https://shields.io/badge/Docker%20Hub-blue?logo=docker&logoColor=ffffff&style=for-the-badge)](https://hub.docker.com/r/imagegenius/immich)
![Image Size](https://img.shields.io/docker/image-size/imagegenius/immich/latest.svg?color=007EC6&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=docker)
[![Jenkins Build](https://img.shields.io/jenkins/build?labelColor=555555&logoColor=ffffff&style=for-the-badge&jobUrl=https%3A%2F%2Fci.imagegenius.io%2Fjob%2FDocker-Pipeline-Builders%2Fjob%2Fdocker-immich%2Fjob%2Fmain%2F&logo=jenkins)](https://ci.imagegenius.io/job/Docker-Pipeline-Builders/job/docker-immich/job/main/)
[![IG CI](https://img.shields.io/badge/dynamic/yaml?color=007EC6&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=CI&query=CI&url=https%3A%2F%2Fci-tests.imagegenius.io%2Fimagegenius%2Fimmich%2Flatest-main%2Fci-status.yml)](https://ci-tests.imagegenius.io/imagegenius/immich/latest-main/index.html)

[Immich](https://immich.app/) - High performance self-hosted photo and video backup solution.

[![immich](https://user-images.githubusercontent.com/27055614/182044984-2ee6d1ed-c4a7-4331-8a4b-64fcde77fe1f.png)](https://immich.app/)

## Supported Architectures

We use Docker manifest for cross-platform compatibility. More details can be found on [Docker's website](https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md#manifest-list).

To obtain the appropriate image for your architecture, simply pull `ghcr.io/imagegenius/immich:latest`. Alternatively, you can also obtain specific architecture images by using tags.

This image supports the following architectures:

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| x86-64 | ✅ | amd64-\<version tag\> |
| arm64 | ✅ | arm64v8-\<version tag\> |

## Version Tags

This image offers different versions via tags. Be cautious when using unstable or development tags, and read their descriptions carefully.

| Tag | Available | Description |
| :----: | :----: |--- |
| latest | ✅ | Latest Immich release with an Ubuntu base. |
| noml | ✅ | Latest Immich release with an Alpine base. Machine-learning is completly removed. (tinnny image), use this if your CPU does not support AVX |

## Application Setup

The WebUI can be found at `http://your-ip:8080`. Follow the wizard to set up Immich.

Immich requires that you have PostgreSQL 14 and Redis setup externally.

Follow these steps if you need help setting up Redis or PostgreSQL.

#### Redis:

Redis can be ran within the container using a docker-mod or you can use an external Redis server/container.

If you don't need to use Redis elsewhere add this environment variable: `DOCKER_MODS=imagegenius/mods:universal-redis`, and set `REDIS_HOSTNAME` to `localhost`.

Or within a seperate container:

```bash
docker run -d \
  --name=redis \
  -p 6379:6379 \
  redis
```

#### PostgreSQL 14:

(A docker-mod for postgres is in the making)

```bash
docker run -d \
  --name=postgres14 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=immich \
  -v path_to_postgres:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:14
```

### Unraid: Migrate from docker-compose

**⚠️ Pre-read all these steps before doing anying, if you are confused open an issue.**

When using the official Immich docker-compose, the PostgreSQL data is stored in a docker volume which _should_ be located at `/var/lib/docker/volumes/pgdata/_data`. Before preceeding you **must** stop the docker-compose stack.

#### 1. Move the database

To move the PostgreSQL data to the unraid array run:

```bash
mv /var/lib/docker/volumes/pgdata/_data /mnt/user/appdata/postgres14
```

Install `postgresql14` from the Unraid CA and remove these variables from the template: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`.
The database is already initialised and these variables don't do anything.
Also set `Database Storage Path` to `/mnt/user/appdata/postgres14`.

#### 2. Move the uploads

In the docker-compose .env you would have set the `UPLOAD_LOCATION`, copy that down and use it below:

**⚠️ Note that Immich created the `uploads` folder within the `UPLOAD_LOCATION`.**

```bash
mv <upload_location>/uploads /mnt/user/<elsewhere>
```

#### 3. Setup the `imagegenius/immich` container

Search the unraid CA for `immich`, choose either `CorneliousJD`'s or `vcxpz`'s templates (`vcxpz` is the official imagegenius template).

**⚠️ You must configure the template to the values listed in the docker-compose .env**

Ensure that the template matches the `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME` and `JWT_SECRET` from the .env. Set `Path: /photos` to `/mnt/user/<elsewhere>`.

Click Apply, Open the WebUI and login. Everything _Should_ be as it was.

## Usage

Example snippets to start creating a container:

### Docker Compose

```yaml
---
version: "2.1"
services:
  immich:
    image: ghcr.io/imagegenius/immich:latest
    container_name: immich
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Australia/Melbourne
      - DB_HOSTNAME=192.168.1.x
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgres
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=redis
      - JWT_SECRET=somelongrandomstring
      - DB_PORT=5432 #optional
      - REDIS_PORT=6379 #optional
      - REDIS_PASSWORD= #optional
    volumes:
      - path_to_appdata:/config
      - path_to_photos:/photos
    ports:
      - 8080:8080
    restart: unless-stopped
```

### Docker CLI ([Click here for more info](https://docs.docker.com/engine/reference/commandline/cli/))

```bash
docker run -d \
  --name=immich \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Australia/Melbourne \
  -e DB_HOSTNAME=192.168.1.x \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=redis \
  -e JWT_SECRET=somelongrandomstring \
  -e DB_PORT=5432 `#optional` \
  -e REDIS_PORT=6379 `#optional` \
  -e REDIS_PASSWORD= `#optional` \
  -p 8080:8080 \
  -v path_to_appdata:/config \
  -v path_to_photos:/photos \
  --restart unless-stopped \
  ghcr.io/imagegenius/immich:latest
```

## Container Variables

To configure the container, pass variables at runtime using the format `<external>:<internal>`. For instance, `-p 8080:80` exposes port `80` inside the container, making it accessible outside the container via the host's IP on port `8080`.

| Variable | Description |
| :----: | --- |
| `-p 8080` | WebUI Port |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e TZ=Australia/Melbourne` | Specify a timezone to use eg. Australia/Melbourne. |
| `-e DB_HOSTNAME=192.168.1.x` | PostgreSQL Host |
| `-e DB_USERNAME=postgres` | PostgreSQL Username |
| `-e DB_PASSWORD=postgres` | PostgreSQL Password |
| `-e DB_DATABASE_NAME=immich` | PostgreSQL Database Name |
| `-e REDIS_HOSTNAME=redis` | Redis Hostname |
| `-e JWT_SECRET=somelongrandomstring` | Run `openssl rand -base64 128` |
| `-e DB_PORT=5432` | PostgreSQL Port |
| `-e REDIS_PORT=6379` | Redis Port |
| `-e REDIS_PASSWORD=` | Redis password |
| `-v /config` | Contains the logs |
| `-v /photos` | Contains all the photos uploaded to Immich |

## Umask for running applications

All of our images allow overriding the default umask setting for services started within the containers using the optional -e UMASK=022 option. Note that umask works differently than chmod and subtracts permissions based on its value, not adding. For more information, please refer to the Wikipedia article on umask [here](https://en.wikipedia.org/wiki/Umask).

## User / Group Identifiers

To avoid permissions issues when using volumes (`-v` flags) between the host OS and the container, you can specify the user (`PUID`) and group (`PGID`). Make sure that the volume directories on the host are owned by the same user you specify, and the issues will disappear.

Example: `PUID=1000` and `PGID=1000`. To find your PUID and PGID, run `id user`.

```bash
  $ id username
    uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```

## Updating the Container

Most of our images are static, versioned, and require an image update and container recreation to update the app. We do not recommend or support updating apps inside the container. Check the [Application Setup](#application-setup) section for recommendations for the specific image.

Instructions for updating containers:

### Via Docker Compose

* Update all images: `docker-compose pull`
  * or update a single image: `docker-compose pull immich`
* Let compose update all containers as necessary: `docker-compose up -d`
  * or update a single container: `docker-compose up -d immich`
* You can also remove the old dangling images: `docker image prune`

### Via Docker Run

* Update the image: `docker pull ghcr.io/imagegenius/immich:latest`
* Stop the running container: `docker stop immich`
* Delete the container: `docker rm immich`
* Recreate a new container with the same docker run parameters as instructed above (if mapped correctly to a host folder, your `/config` folder and settings will be preserved)
* You can also remove the old dangling images: `docker image prune`

## Versions

* **26.01.23:** - add unraid migration to readme
* **26.01.23:** - use find to apply chown to /app, excluding node_modules
* **26.01.23:** - enable ci testing
* **24.01.23:** - fix services starting prematurely, causing permission errors.
* **23.01.23:** - add noml image to readme and add aarch64 image to readme, make github release stable
* **21.01.23:** - BREAKING: Redis is removed. Update missing param_env_vars & opt_param_env_vars for redis & postgres
* **02.01.23:** - Initial Release.
