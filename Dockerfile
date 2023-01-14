FROM ghcr.io/imagegenius/baseimage-ubuntu:jammy

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz"

# environment settings
ENV DEBIAN_FRONTEND="noninteractive"

# this is a really messy dockerfile but it works
RUN  \
	echo "**** install runtime packages ****" && \
	curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
	apt-get update && \
	apt-get install --no-install-recommends -y \
		build-essential \
		ffmpeg \
		libheif1 \
		libvips \
		libvips-dev \
		nginx-full \
		nodejs \
		redis-server && \
	echo "**** install immich ****" && \
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
	cd /tmp/immich/server && \
	npm ci && \
	npm run build && \
	npm prune --omit=dev && \
	mkdir -p \
		/app/immich/server && \
	cp -a \
		package.json \
		package-lock.json \
		node_modules \
		dist \
		/app/immich/server && \
	echo "**** build web frontend ****" && \
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
		dist \
		/app/immich/web && \
	echo "**** build machine-learning ****" && \
	cd /tmp/immich/machine-learning && \
	sed -i \
		'/@tensorflow\/tfjs-node-gpu/d' \
		package.json && \
	npm ci && \
	npm rebuild @tensorflow/tfjs-node --build-from-source && \
	npm run build && \
	npm prune --omit=dev && \
	mkdir -p \
		/app/immich/machine-learning && \
	cp -a \
		package.json \
		package-lock.json \
		node_modules \
		dist \
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
	chown -R abc:abc /app && \
	echo "**** cleanup ****" && \
	apt-get remove -y --purge \
		build-essential \
		libvips-dev && \
	apt-get autoremove -y --purge && \
	apt-get clean && \
	rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/* \
		/root/.cache \
		/root/.npm

# environment settings
ENV NODE_ENV="production" \
	REDIS_HOSTNAME="localhost"

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8080
VOLUME /config
