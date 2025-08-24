# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-immich:latest

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
ARG NODEJS_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV \
  IMMICH_BUILD_DATA="/app/immich/server" \
  IMMICH_ENV="production" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  SHARP_FORCE_GLOBAL_LIBVIPS="true" \
  TRANSFORMERS_CACHE="/config/machine-learning/models" \
  UV_PYTHON="/usr/bin/python3.11"

RUN \
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
  if [ -z "${NODEJS_VERSION}" ]; then \
    NODEJS_VERSION="$(cat /tmp/immich/server/.nvmrc)" && \
    echo "**** detected node version ${NODEJS_VERSION} ****"; \
  fi && \
  NODEJS_MAJOR_VERSION=$(echo "$NODEJS_VERSION" | cut -d '.' -f 1) && \
  NODEJS_VERSION="${NODEJS_VERSION}-1nodesource1" && \
  echo "**** setup repos ****" && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_${NODEJS_MAJOR_VERSION}.x nodistro main" >>/etc/apt/sources.list.d/node.list && \
  curl -s "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | gpg --dearmor | tee /usr/share/keyrings/nodesource-repo.gpg >/dev/null && \
  echo "deb [signed-by=/usr/share/keyrings/deadsnakes.gpg] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main" >>/etc/apt/sources.list.d/deadsnakes.list && \
  curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | gpg --dearmor | tee /usr/share/keyrings/deadsnakes.gpg >/dev/null && \
  echo "**** install build packages ****" && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    build-essential \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libjpeg-dev \
    librsvg2-dev \
    libspng-dev \
    pkg-config \
    python3.11-dev && \
  echo "**** install runtime packages ****" && \
  apt-get install --no-install-recommends -y \
    nodejs=$NODEJS_VERSION \
    python3.11 && \
  echo "**** install pnpm via corepack ****" && \
  npm install --global corepack@latest && \
  corepack enable pnpm && \
  echo "**** build server ****" && \
  mkdir -p \
    /tmp/node_modules && \
  cd /tmp/immich && \
  SHARP_IGNORE_GLOBAL_LIBVIPS=true pnpm --filter immich --frozen-lockfile install && \
  rm -rf server/node_modules/@img/sharp-libvips* && \
  rm -rf server/node_modules/@img/sharp-linuxmusl-x64 && \
  cp -r \
    server/node_modules/@img \
    server/node_modules/exiftool-vendored.pl \
    /tmp/node_modules && \
  pnpm --filter immich build && \
  pnpm --filter immich --prod --no-optional deploy /tmp/server-pruned && \
  cp -r \
    /tmp/node_modules/@img \
    /tmp/node_modules/exiftool-vendored.pl \
    /tmp/server-pruned/node_modules && \
  pnpm store prune && \
  cp -a \
    server/resources \
    server/bin \
    /tmp/server-pruned && \
  cp -r /tmp/server-pruned/* /app/immich/server && \
  echo "**** build open-api ****" && \
  cd /tmp/immich && \
  pnpm --filter @immich/sdk --frozen-lockfile install && \
  pnpm --filter @immich/sdk build && \
  echo "**** build web ****" && \
  mkdir -p \
    /app/immich/server/www && \
  cd /tmp/immich && \
  pnpm --filter @immich/sdk --filter immich-web --frozen-lockfile --force install && \
  pnpm --filter @immich/sdk --filter immich-web build && \
  cp -a \
    web/build/* \
    web/static \
    /app/immich/server/www  && \
  echo "**** build CLI ****" && \
  mkdir -p \
    /app/immich/cli && \
  cd /tmp/immich && \
  pnpm --filter @immich/sdk --filter @immich/cli --frozen-lockfile install && \
  pnpm --filter @immich/sdk --filter @immich/cli build && \
  pnpm --filter @immich/cli --prod --no-optional deploy /tmp/cli-pruned && \
  cp -r /tmp/cli-pruned/* /app/immich/cli && \
  ln -s ../cli/bin/immich /app/immich/server/bin/immich && \
  echo "**** build machine-learning ****" && \
  mkdir -p \
    /app/immich/machine-learning/ann && \
  cd /tmp/immich/machine-learning && \
  if [ -z ${UV_VERSION} ]; then \
    UV_VERSION=$(curl -sL https://api.github.com/repos/astral-sh/uv/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/uv.tar.gz -L \
    "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" && \
  tar xf \
    /tmp/uv.tar.gz -C \
    /tmp --strip-components=1 && \
  /tmp/uv sync --active --frozen --extra cpu --no-dev --no-editable --no-install-project --compile-bytecode --no-progress && \
  cp -a \
    immich_ml \
    pyproject.toml \
    uv.lock \
    /app/immich/machine-learning && \
  echo "**** cleanup ****" && \
  for cleanfiles in *.pyc *.pyo; do \
    find /usr/local/lib/python3.* /usr/lib/python3.* /lsiopy/lib/python3.* -name "${cleanfiles}" -delete; \
  done && \
  apt-get remove -y --purge \
    build-essential \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libhwy-dev \
    libjpeg-dev \
    librsvg2-dev \
    libspng-dev \
    libwebp-dev \
    pkg-config \
    python3.11-dev && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /etc/apt/sources.list.d/node.list \
    /root/.cache \
    /root/.local/share/pnpm \
    /tmp/* \
    /usr/share/keyrings/nodesource-repo.gpg \
    /var/lib/apt/lists/* \
    /var/tmp/*

# copy local files
COPY root/ /

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /libraries
