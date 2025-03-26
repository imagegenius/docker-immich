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
  IMMICH_BUILD_DATA="/app/immich/server" \
  IMMICH_ENV="production" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  IMMICH_PORT="8080" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  TRANSFORMERS_CACHE="/config/machine-learning/models" \
  UV_PYTHON="/usr/bin/python3.11"

RUN \
  echo "**** install build packages ****" && \
  echo "deb [signed-by=/usr/share/keyrings/deadsnakes.gpg] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu noble main" >>/etc/apt/sources.list.d/deadsnakes.list && \
  curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | gpg --dearmor | tee /usr/share/keyrings/deadsnakes.gpg >/dev/null && \
  echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/ /" >>/etc/apt/sources.list.d/cuda.list && \
  curl -s "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub" | gpg --dearmor | tee /usr/share/keyrings/cuda-archive-keyring.gpg >/dev/null && \
  printf "Package: *\nPin: release l=NVIDIA CUDA\nPin-Priority: 600" > /etc/apt/preferences.d/cuda && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    build-essential \
    execstack \
    python3.11-dev && \
  echo "**** install runtime packages ****" && \
  apt-get install --no-install-recommends -y \
    libcublas12 \
    libcublaslt12 \
    libcudart12 \
    libcudnn9-cuda-12 \
    libcufft11 \
    libcurand10 \
    python3.11 && \
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
  /tmp/uv sync --active --frozen --extra cuda --no-dev --no-editable --no-install-project --compile-bytecode --no-progress && \
  find /lsiopy/lib -name "*linux-gnu.so" -exec execstack -c {} \; && \
  cp -a \
    pyproject.toml \
    app \
    log_conf.json \
    uv.lock \
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
    execstack \
    python3.11-dev && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /etc/apt/preferences.d/cuda \
    /etc/apt/sources.list.d/cuda.list \
    /root/.cache \
    /root/.npm \
    /tmp/* \
    /usr/share/keyrings/cuda-archive-keyring.gpg \
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
VOLUME /config /libraries
