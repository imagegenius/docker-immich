target "docker-metadata-action" {}

variable "OWNER" {
  default = "imagegenius"
}

variable "VERSION" {
  # renovate: datasource=github-tags depName=immich-app/immich versioning=semver
  default = "v3.3.5"
}

# Upstream Immich pins these at VERSION; .github/scripts/upstream-inputs.sh reads them.
variable "IMMICH_BASE_IMAGES_VERSION" {}
variable "MISE_IMAGE" {}
variable "NODEJS_VERSION" {}
variable "ONNXRUNTIME_VERSION" {}
variable "UV_IMAGE" {}

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
    ONNXRUNTIME_VERSION        = "${ONNXRUNTIME_VERSION}"
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

group "image-all" {
  targets = ["image-main", "image-noml", "image-cuda", "image-openvino"]
}
