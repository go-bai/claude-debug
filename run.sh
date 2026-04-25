#!/bin/bash
# Non-sensitive vars via export:
#   export ANTHROPIC_BASE_URL=https://your-proxy.internal
#   export ANTHROPIC_MODEL=claude-opus-4-7
#   export ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001
#
# ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY are prompted interactively (not stored in shell history)
#
# Optional:
#   CLAUDE_IMAGE  — image, default ghcr.io/go-bai/claude-debug:latest
#   RUNTIME       — force runtime: nerdctl or docker

set -e

if [ -n "$CLAUDE_IMAGE" ]; then
  IMAGE="$CLAUDE_IMAGE"
else
  BASE_IMAGE="ghcr.io/go-bai/claude-debug:latest"
  COUNTRY=$(curl -sf --max-time 5 https://ipinfo.io/country 2>/dev/null)
  if [ "$COUNTRY" = "CN" ]; then
    IMAGE="m.daocloud.io/${BASE_IMAGE}"
    echo "China detected, using mirror: $IMAGE"
  else
    IMAGE="$BASE_IMAGE"
  fi
fi

if [ -n "$RUNTIME" ]; then
  CTR="$RUNTIME"
elif command -v nerdctl &>/dev/null; then
  CTR="nerdctl"
elif command -v docker &>/dev/null; then
  CTR="docker"
else
  echo "ERROR: nerdctl and docker not found" >&2
  exit 1
fi

if [ -z "$ANTHROPIC_AUTH_TOKEN" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
  read -rsp "ANTHROPIC_AUTH_TOKEN: " ANTHROPIC_AUTH_TOKEN
  echo
  export ANTHROPIC_AUTH_TOKEN
fi

KUBE_MOUNT=()
if [ -f /root/.kube/config ]; then
  TMPKUBE=$(mktemp -d)
  cp /root/.kube/config "$TMPKUBE/config"
  chmod 644 "$TMPKUBE/config"
  trap 'rm -rf "$TMPKUBE"' EXIT
  KUBE_MOUNT=(-v "$TMPKUBE/config":/home/claude/.kube/config:ro)
fi

HOST_PATH=$(echo "$PATH" | tr ':' '\n' | sed 's|^|/host|' | tr '\n' ':')

echo "Runtime: $CTR  Image: $IMAGE"

exec "$CTR" run --rm -it \
  --network host \
  --pid host \
  --ipc host \
  --privileged \
  -v /:/host \
  -v /etc/hosts:/etc/hosts:ro \
  "${KUBE_MOUNT[@]}" \
  ${ANTHROPIC_AUTH_TOKEN:+--env ANTHROPIC_AUTH_TOKEN} \
  ${ANTHROPIC_API_KEY:+--env ANTHROPIC_API_KEY} \
  ${ANTHROPIC_BASE_URL:+--env ANTHROPIC_BASE_URL} \
  ${ANTHROPIC_MODEL:+--env ANTHROPIC_MODEL} \
  ${ANTHROPIC_SMALL_FAST_MODEL:+--env ANTHROPIC_SMALL_FAST_MODEL} \
  -e PATH="${HOST_PATH}${PATH}" \
  "$IMAGE"
