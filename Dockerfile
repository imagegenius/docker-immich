# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-alpine:3.18

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
ARG IMMICH_CLI_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV PUBLIC_IMMICH_SERVER_URL="http://127.0.0.1:3001" \
  IMMICH_MACHINE_LEARNING_URL="false" \
  IMMICH_MEDIA_LOCATION="/photos"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    g++ \  
    make \
    vips-dev && \  
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    ffmpeg \
    imagemagick-dev \
    libraw-dev \
    nginx \
    nodejs \
    npm \
    openssl \
    perl \
    python3 \
    py3-pip \
    vips \
    vips-cpp \
    vips-heif \
    vips-jxl \
    vips-magick && \
  echo "**** download immich ****" && \
  mkdir -p \
    /tmp/immich && \
  if [ -z ${IMMICH_VERSION} ]; then \
    IMMICH_VERSION=$(curl -sL https://api.github.com/repos/immich-app/immich/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/immich.tar.gz -L \
    "https://github.com/immich-app/immich/archive/${IMMICH_VERSION}.tar.gz" && \
  tar xf \
    /tmp/immich.tar.gz -C \
    /tmp/immich --strip-components=1 && \
  echo "**** download immich-cli ****" && \
  mkdir -p \
    /tmp/cli && \
  if [ -z ${IMMICH_CLI_VERSION} ]; then \
    IMMICH_CLI_VERSION=$(curl -sL https://api.github.com/repos/immich-app/CLI/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/cli.tar.gz -L \
    "https://github.com/immich-app/CLI/archive/${IMMICH_CLI_VERSION}.tar.gz" && \
  tar xf \
    /tmp/cli.tar.gz -C \
    /tmp/cli --strip-components=1 && \
  echo "**** install pip dependencies ****" && \
  pip install --break-system-packages -U --no-cache-dir \
    psycopg2-binary && \
  echo "**** build cli ****" && \
  cd /tmp/cli && \
  mkdir -p \
    /app/immich/cli && \
  npm ci && \
  npm run build && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    bin \
    /app/immich/cli && \
  echo "**** build server ****" && \
  cd /tmp/immich/server && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev --omit=optional && \
  npm link && \
  npm cache clean --force && \
  mkdir -p \
    /app/immich/server && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/server && \
  echo "**** build web ****" && \
  cd /tmp/immich/web && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev && \
  mkdir -p \
    /app/immich/web && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    build \
    static \
    /app/immich/web && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    /root/.cache \
    /root/.npm

# environment settings
ENV NODE_ENV="production"

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads
