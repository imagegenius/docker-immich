# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-immich:latest AS build

ARG IMMICH_VERSION
ARG LATEST_UBUNTU_VERSION="resolute"
ARG NODEJS_VERSION
ARG UV_VERSION

ENV \
  IMMICH_BUILD_DATA="/app/immich/data" \
  IMMICH_ENV="production" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  SHARP_FORCE_GLOBAL_LIBVIPS="true" \
  TRANSFORMERS_CACHE="/config/machine-learning/models" \
  UV_PYTHON="/usr/bin/python3.11" \
  MISE_TRUSTED_CONFIG_PATHS="/app/immich/plugins/mise.toml" \
  MISE_DATA_DIR="/buildcache/mise" \
  NODE_OPTIONS="--max-old-space-size=8192"

RUN \
  echo "**** download immich ****" && \
  mkdir -p \
    /app/immich \
    /tmp/immich && \
  if [ -z "${IMMICH_VERSION}" ]; then \
    IMMICH_VERSION=$(curl -sL https://api.github.com/repos/immich-app/immich/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/immich.tar.gz -L \
    "https://github.com/immich-app/immich/archive/${IMMICH_VERSION}.tar.gz" && \
  tar xf \
    /tmp/immich.tar.gz -C \
    /tmp/immich --strip-components=1 && \
  cp \
    /tmp/immich/server/.nvmrc \
    /tmp/.nvmrc && \
  if [ -z "${NODEJS_VERSION}" ]; then \
    NODEJS_VERSION="$(cat /tmp/.nvmrc)" && \
    echo "**** detected node version ${NODEJS_VERSION} ****"; \
  fi && \
  NODEJS_MAJOR_VERSION=$(echo "${NODEJS_VERSION}" | cut -d '.' -f 1) && \
  NODEJS_VERSION="${NODEJS_VERSION}-1nodesource1" && \
  echo "**** setup repos ****" && \
  echo "deb http://archive.ubuntu.com/ubuntu ${LATEST_UBUNTU_VERSION} main restricted universe multiverse" > /etc/apt/sources.list.d/immich.list && \
  printf "Package: *\nPin: release n=${LATEST_UBUNTU_VERSION}\nPin-Priority: 450\n" > /etc/apt/preferences.d/preferences && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_${NODEJS_MAJOR_VERSION}.x nodistro main" > /etc/apt/sources.list.d/node.list && \
  curl -s \
    "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | \
    gpg --dearmor | tee /usr/share/keyrings/nodesource-repo.gpg >/dev/null && \
  echo "deb [signed-by=/usr/share/keyrings/deadsnakes.gpg] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main" > /etc/apt/sources.list.d/deadsnakes.list && \
  curl -s \
    "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | \
    gpg --dearmor | tee /usr/share/keyrings/deadsnakes.gpg >/dev/null && \
  mkdir -p \
    /etc/apt/keyrings && \
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.pub] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list && \
  curl -fSs \
    "https://mise.jdx.dev/gpg-key.pub" | tee /etc/apt/keyrings/mise-archive-keyring.pub >/dev/null && \
  echo "**** install packages ****" && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libjpeg-dev \
    libspng-dev \
    pkg-config \
    python3.11-dev \
    mise && \
  apt-get install --no-install-recommends -y -t ${LATEST_UBUNTU_VERSION} \
    libhwy-dev \
    librsvg2-dev \
    libsharpyuv-dev \
    libwebp-dev \
    libwebp7 \
    libtiff6 \
    dcraw \
    libwebpdemux2 \
    libwebpmux3 && \
  apt-get install --no-install-recommends -y \
    nodejs="${NODEJS_VERSION}" \
    python3.11 && \
  echo "**** setup pnpm ****" && \
  npm install --global corepack@latest && \
  corepack enable pnpm && \
  echo "**** setup plugins (mise) ****" && \
  mkdir -p \
    /app/immich/plugins && \
  cp \
    /tmp/immich/plugins/mise.toml \
    /app/immich/plugins && \
  mise install --cd /app/immich/plugins && \
  echo "**** build plugins (mise) ****" && \
  cp -a \
    /tmp/immich/plugins/. \
    /app/immich/plugins && \
  cp -a \
    /tmp/immich/.pnpmfile.cjs \
    /tmp/immich/pnpm-lock.yaml \
    /tmp/immich/pnpm-workspace.yaml \
    /app/immich/plugins && \
  sed -i 's/pnpm install --frozen-lockfile/pnpm install --no-frozen-lockfile/' /app/immich/plugins/mise.toml && \
  cd /app/immich/plugins && \
  mise run build && \
  echo "**** build server ****" && \
  cd /tmp/immich && \
  SHARP_IGNORE_GLOBAL_LIBVIPS=true pnpm \
    --filter immich \
    --frozen-lockfile \
    build && \
  SHARP_FORCE_GLOBAL_LIBVIPS=true pnpm \
    --filter immich \
    --frozen-lockfile \
    --prod \
    --no-optional \
    deploy /app/immich/server && \
  echo "**** build web ****" && \
  SHARP_IGNORE_GLOBAL_LIBVIPS=true pnpm \
    --filter @immich/sdk \
    --filter immich-web \
    --frozen-lockfile \
    --force install && \
  pnpm \
    --filter @immich/sdk \
    --filter immich-web \
    build && \
  echo "**** build CLI ****" && \
  pnpm \
    --filter @immich/sdk \
    --filter @immich/cli \
    --frozen-lockfile \
    install && \
  pnpm \
    --filter @immich/sdk \
    --filter @immich/cli \
    build && \
  pnpm \
    --filter @immich/cli \
    --prod \
    --no-optional \
    deploy /app/immich/cli && \
  echo "**** install core plugins ****" && \
  mkdir -p \
    /app/immich/data/corePlugin \
    /app/immich/data/www && \
  cp -a \
    /app/immich/plugins/dist \
    /app/immich/data/corePlugin/dist && \
  cp -a \
    /tmp/immich/plugins/manifest.json \
    /app/immich/data/corePlugin/manifest.json && \
  cp -a \
    /tmp/immich/web/build/. \
    /app/immich/data/www && \
  echo "**** copy scripts ****" && \
  mkdir -p \
    /app/immich/machine-learning \
    /app/immich/server/bin && \
  cp -a \
    /tmp/immich/server/bin/get-cpus.sh \
    /tmp/immich/server/bin/immich-healthcheck \
    /tmp/immich/server/bin/start.sh \
    /app/immich/server/bin && \
  ln -s \
    ../../cli/bin/immich \
    /app/immich/server/bin/immich && \
  apt-get clean && \
  rm -rf \
    /var/lib/apt/lists/*

FROM python:3.11-bookworm AS machine-learning

ARG UV_VERSION

ENV \
  UV_PYTHON="/usr/local/bin/python3.11"

RUN \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    curl \
    g++ \
    jq && \
  apt-get clean && \
  rm -rf \
    /var/lib/apt/lists/*

COPY --from=build /tmp/immich/machine-learning /tmp/immich/machine-learning

WORKDIR /tmp/immich/machine-learning

RUN \
  if [ -z "${UV_VERSION}" ]; then \
    UV_VERSION=$(curl -sL https://api.github.com/repos/astral-sh/uv/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/uv.tar.gz -L \
    "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" && \
  tar xf \
    /tmp/uv.tar.gz -C \
    /tmp --strip-components=1 && \
  /tmp/uv venv \
    /lsiopy \
    --python "${UV_PYTHON}" && \
  . /lsiopy/bin/activate && \
  /tmp/uv sync \
    --active \
    --frozen \
    --extra cpu \
    --no-dev \
    --no-editable \
    --no-install-project \
    --compile-bytecode \
    --no-progress && \
  rm -rf \
    /tmp/uv \
    /tmp/uv.tar.gz

FROM ghcr.io/imagegenius/baseimage-immich:latest

# set version label
ARG BUILD_DATE
ARG VERSION
ARG NODEJS_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV \
  IMMICH_BUILD_DATA="/app/immich/data" \
  IMMICH_ENV="production" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  PATH="${PATH}:/app/immich/server/bin" \
  PYTHONDONTWRITEBYTECODE="1" \
  PYTHONPATH="/app/immich/machine-learning" \
  PYTHONUNBUFFERED="1" \
  SHARP_FORCE_GLOBAL_LIBVIPS="true" \
  TRANSFORMERS_CACHE="/config/machine-learning/models" \
  VIRTUAL_ENV="/lsiopy" \
  NODE_OPTIONS="--max-old-space-size=8192"

COPY --from=build /tmp/.nvmrc /tmp/.nvmrc
COPY --from=build /app/immich /app/immich
COPY --from=machine-learning /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=machine-learning /usr/local/bin/python3.11 /usr/local/bin/python3.11
COPY --from=machine-learning /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=machine-learning /usr/local/lib/libpython3.11.so /usr/local/lib/libpython3.11.so
COPY --from=machine-learning /usr/local/lib/libpython3.11.so.1.0 /usr/local/lib/libpython3.11.so.1.0
COPY --from=machine-learning /lsiopy /lsiopy
COPY --from=machine-learning /tmp/immich/machine-learning /app/immich/machine-learning

RUN \
  if [ -z "${NODEJS_VERSION}" ]; then \
    NODEJS_VERSION="$(cat /tmp/.nvmrc)" && \
    echo "**** detected node version ${NODEJS_VERSION} ****"; \
  fi && \
  NODEJS_MAJOR_VERSION=$(echo "${NODEJS_VERSION}" | cut -d '.' -f 1) && \
  NODEJS_VERSION="${NODEJS_VERSION}-1nodesource1" && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_${NODEJS_MAJOR_VERSION}.x nodistro main" > /etc/apt/sources.list.d/node.list && \
  curl -s \
    "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | \
    gpg --dearmor | tee /usr/share/keyrings/nodesource-repo.gpg >/dev/null && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    nodejs="${NODEJS_VERSION}" && \
  ldconfig /usr/local/lib && \
  apt-get clean && \
  rm -rf \
    /etc/apt/sources.list.d/node.list \
    /tmp/.nvmrc \
    /usr/share/keyrings/nodesource-repo.gpg \
    /var/lib/apt/lists/*

# copy local files
COPY root/ /

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /photos /libraries
