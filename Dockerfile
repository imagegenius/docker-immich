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
  IMMICH_ENV="production" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  IMMICH_PORT="8080" \
  IMMICH_REVERSE_GEOCODING_ROOT="/app/immich/server/geodata" \
  IMMICH_WEB_ROOT="/app/immich/server/www" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  TRANSFORMERS_CACHE="/config/machine-learning/models"

RUN \
  echo "**** install build packages ****" && \
  echo "deb [signed-by=/usr/share/keyrings/deadsnakes.gpg] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main" >>/etc/apt/sources.list.d/deadsnakes.list && \
  curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | gpg --dearmor | tee /usr/share/keyrings/deadsnakes.gpg >/dev/null && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    build-essential \
    python3.10-dev \
    python3.10-venv \
    python3-pip && \
  echo "**** install runtime packages ****" && \
  apt-get install --no-install-recommends -y \
    python3.10 && \
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
  echo "**** build server ****" && \
  mkdir -p \
    /tmp/node_modules && \
  cd /tmp/immich/server && \
  npm ci && \
  rm -rf node_modules/@img/sharp-libvips* && \
  rm -rf node_modules/@img/sharp-linuxmusl-x64 && \
  cp -r \
    node_modules/@img \
    node_modules/exiftool-vendored.pl \
    /tmp/node_modules && \
  npm run build && \
  npm prune --omit=dev --omit=optional && \
  cp -r \
    /tmp/node_modules/@img \
    /tmp/node_modules/exiftool-vendored.pl \
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
  echo "**** copy scripts ****" && \
  cd /tmp/immich/docker && \
  cp -r \
    scripts \
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
  echo "**** build CLI ****" && \
  mkdir -p \
    /app/immich/cli && \
  cd /tmp/immich/cli && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev --omit=optional && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/cli && \
  echo "**** build machine-learning ****" && \
  mkdir -p \
    /app/immich/machine-learning/ann && \
  cd /tmp/immich/machine-learning && \
  pip install --break-system-packages -U --no-cache-dir \
    poetry && \
  python3.10 -m venv /lsiopy && \
  poetry config installer.max-workers 10 && \
  poetry config virtualenvs.create false && \
  poetry add --lock --no-interaction --no-ansi --group openvino openvino==2023.3.0 && \
  poetry install --sync --no-interaction --no-ansi --no-root --with openvino --without dev && \
  cp -a \
    pyproject.toml \
    poetry.lock \
    app \
    log_conf.json \
    /app/immich/machine-learning && \
  cp -a \
    ann/ann.py \
    /app/immich/machine-learning/ann && \
  echo "**** cleanup ****" && \
  for cleanfiles in *.pyc *.pyo; do \
    find /usr/local/lib/python3.* /usr/lib/python3.* /lsiopy/lib/python3.* -name "${cleanfiles}" -delete; \
  done && \
  apt-get remove -y --purge \
    build-essential \
    python3.10-dev \
    python3.10-venv \
    python3-pip && \
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
VOLUME /config /import
