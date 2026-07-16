target "docker-metadata-action" {}

variable "OWNER" {
  default = "imagegenius"
}

variable "IMMICH_BASE_IMAGES_VERSION" {
  # renovate: datasource=github-tags depName=immich-app/base-images versioning=regex:^(?<major>\d{8})(?<minor>\d{4})$
  default = "202607141130"
}

variable "VERSION" {
  # renovate: datasource=github-tags depName=immich-app/immich versioning=semver
  default = "v3.0.3"
}

variable "NODEJS_VERSION" {
  # renovate: datasource=node-version depName=node versioning=node
  default = "24.15.0"
}

variable "UV_IMAGE_REPOSITORY" {
  default = "ghcr.io/astral-sh/uv"
}

variable "UV_IMAGE_VERSION" {
  # renovate: datasource=docker depName=ghcr.io/astral-sh/uv versioning=docker
  default = "0.8.15"
}

variable "MISE_IMAGE_REPOSITORY" {
  default = "ghcr.io/jdx/mise"
}

variable "MISE_IMAGE_VERSION" {
  # renovate: datasource=docker depName=ghcr.io/jdx/mise versioning=docker
  default = "2026.6.10"
}

variable "IMMICH_MEDIA_BUILD_JOBS" {
  default = "4"
}

variable "SOURCE" {
  default = "https://github.com/immich-app/immich"
}

group "default" {
  targets = ["image-main-local"]
}

target "image" {
  inherits = ["docker-metadata-action"]
  args = {
    IMMICH_BASE_IMAGES_VERSION = "${IMMICH_BASE_IMAGES_VERSION}"
    IMMICH_MEDIA_BUILD_JOBS    = "${IMMICH_MEDIA_BUILD_JOBS}"
    IMMICH_VERSION             = "${VERSION}"
    MISE_IMAGE                 = "${MISE_IMAGE_REPOSITORY}:${MISE_IMAGE_VERSION}"
    NODEJS_VERSION             = "${NODEJS_VERSION}"
    UV_IMAGE                   = "${UV_IMAGE_REPOSITORY}:${UV_IMAGE_VERSION}"
  }
  labels = {
    "org.opencontainers.image.source" = "${SOURCE}"
  }
}

target "image-main" {
  inherits  = ["image"]
  target    = "final-main"
  platforms = ["linux/amd64", "linux/arm64"]
}

target "image-main-local" {
  inherits = ["image"]
  target   = "final-main"
  output   = ["type=docker"]
  tags     = ["immich:local-main"]
}

target "image-noml" {
  inherits  = ["image"]
  target    = "final-noml"
  platforms = ["linux/amd64", "linux/arm64"]
}

target "image-noml-local" {
  inherits = ["image"]
  target   = "final-noml"
  output   = ["type=docker"]
  tags     = ["immich:local-noml"]
}

target "image-cuda" {
  inherits  = ["image"]
  target    = "final-cuda"
  platforms = ["linux/amd64"]
}

target "image-cuda-local" {
  inherits = ["image"]
  target   = "final-cuda"
  output   = ["type=docker"]
  tags     = ["immich:local-cuda"]
}

target "image-openvino" {
  inherits  = ["image"]
  target    = "final-openvino"
  platforms = ["linux/amd64"]
}

target "image-openvino-local" {
  inherits = ["image"]
  target   = "final-openvino"
  output   = ["type=docker"]
  tags     = ["immich:local-openvino"]
}

group "image-multiarch" {
  targets = ["image-main", "image-noml"]
}

group "image-amd64-only" {
  targets = ["image-cuda", "image-openvino"]
}
