#!/usr/bin/env bash
set -euo pipefail

# Prints the build inputs upstream Immich pins at VERSION as NAME=value lines, named after the bake variables.
version=$(docker buildx bake image --print --progress=quiet | jq -er '.target.image.args.IMMICH_VERSION')
src="https://raw.githubusercontent.com/immich-app/immich/$version"
server=$(curl -fsSL "$src/server/Dockerfile")
ml=$(curl -fsSL "$src/machine-learning/Dockerfile")
tools=$(curl -fsSL "$src/mise.toml")

# extract NAME TEXT REGEX prints NAME and the first capture of REGEX on the first matching line.
extract() {
  local value
  value=$(sed -nE "\|$3|{s||\1|p;q;}" <<<"$2")
  if [[ -z $value ]]; then
    echo "immich $version: $1 not found" >&2
    return 1
  fi
  echo "$1=$value"
}

extract IMMICH_BASE_IMAGES_VERSION "$server" '.*base-server-dev:([0-9]+).*'
extract MISE_IMAGE "$server" '.*(ghcr\.io/jdx/mise:[^ ]+).*'
extract NODEJS_VERSION "$tools" '^node = "([^"]+)".*'
extract ONNXRUNTIME_VERSION "$ml" '^ARG ONNXRUNTIME_VERSION="([^"]+)".*'
extract UV_IMAGE "$ml" '.*(ghcr\.io/astral-sh/uv:[^ ]+).*'
