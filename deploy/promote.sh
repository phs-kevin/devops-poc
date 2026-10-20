#!/bin/bash
# Adds a release version to an image staging already built; nothing is rebuilt.
# Usage: promote.sh <staged-tag> <version>    e.g. promote.sh sha-<commit> 1.4.0
# Fails if <staged-tag> isn't in ECR (the commit never went through staging).
# Succeeds without changes if <version> already points at that image, so
# re-runs and rollbacks take the same path as a new release.
set -euo pipefail
SRC=$1
VERSION=$2
REPO=${ECR_REPOSITORY:-devops-poc/shn-site}

digest() {
  aws ecr describe-images --repository-name "$REPO" --image-ids imageTag="$1" \
    --query 'imageDetails[0].imageDigest' --output text 2>/dev/null
}

SRC_DIGEST=$(digest "$SRC") || {
  echo "::error::$SRC is not in ECR; this commit never went through staging"
  exit 1
}

if VERSION_DIGEST=$(digest "$VERSION"); then
  if [ "$VERSION_DIGEST" = "$SRC_DIGEST" ]; then
    echo "$VERSION already points at $SRC ($SRC_DIGEST)"
    exit 0
  fi
  echo "::error::$VERSION already exists for a different image ($VERSION_DIGEST)"
  exit 1
fi

# Re-put the staged manifest under the new tag. Accept multi-arch/attestation
# indexes too, since docker build may push one.
IMAGE=$(aws ecr batch-get-image --repository-name "$REPO" --image-ids imageTag="$SRC" --output json \
  --accepted-media-types application/vnd.oci.image.index.v1+json application/vnd.oci.image.manifest.v1+json \
    application/vnd.docker.distribution.manifest.list.v2+json application/vnd.docker.distribution.manifest.v2+json)

aws ecr put-image --repository-name "$REPO" --image-tag "$VERSION" \
  --image-manifest "$(jq -r '.images[0].imageManifest' <<<"$IMAGE")" \
  --image-manifest-media-type "$(jq -r '.images[0].imageManifestMediaType' <<<"$IMAGE")" >/dev/null
echo "tagged $SRC ($SRC_DIGEST) as $VERSION"
