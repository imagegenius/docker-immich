# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-ubuntu:jammy as builder

ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1 \
  PIP_NO_CACHE_DIR=true

RUN \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    g++ \
    python3-dev \
    python3-pip \
    python3-venv && \
  mkdir -p \
    /tmp/immich && \
  if [ -z ${IMMICH_VERSION} ]; then \
    IMMICH_VERSION=$(curl -sL https://api.github.com/repos/immich-app/immich/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -sL "https://github.com/mertalev/immich/archive/ml-ray.tar.gz" -o /tmp/immich.tar.gz && \
	tar xf /tmp/immich.tar.gz -C /tmp/immich --strip-components=1 && \
  mkdir -p \
    /app/immich/machine-learning && \
  cp -a \
    /tmp/immich/machine-learning/poetry.lock \
    /tmp/immich/machine-learning/pyproject.toml \
    /app/immich/machine-learning && \
  pip install --upgrade pip && pip install poetry && \
  poetry config installer.max-workers 10 && \
  poetry config virtualenvs.create false && \
  python3 -m venv /lsiopy

ENV VIRTUAL_ENV="/lsiopy" PATH="/lsiopy/bin:${PATH}"

WORKDIR /app/immich/machine-learning

RUN poetry install --sync --no-interaction --no-ansi --no-root --only main

FROM ghcr.io/imagegenius/baseimage-ubuntu:lunar

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV TRANSFORMERS_CACHE="/config/machine-learning" \
  TYPESENSE_DATA_DIR="/config/typesense" \
  TYPESENSE_VERSION="0.24.0" \
  TYPESENSE_API_KEY="xyz" \
  TYPESENSE_HOST="127.0.0.1" \
  PUBLIC_IMMICH_SERVER_URL="http://127.0.0.1:3001" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning"

RUN \
  echo "**** install runtime packages ****" && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x lunar main" >>/etc/apt/sources.list.d/node.list && \
  curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    ffmpeg \
    g++ \
    imagemagick \
    libheif1 \
    libraw-dev \
    libvips \
    libvips-dev \
    make \
    nginx \
    nodejs \
    perl && \
  echo "**** download immich ****" && \
  mkdir -p \
    /tmp/immich && \
  if [ -z ${IMMICH_VERSION} ]; then \
    IMMICH_VERSION=$(curl -sL https://api.github.com/repos/immich-app/immich/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl  \
    -o /tmp/immich.tar.gz
    -sL "https://github.com/mertalev/immich/archive/ml-ray.tar.gz" && \
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
  echo "**** build machine-learning ****" && \
  cd /tmp/immich/machine-learning && \
  mkdir -p \
    /app/immich/machine-learning && \
  cp -a \
    app \
    /app/immich/machine-learning && \
  echo "**** cleanup ****" && \
  apt-get remove -y --purge \
    g++ \
    libvips-dev \
    make && \
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

# copy python dependencies
COPY --from=builder /lsiopy /lsiopy
COPY --from=builder /usr/bin/python3 /usr/bin/python3
COPY --from=builder /usr/lib/python3 /usr/lib/python3
COPY --from=builder /usr/lib/python3.10 /usr/lib/python3.10
COPY --from=builder /usr/local/lib/python3.10 /usr/local/lib/python3.10

# copy local files
COPY root/ /

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads
