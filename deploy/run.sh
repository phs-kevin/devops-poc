#!/bin/bash
# Runs on the host (via SSM): pull an image tag, swap the container, check /health.
# Usage: run.sh <image-tag> [auto-rollback: true|false]
# Exit 0: new tag is healthy.
# Exit 2: new tag failed; the previous tag is running and healthy again.
# Exit 1: failed and nothing healthy is running.
set -euo pipefail
TAG=$1
AUTO_ROLLBACK=${2:-false}
source /opt/shn/env
IMAGE=$REGISTRY/$REPO
STATE=/opt/shn/current_tag
PREV=$(cat "$STATE" 2>/dev/null || true)

healthy() {
  for _ in $(seq 1 30); do
    curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

start() {
  docker rm -f shn >/dev/null 2>&1 || true
  docker run -d --name shn --restart unless-stopped -p 8000:8000 \
    -e AWS_REGION="$REGION" -e AWS_SECRET_ID="$SECRET_ID" -e IMAGE_TAG="$1" \
    "$IMAGE:$1" >/dev/null && healthy
}

rollback() {
  if [ "$AUTO_ROLLBACK" = true ] && [ -n "$PREV" ] && [ "$PREV" != "$TAG" ]; then
    echo "auto-rollback: restarting $PREV"
    if start "$PREV"; then echo "rolled back to $PREV"; exit 2; fi
  fi
  exit 1
}

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
if ! docker pull "$IMAGE:$TAG"; then
  echo "pull of $TAG failed"
  rollback
fi
if start "$TAG"; then
  echo "$TAG" > "$STATE"
  echo "deployed $TAG"
  exit 0
fi
echo "$TAG failed its health check"
docker logs --tail 50 shn 2>&1 || true
rollback
