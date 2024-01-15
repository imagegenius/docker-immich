# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-immich:latest

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning" \
  TRANSFORMERS_CACHE="/config/machine-learning" \
  SERVER_PORT="8080" \
  IMMICH_WEB_ROOT="/app/immich/server/www" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

RUN \
  echo "**** install build packages ****" && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    autoconf \
    bc \
    build-essential \
    g++ \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libgsf-1-dev \
    libheif-dev \
    libjpeg-dev \
    libjxl-dev \
    libltdl-dev \
    liborc-0.4-dev \
    librsvg2-dev \
    libspng-dev \
    libtool \
    libwebp-dev \
    make \
    meson \
    ninja-build \
    pkg-config \
    python3-dev \
    wget && \
  echo "**** install runtime packages ****" && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    python3 \
    python3-pip \
    python3-venv && \
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
  echo "**** download immich dependencies ****" && \
  mkdir -p \
    /tmp/immich-dependencies && \
  curl -o \
    /tmp/immich-dependencies.tar.gz -L \
    "https://github.com/immich-app/base-images/archive/main.tar.gz" && \
  tar xf \
    /tmp/immich-dependencies.tar.gz -C \
    /tmp/immich-dependencies --strip-components=1 && \
  echo "**** build server ****" && \
  mkdir -p \
    /app/immich/server \
    /tmp/sharp && \
  cd /tmp/immich/server && \
  npm ci && \
  rm -rf node_modules/@img/sharp-libvips* && \
  rm -rf node_modules/@img/sharp-linuxmusl-x64 && \
  cp -r \
    node_modules/@img \
    /tmp/sharp && \
  npm run build && \
  npm prune --omit=dev --omit=optional && \
  cp -r \
    /tmp/sharp/@img \
    node_modules && \
  npm link && \
  npm cache clean --force && \
  cp -a \
    resources \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/server && \
  echo "**** build open-api ****" && \
  cd /tmp/immich/open-api/typescript-sdk && \
  npm ci && \
  npm run build && \
  echo "**** build web ****" && \
  mkdir -p \
    /app/immich/server/www && \
  cd /tmp/immich/web && \
  npm ci && \
  npm run build && \
  cp -a \
    build/* \
    static \
    /app/immich/server/www  && \
  echo "**** build machine-learning ****" && \
  mkdir -p \
    /app/immich/machine-learning/ann && \
  cd /tmp/immich/machine-learning && \
  pip install --break-system-packages -U --no-cache-dir \
    poetry && \
  python3 -m venv /lsiopy && \
  poetry config installer.max-workers 10 && \
  poetry config virtualenvs.create false && \
  poetry install --sync --no-interaction --no-ansi --no-root --only main && \
  cp -a \
    app \
    log_conf.json \
    /app/immich/machine-learning && \
  cp -a \
    ann/ann.py \
    /app/immich/machine-learning/ann && \
  echo "**** install immich cli (immich upload) ****" && \
    npm install -g --prefix /tmp/cli @immich/cli && \
    mv /tmp/cli/lib/node_modules/@immich/cli /app/cli && \
  echo "**** cleanup ****" && \
  for cleanfiles in *.pyc *.pyo; do \
    find /usr/local/lib/python3.* /usr/lib/python3.* /lsiopy/lib/python3.* -name "${cleanfiles}" -delete; \
  done && \
  apt-get remove -y --purge \
    autoconf \
    bc \
    build-essential \
    cpanminus \
    g++ \
    git \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libgsf-1-dev \
    libheif-dev \
    libglib2.0-dev \
    libgsf-1-dev \
    libheif-dev \
    libjpeg-dev \
    libjxl-dev \
    libltdl-dev \
    liborc-0.4-dev \
    librsvg2-dev \
    libspng-dev \
    libtool \
    libwebp-dev \
    make \
    meson \
    ninja-build \
    pkg-config \
    python3-dev \
    unzip \
    wget && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/tmp/* \
    /var/lib/apt/lists/* \
    /root/.cache \
    /root/.npm

# copy local files
COPY root/ /

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads /import
