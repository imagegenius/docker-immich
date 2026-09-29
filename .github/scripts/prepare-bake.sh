#!/usr/bin/env bash
set -euo pipefail

# Scope metadata and cache exports to each target, while sharing one builder.
while read -r variant; do
  cache="ghcr.io/$OWNER/$APP-cache:$variant-$ARCH"
  jq --arg target "image-$variant" \
    --arg platform "$PLATFORM" \
    --arg cache "$cache" \
    --arg image "ghcr.io/$OWNER/$APP" \
    --arg local "$APP:sandbox-$variant" \
    --arg title "$APP-$variant" \
    --arg owner "$OWNER" \
    --arg revision "$REVISION" \
    --argjson release "$RELEASE" '
    .target["docker-metadata-action"]
    # Keep the upstream source label inherited from docker-bake.hcl.
    | del(.labels["org.opencontainers.image.source"])
    | .labels += {
        "org.opencontainers.image.title": $title,
        "org.opencontainers.image.revision": $revision,
        "org.opencontainers.image.vendor": $owner
      }
    | .platforms = [$platform]
    | .["cache-from"] = ["type=registry,ref=" + $cache]
    | .["cache-to"] = (if $release then
        ["type=registry,ref=" + $cache + ",mode=max,compression=zstd,force-compression=true"]
      else [] end)
    | .output = (if $release then
        ["type=image,name=" + $image + ",push-by-digest=true,name-canonical=true,push=true,compression=gzip,force-compression=true,oci-mediatypes=true"]
      else ["type=docker"] end)
    | .tags = (if $release then [] else [$local] end)
    | {target: {($target): .}}
  ' "$RUNNER_TEMP/metadata/$variant-bake-metadata/docker-metadata-action-bake.json"
done < <(jq -r '.[]' <<<"$VARIANTS") >"$RUNNER_TEMP/ci-targets.json"

jq -s 'reduce .[] as $item ({}; . * $item)' "$RUNNER_TEMP/ci-targets.json" >"$RUNNER_TEMP/ci-bake.json"
echo "targets=$(jq -r 'map("image-" + .) | join(",")' <<<"$VARIANTS")" >>"$GITHUB_OUTPUT"
