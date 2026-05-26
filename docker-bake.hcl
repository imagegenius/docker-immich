target "docker-metadata-action" {}

variable "OWNER" {
  default = "imagegenius"
}

variable "BASE_IMAGE" {
  # renovate: datasource=docker depName=ghcr.io/imagegenius/baseimage-immich
  default = "ghcr.io/imagegenius/baseimage-immich@sha256:971e2332d0a6654d7513173385a9cb5d4ccedcbf612b49df3dbdd93fd908f545"
}

variable "VERSION" {
  # renovate: datasource=github-releases depName=immich-app/immich
  default = "v2.7.5"
}

variable "NODEJS_VERSION" {
  # renovate: datasource=github-releases depName=nodejs/node versioning=node
  default = "22.22.3"
}

variable "UV_IMAGE" {
  # renovate: datasource=docker depName=ghcr.io/astral-sh/uv
  default = "ghcr.io/astral-sh/uv:0.11.14@sha256:1025398289b62de8269e70c45b91ffa37c373f38118d7da036fb8bb8efc85d97"
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
    BASE_IMAGE     = "${BASE_IMAGE}"
    IMMICH_VERSION = "${VERSION}"
    NODEJS_VERSION = "${NODEJS_VERSION}"
    UV_IMAGE       = "${UV_IMAGE}"
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
