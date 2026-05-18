#!/usr/bin/env -S just --justfile

set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

[private]
default:
    just --list

[doc('Build and test a variant locally')]
[working-directory('.cache')]
local-build variant="main":
    docker buildx bake --no-cache --metadata-file docker-bake.json --set=*.output=type=docker --load --file {{ justfile_dir() }}/docker-bake.hcl image-{{ variant }}-local
    TEST_IMAGE="$(jq -r '."image-{{ variant }}-local"."image.name" | sub("^docker.io/library/"; "")' docker-bake.json)" \
        VARIANT={{ variant }} \
        go test -v {{ justfile_dir() }}/tests/...

[doc('Trigger a remote build')]
remote-build variant="main" release="false":
    gh workflow run release.yaml -f variant={{ variant }} -f release={{ release }}
