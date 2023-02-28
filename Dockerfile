# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-ubuntu:jammy

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV DEBIAN_FRONTEND="noninteractive" \
  IMMICH_WEB_URL=http://127.0.0.1:3000 \
  MMICH_SERVER_URL=http://127.0.0.1:3001 \
  IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003 \
  PUBLIC_IMMICH_SERVER_URL=http://127.0.0.1:3001 \
  TRANSFORMERS_CACHE=/cache

# copy local files
COPY root/ /

RUN \
  echo "**** install runtime packages ****" && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x jammy main" >>/etc/apt/sources.list && \
  curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    ffmpeg \
    g++ \
    git \
    libheif1 \
    libvips \
    libvips-dev \
    make \
    nginx \
    nodejs \
    perl \
    python3-pip && \
  echo "**** download immich ****" && \
  mkdir -p \
    /app/immich && \
  if [ -z ${IMMICH_VERSION+x} ]; then \
    IMMICH_VERSION=$(curl -sL "https://api.github.com/repos/immich-app/immich/commits?ref=main" | jq -r '.[0].sha' | cut -c1-8); \
  fi && \
  git clone -b main https://github.com/immich-app/immich.git /tmp/immich && \
  cd /tmp/immich && \
  git checkout ${IMMICH_VERSION} && \
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
  echo "**** build machine-learning ****" && \
  mkdir -p /cache && \
  pip install --no-cache-dir -f https://download.pytorch.org/whl/torch_stable.html \
    pillow \
    flask \
    nltk \
    numpy \
    scikit-learn \
    scipy \
    sentence-transformers \
    sentencepiece \
    torch==1.13.1+cpu \
    tqdm \
    transformers && \
  python3 /defaults/install.py && \
  rm /defaults/install.py && \
  mkdir -p \
    /app/immich/machine-learning && \
  cp -a \
    /tmp/immich/machine-learning/src \
    /app/immich/machine-learning/ && \
  echo "**** setup upload folder ****" && \
  mkdir -p \
    /photos && \
  ln -s \
    /photos \
    /app/immich/server/upload && \
  ln -s \
    /photos \
    /app/immich/machine-learning/upload && \
  echo "**** cleanup ****" && \
  apt-get remove -y --purge \
    libvips-dev \
    make \
    g++ && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /root/.cache \
    /root/.npm

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads
