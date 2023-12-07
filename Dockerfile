# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-ubuntu:lunar

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
  SERVER_PORT="8080"

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
  echo "deb [signed-by=/usr/share/keyrings/nodesource-repo.gpg] https://deb.nodesource.com/node_20.x nodistro main" >>/etc/apt/sources.list.d/node.list && \
  curl -s https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource-repo.gpg >/dev/null && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    intel-media-va-driver-non-free \
    libexif12 \
    libexpat1 \
    libgcc-s1 \
    libglib2.0-0 \
    libgomp1 \
    libgsf-1-114 \
    libheif1 \
    libjxl0.7 \
    liblcms2-2 \
    liblqr-1-0 \
    libltdl7 \
    libmimalloc2.0 \
    libopenexr-3-1-30 \
    libopenjp2-7 \
    liborc-0.4-0 \
    libpng16-16 \
    librsvg2-2 \
    libspng0 \
    libwebp7 \
    libwebpdemux2 \
    libwebpmux3 \
    mesa-va-drivers \
    nginx \
    nodejs \
    perl \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    zlib1g && \
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
  echo "**** download geocoding data ****" && \
  mkdir -p \
    /usr/src/resources && \
  curl -o \
    /tmp/cities500.zip -L \
    "https://download.geonames.org/export/dump/cities500.zip" && \
  curl -o \
    /usr/src/resources/admin1CodesASCII.txt -L \
    "https://download.geonames.org/export/dump/admin1CodesASCII.txt" && \
  curl -o \
    /usr/src/resources/admin2Codes.txt -L \
    "https://download.geonames.org/export/dump/admin2Codes.txt" && \
  unzip \
    /tmp/cities500.zip -d \
    /usr/src/resources && \
  date --iso-8601=seconds | tr -d "\n" > /usr/src/resources/geodata-date.txt && \
  echo "**** build immich dependencies ****" && \
  cd /tmp/immich-dependencies/server/bin && \
  ./install-ffmpeg.sh && \
  ./build-libraw.sh && \
  ./build-imagemagick.sh && \
  ./build-libvips.sh && \
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
    resources \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/server && \
  echo "**** build web ****" && \
  cd /tmp/immich/web && \
  npm ci && \
  npm run build && \
  mkdir -p \
    /app/immich/server/www && \
  cp -a \
    build/* \
    static \
    /app/immich/server/www  && \
  echo "**** build machine-learning ****" && \
  cd /tmp/immich/machine-learning && \
  pip install --break-system-packages -U --no-cache-dir \
    poetry && \
  python3 -m venv /lsiopy && \
  poetry config installer.max-workers 10 && \
  poetry config virtualenvs.create false && \
  poetry install --sync --no-interaction --no-ansi --no-root --only main && \
  mkdir -p \
    /app/immich/machine-learning && \
  cp -a \
    app \
    log_conf.json \
    /app/immich/machine-learning && \
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
    unzip \
    wget && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/tmp/* \
    /var/lib/apt/lists/* \
    /root/.cache \
    /root/.npm \
    /etc/apt/sources.list.d/node.list \
    /usr/share/keyrings/nodesource.gpg

# copy local files
COPY root/ /

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads /import
