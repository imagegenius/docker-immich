# syntax=docker/dockerfile:1

ARG BASE_IMAGE
ARG UV_IMAGE

FROM ${UV_IMAGE} AS uv

# =============================================================================
# build: download immich, install build deps, pnpm build server/web/cli/plugins
# =============================================================================
FROM ${BASE_IMAGE} AS build

ARG IMMICH_VERSION
ARG NODEJS_VERSION
ARG LATEST_UBUNTU_VERSION="resolute"

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
  MISE_TRUSTED_CONFIG_PATHS="/tmp/immich" \
  MISE_DATA_DIR="/buildcache/mise" \
  NODE_OPTIONS="--max-old-space-size=8192"

RUN \
  echo "**** download immich ****" && \
  mkdir -p \
    /app/immich \
    /tmp/immich && \
  curl -o \
    /tmp/immich.tar.gz -L \
    "https://github.com/immich-app/immich/archive/${IMMICH_VERSION}.tar.gz" && \
  tar xf \
    /tmp/immich.tar.gz -C \
    /tmp/immich --strip-components=1 && \
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
    libwebpdemux2 \
    libwebpmux3 && \
  apt-get install --no-install-recommends -y \
    nodejs="${NODEJS_VERSION}" \
    python3.11 && \
  echo "**** setup pnpm ****" && \
  npm install --global corepack@latest && \
  corepack enable pnpm && \
  echo "**** build plugins (mise) ****" && \
  rm /tmp/immich/mise.toml && \
  mise install --cd /tmp/immich/plugins && \
  cd /tmp/immich/plugins && \
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
    /tmp/immich/plugins/dist \
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

# =============================================================================
# ml-base: uv from official multi-arch image, source machine-learning sources
# =============================================================================
FROM python:3.11-bookworm AS ml-base

ENV \
  UV_PYTHON="/usr/local/bin/python3.11"

RUN \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    g++ && \
  apt-get clean && \
  rm -rf \
    /var/lib/apt/lists/*

COPY --from=uv /uv /uvx /usr/local/bin/
COPY --from=build /tmp/immich/machine-learning /tmp/immich/machine-learning

WORKDIR /tmp/immich/machine-learning

RUN uv venv /lsiopy --python "${UV_PYTHON}"

# =============================================================================
# ml-cpu: uv sync with cpu extras
# =============================================================================
FROM ml-base AS ml-cpu

RUN \
  . /lsiopy/bin/activate && \
  uv sync \
    --active \
    --frozen \
    --extra cpu \
    --no-dev \
    --no-editable \
    --no-install-project \
    --compile-bytecode \
    --no-progress

# =============================================================================
# runtime-base: shared final scaffolding for all variants
# =============================================================================
FROM ${BASE_IMAGE} AS runtime-base

ARG NODEJS_VERSION

LABEL org.opencontainers.image.authors="hydazz, martabal"

ENV \
  IMMICH_BUILD_DATA="/app/immich/data" \
  IMMICH_ENV="production" \
  IMMICH_MEDIA_LOCATION="/photos" \
  NODE_ENV="production" \
  NODE_OPTIONS="--max-old-space-size=8192" \
  PATH="${PATH}:/app/immich/server/bin"

COPY --from=build /app/immich /app/immich

RUN \
  NODEJS_MAJOR_VERSION=$(echo "${NODEJS_VERSION}" | cut -d '.' -f 1) && \
  NODEJS_VERSION="${NODEJS_VERSION}-1nodesource1" && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_${NODEJS_MAJOR_VERSION}.x nodistro main" \
    >/etc/apt/sources.list.d/node.list && \
  curl -s \
    "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | \
    gpg --dearmor | tee /usr/share/keyrings/nodesource-repo.gpg >/dev/null && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    nodejs="${NODEJS_VERSION}" && \
  apt-get clean && \
  rm -rf \
    /etc/apt/sources.list.d/node.list \
    /usr/share/keyrings/nodesource-repo.gpg \
    /var/lib/apt/lists/*

COPY root/ /

EXPOSE 8080
VOLUME /config /photos /libraries

# =============================================================================
# final-main: Ubuntu + ML (CPU)
# =============================================================================
FROM runtime-base AS final-main

ENV \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  PYTHONDONTWRITEBYTECODE="1" \
  PYTHONPATH="/app/immich/machine-learning" \
  PYTHONUNBUFFERED="1" \
  SHARP_FORCE_GLOBAL_LIBVIPS="true" \
  TRANSFORMERS_CACHE="/config/machine-learning/models" \
  VIRTUAL_ENV="/lsiopy"

COPY --from=ml-cpu /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=ml-cpu /usr/local/bin/python3.11 /usr/local/bin/python3.11
COPY --from=ml-cpu /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=ml-cpu /usr/local/lib/libpython3.11.so /usr/local/lib/libpython3.11.so
COPY --from=ml-cpu /usr/local/lib/libpython3.11.so.1.0 /usr/local/lib/libpython3.11.so.1.0
COPY --from=ml-cpu /lsiopy /lsiopy
COPY --from=ml-cpu /tmp/immich/machine-learning /app/immich/machine-learning

RUN ldconfig /usr/local/lib

# =============================================================================
# final-noml: Ubuntu, no ML — drop s6 ML service
# =============================================================================
FROM runtime-base AS final-noml

ENV \
  IMMICH_MACHINE_LEARNING_ENABLED="false"

RUN rm -rf \
      /etc/s6-overlay/s6-rc.d/svc-machine-learning \
      /etc/s6-overlay/s6-rc.d/user/contents.d/svc-machine-learning \
      /etc/s6-overlay/s6-rc.d/svc-microservices/dependencies.d/svc-machine-learning

# =============================================================================
# ml-cuda: uv sync with cuda extras
# =============================================================================
FROM ml-base AS ml-cuda

RUN \
  . /lsiopy/bin/activate && \
  uv sync \
    --active \
    --frozen \
    --extra cuda \
    --no-dev \
    --no-editable \
    --no-install-project \
    --compile-bytecode \
    --no-progress

# =============================================================================
# final-cuda: final-main + CUDA runtime libs
# =============================================================================
FROM final-main AS final-cuda

ENV \
  NVIDIA_VISIBLE_DEVICES="all"

# Replace ml-cpu artifacts with ml-cuda artifacts
COPY --from=ml-cuda /lsiopy /lsiopy
COPY --from=ml-cuda /tmp/immich/machine-learning /app/immich/machine-learning

RUN \
  echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/ /" \
    >/etc/apt/sources.list.d/cuda.list && \
  curl -s \
    "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub" | \
    gpg --dearmor | tee /usr/share/keyrings/cuda-archive-keyring.gpg >/dev/null && \
  printf "Package: *\nPin: release l=NVIDIA CUDA\nPin-Priority: 600\n" \
    >/etc/apt/preferences.d/cuda && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    execstack \
    libcublas12 \
    libcublaslt12 \
    libcudart12 \
    libcudnn9-cuda-12=9.10.2.21-1 \
    libcufft11 \
    libcurand10 && \
  find /lsiopy/lib -name "*linux-gnu.so" -exec execstack -c {} \; && \
  apt-get remove -y --purge \
    execstack && \
  ldconfig /usr/local/lib && \
  apt-get clean && \
  rm -rf \
    /etc/apt/preferences.d/cuda \
    /etc/apt/sources.list.d/cuda.list \
    /usr/share/keyrings/cuda-archive-keyring.gpg \
    /var/lib/apt/lists/*

# =============================================================================
# ml-openvino: uv sync with openvino extras
# =============================================================================
FROM ml-base AS ml-openvino

RUN \
  . /lsiopy/bin/activate && \
  uv sync \
    --active \
    --frozen \
    --extra openvino \
    --no-dev \
    --no-editable \
    --no-install-project \
    --compile-bytecode \
    --no-progress

# =============================================================================
# final-openvino: final-main + execstack on OpenVINO .so files
# =============================================================================
FROM final-main AS final-openvino

# Replace ml-cpu artifacts with ml-openvino artifacts
COPY --from=ml-openvino /lsiopy /lsiopy
COPY --from=ml-openvino /tmp/immich/machine-learning /app/immich/machine-learning

RUN \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    execstack && \
  find /lsiopy/lib -name "*linux-gnu.so" -exec execstack -c {} \; && \
  apt-get remove -y --purge \
    execstack && \
  ldconfig /usr/local/lib && \
  apt-get clean && \
  rm -rf \
    /var/lib/apt/lists/*
