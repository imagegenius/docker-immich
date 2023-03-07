FROM ghcr.io/imagegenius/baseimage-alpine:3.17

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV IMMICH_MACHINE_LEARNING_URL=false \
  IMMICH_WEB_URL="http://127.0.0.1:3000" \
  MMICH_SERVER_URL="http://127.0.0.1:3001" \
  PUBLIC_IMMICH_SERVER_URL="http://127.0.0.1:3001" \
  TYPESENSE_DATA_DIR="/config/typesense" \
  TYPESENSE_API_KEY="xyz" \
  TYPESENSE_HOST="127.0.0.1" \
  TYPESENSE_VERSION="0.24.0"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    g++ \  
    make \
    vips-dev && \  
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    ffmpeg \
    libheif \
    nginx \
    nodejs \
    npm \
    openssl \
    perl \
    vips \
    vips-cpp && \
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
  echo "**** download typesense server ****" && \
  mkdir -p \
    /app/typesense && \
  curl -o  \
    /tmp/typesense.tar.gz -L \
    https://dl.typesense.org/releases/${TYPESENSE_VERSION}/typesense-server-${TYPESENSE_VERSION}-linux-amd64.tar.gz && \
  tar -xf \
    /tmp/typesense.tar.gz -C \
    /app/typesense && \
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
  echo "**** setup upload folder ****" && \
  mkdir -p \
    /photos && \
  ln -s \
    /photos \
    /app/immich/server/upload && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    /root/.cache \
    /root/.npm

# environment settings
ENV NODE_ENV="production" \
  HOME="/config"

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads
