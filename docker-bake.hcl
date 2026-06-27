target "docker-metadata-action" {}

variable "OWNER" {
  default = "imagegenius"
}

variable "IMMICH_BASE_IMAGES_VERSION" {
  # renovate: datasource=github-tags depName=immich-app/base-images versioning=regex:^(?<major>\d{8})(?<minor>\d{4})$
  default = "202605121138"
}

variable "VERSION" {
  # renovate: datasource=github-releases depName=immich-app/immich
  default = "v2.7.5"
}

variable "NODEJS_VERSION" {
  default = "24.14.1"
}

variable "UV_IMAGE" {
  default = "ghcr.io/astral-sh/uv:0.8.15"
}

variable "MISE_IMAGE" {
  default = "ghcr.io/jdx/mise:2026.3.12"
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
    MISE_IMAGE                 = "${MISE_IMAGE}"
    NODEJS_VERSION             = "${NODEJS_VERSION}"
    UV_IMAGE                   = "${UV_IMAGE}"
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
