# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom

ARG UV_IMAGE
ARG MISE_IMAGE

FROM ${UV_IMAGE} AS uv
FROM ${MISE_IMAGE} AS mise

# =============================================================================
# media-deps: Immich media/runtime dependencies
# =============================================================================
FROM ghcr.io/linuxserver/baseimage-ubuntu:resolute AS media-deps

ARG IMMICH_BASE_IMAGES_VERSION
ARG IMMICH_MEDIA_BUILD_JOBS=4
ARG TARGETARCH

ENV \
  LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/jellyfin-ffmpeg/lib:/usr/lib/wsl/lib" \
  LD_RUN_PATH="/usr/local/lib"

RUN \
  echo "**** setup media dependency build ****" && \
  mkdir -p \
    /app/immich/data/geodata \
    /tmp/immich-dependencies && \
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/pgdg-archive-keyring.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/pgdg-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt resolute-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  apt-get update && \
  echo "**** install media build packages ****" && \
  apt-get install --no-install-recommends -y \
    autoconf \
    automake \
    aom-tools \
    bc \
    build-essential \
    ca-certificates \
    cmake \
    git \
    jq \
    libaom-dev \
    libbrotli-dev \
    libdav1d-dev \
    libde265-dev \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libgsf-1-dev \
    libhwy-dev \
    libjpeg-dev \
    liblcms2-dev \
    libltdl-dev \
    librsvg2-dev \
    libsharpyuv-dev \
    libspng-dev \
    libtool \
    libwebm-dev \
    libwebp-dev \
    libyuv-dev \
    make \
    meson \
    ninja-build \
    pkg-config \
    postgresql-client-14 \
    postgresql-client-15 \
    postgresql-client-16 \
    postgresql-client-17 \
    postgresql-client-18 \
    unzip \
    wget && \
  echo "**** install media runtime packages ****" && \
  apt-get install --no-install-recommends -y \
    libaom3 \
    libdav1d7 \
    libde265-0 \
    libexif12 \
    libexpat1 \
    libgcc-s1 \
    libglib2.0-0 \
    libgomp1 \
    libgsf-1-114 \
    libhwy1t64 \
    libio-compress-brotli-perl \
    liblcms2-2 \
    liblqr-1-0 \
    libltdl7 \
    libmimalloc3 \
    libopenexr-3-1-30 \
    libopenjp2-7 \
    libpng16-16 \
    librsvg2-2 \
    libspng0 \
    libwebp7 \
    libwebpdemux2 \
    libwebpmux3 \
    libwebm1 \
    libyuv0 \
    mesa-utils \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    ocl-icd-libopencl1 \
    perl \
    zlib1g && \
  apt-mark manual \
    libaom3 \
    libwebm1 \
    libyuv0 && \
  if [ "${TARGETARCH:-$(dpkg --print-architecture)}" = "amd64" ]; then \
    echo "**** install intel opencl runtime ****" && \
    apt-get install --no-install-recommends -y \
      intel-media-va-driver-non-free && \
    mkdir -p /tmp/intel && \
    wget -nv -P /tmp/intel \
      "https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17537.24/intel-igc-core_1.0.17537.24_amd64.deb" \
      "https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.17537.24/intel-igc-opencl_1.0.17537.24_amd64.deb" \
      "https://github.com/intel/compute-runtime/releases/download/24.35.30872.36/intel-opencl-icd-legacy1_24.35.30872.36_amd64.deb" \
      "https://github.com/intel/intel-graphics-compiler/releases/download/v2.36.3/intel-igc-core-2_2.36.3+21719_amd64.deb" \
      "https://github.com/intel/intel-graphics-compiler/releases/download/v2.36.3/intel-igc-opencl-2_2.36.3+21719_amd64.deb" \
      "https://github.com/intel/compute-runtime/releases/download/26.22.38646.4/intel-opencl-icd_26.22.38646.4-0_amd64.deb" \
      "https://github.com/intel/compute-runtime/releases/download/26.22.38646.4/libigdgmm12_22.10.0_amd64.deb" && \
    dpkg -i /tmp/intel/*.deb; \
  fi && \
  echo "**** download upstream immich base-image scripts ****" && \
  curl -o \
    /tmp/immich-dependencies.tar.gz -L \
    "https://github.com/immich-app/base-images/archive/${IMMICH_BASE_IMAGES_VERSION}.tar.gz" && \
  tar xf \
    /tmp/immich-dependencies.tar.gz -C \
    /tmp/immich-dependencies --strip-components=1 && \
  echo "**** build upstream media dependencies ****" && \
  cd /tmp/immich-dependencies/server/sources && \
  FFMPEG_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" && \
  FFMPEG_DEBIAN_RELEASE="resolute" && \
  FFMPEG_VERSION=$(jq -cr '.version' /tmp/immich-dependencies/server/packages/ffmpeg.json) && \
  FFMPEG_ASSET="jellyfin-ffmpeg7_${FFMPEG_VERSION}-${FFMPEG_DEBIAN_RELEASE}_${FFMPEG_ARCH}.deb" && \
  curl -f -o \
    /tmp/ffmpeg.deb -L \
    "https://github.com/jellyfin/jellyfin-ffmpeg/releases/download/v${FFMPEG_VERSION}/${FFMPEG_ASSET}" && \
  apt-get install --no-install-recommends -y -f \
    /tmp/ffmpeg.deb && \
  ldconfig /usr/lib/jellyfin-ffmpeg/lib && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/ffmpeg \
    /usr/bin && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/ffprobe \
    /usr/bin && \
  mkdir -p /tmp/media-build-bin && \
  printf '#!/bin/sh\nprintf "%%s\\n" "${IMMICH_MEDIA_BUILD_JOBS:-4}"\n' > /tmp/media-build-bin/nproc && \
  chmod +x /tmp/media-build-bin/nproc && \
  PATH="/tmp/media-build-bin:${PATH}" && \
  ./libjxl.sh \
    --JPEGLI_LIBJPEG_LIBRARY_SOVERSION 8 \
    --JPEGLI_LIBJPEG_LIBRARY_VERSION 8.2.2 && \
  ./libheif.sh && \
  ./libraw.sh && \
  ./imagemagick.sh && \
  ./libvips.sh && \
  jq -s '.' /tmp/immich-dependencies/server/packages/*.json > /tmp/packages.json && \
  jq -s '.' /tmp/immich-dependencies/server/sources/*.json > /tmp/sources.json && \
  jq -n \
    --slurpfile sources /tmp/sources.json \
    --slurpfile packages /tmp/packages.json \
    '{sources: $sources[0], packages: $packages[0]}' \
    > /app/immich/data/build-lock.json && \
  echo "**** download geocoding data ****" && \
  curl -o \
    /tmp/cities500.zip -L \
    "https://download.geonames.org/export/dump/cities500.zip" && \
  curl -o \
    /app/immich/data/geodata/admin1CodesASCII.txt -L \
    "https://download.geonames.org/export/dump/admin1CodesASCII.txt" && \
  curl -o \
    /app/immich/data/geodata/admin2Codes.txt -L \
    "https://download.geonames.org/export/dump/admin2Codes.txt" && \
  curl -o \
    /app/immich/data/geodata/ne_10m_admin_0_countries.geojson -L \
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson" && \
  unzip \
    /tmp/cities500.zip -d \
    /app/immich/data/geodata && \
  date --iso-8601=seconds | tr -d "\n" > /app/immich/data/geodata/geodata-date.txt && \
  echo "**** cleanup media dependency build ****" && \
  apt-get remove -y --purge \
    autoconf \
    automake \
    aom-tools \
    bc \
    build-essential \
    cmake \
    git \
    libaom-dev \
    libbrotli-dev \
    libdav1d-dev \
    libde265-dev \
    libexif-dev \
    libexpat1-dev \
    libglib2.0-dev \
    libgsf-1-dev \
    libheif-dev \
    libhwy-dev \
    libjpeg-dev \
    liblcms2-dev \
    libltdl-dev \
    librsvg2-dev \
    libsharpyuv-dev \
    libspng-dev \
    libtool \
    libwebm-dev \
    libwebp-dev \
    libyuv-dev \
    make \
    meson \
    ninja-build \
    pkg-config \
    unzip \
    wget && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /etc/apt/sources.list.d/pgdg.list \
    /tmp/* \
    /usr/share/keyrings/pgdg-archive-keyring.gpg \
    /var/lib/apt/lists/* \
    /var/log/* \
    /var/tmp/* && \
  ldconfig /usr/local/lib

# =============================================================================
# build: download immich, install build deps, pnpm build server/web/cli/plugins
# =============================================================================
FROM media-deps AS build

ARG IMMICH_VERSION
ARG NODEJS_VERSION

COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise

ENV \
  IMMICH_BUILD_DATA="/app/immich/data" \
  IMMICH_ENV="production" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning/models" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  SHARP_FORCE_GLOBAL_LIBVIPS="true" \
  TRANSFORMERS_CACHE="/config/machine-learning/models" \
  MISE_TRUSTED_CONFIG_PATHS="/tmp/immich/mise.toml" \
  MISE_DATA_DIR="/buildcache/mise" \
  MISE_DISABLE_TOOLS="flutter" \
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
  echo "deb [signed-by=/usr/share/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_${NODEJS_MAJOR_VERSION}.x nodistro main" > /etc/apt/sources.list.d/node.list && \
  curl -s \
    "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | \
    gpg --dearmor | tee /usr/share/keyrings/nodesource-repo.gpg >/dev/null && \
  echo "**** install packages ****" && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libcairo2-dev \
    libexif-dev \
    libexpat1-dev \
    libfontconfig-dev \
    libglib2.0-dev \
    libhwy-dev \
    libjpeg-dev \
    liblcms2-dev \
    libpango1.0-dev \
    libpng-dev \
    librsvg2-dev \
    libspng-dev \
    libwebp-dev \
    pkg-config \
    python3 && \
  apt-get install --no-install-recommends -y \
    nodejs="${NODEJS_VERSION}" && \
  echo "**** setup pnpm ****" && \
  npm install --global corepack@latest && \
  corepack enable pnpm && \
  echo "**** build plugins (mise) ****" && \
  cd /tmp/immich && \
  mise install && \
  mise //:plugins && \
  echo "**** build server ****" && \
  cd /tmp/immich && \
  SHARP_IGNORE_GLOBAL_LIBVIPS=true pnpm \
    --filter @immich/sdk \
    --filter @immich/plugin-sdk \
    --filter immich \
    build && \
  SHARP_FORCE_GLOBAL_LIBVIPS=true pnpm \
    --filter immich \
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
    /tmp/immich/packages/plugin-core/dist \
    /app/immich/data/corePlugin/dist && \
  cp -a \
    /tmp/immich/packages/plugin-core/manifest.json \
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
    /etc/apt/sources.list.d/node.list \
    /usr/share/keyrings/nodesource-repo.gpg \
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
# ml-base-openvino: upstream OpenVINO Python base
# =============================================================================
FROM python:3.13-slim-trixie AS ml-base-openvino

ENV \
  UV_PYTHON="/usr/local/bin/python3.13"

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
FROM media-deps AS runtime-base

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

RUN \
  echo "**** prevent core dumps ****" && \
  echo "hard core 0" >> /etc/security/limits.conf && \
  echo "fs.suid_dumpable 0" >> /etc/sysctl.conf && \
  echo 'ulimit -S -c 0 > /dev/null 2>&1' >> /etc/profile

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
  MACHINE_LEARNING_MODEL_ARENA="false" \
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
    libcublas12 \
    libcublaslt12 \
    libcudart12 \
    libcudnn9-cuda-12=9.10.2.21-1 \
    libcufft11 \
    libcurand10 && \
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
FROM ml-base-openvino AS ml-openvino

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
# final-openvino: final-main + OpenVINO ml venv
# =============================================================================
FROM final-main AS final-openvino

ENV \
  MACHINE_LEARNING_MODEL_ARENA="true"

# Replace ml-cpu artifacts with ml-openvino artifacts
COPY --from=ml-openvino /lsiopy /lsiopy
COPY --from=ml-openvino /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=ml-openvino /usr/local/bin/python3.13 /usr/local/bin/python3.13
COPY --from=ml-openvino /usr/local/lib/python3.13 /usr/local/lib/python3.13
COPY --from=ml-openvino /usr/local/lib/libpython3.13.so /usr/local/lib/libpython3.13.so
COPY --from=ml-openvino /usr/local/lib/libpython3.13.so.1.0 /usr/local/lib/libpython3.13.so.1.0
COPY --from=ml-openvino /tmp/immich/machine-learning /app/immich/machine-learning

RUN ldconfig /usr/local/lib
