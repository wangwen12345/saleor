#!/usr/bin/env bash
set -Eeuo pipefail

# Deploy this repo to a remote Linux host via SSH and run scripts/deploy.sh there.
# Requirements on remote: Docker + Docker Compose v2
# Usage (env):
#   DEPLOY_SSH_HOST=1.2.3.4 DEPLOY_SSH_USER=root DEPLOY_PATH=/opt/e_shop \
#   ADMIN_EMAIL=328951525@qq.com ADMIN_PASSWORD='ww19880422.' \
#   ./scripts/remote_deploy.sh
# Optional: DEPLOY_SSH_PORT=22 API_PORT=8001 DASHBOARD_PORT=9001 STOREFRONT_PORT=3000

: "${DEPLOY_SSH_HOST:?Set DEPLOY_SSH_HOST}"
: "${DEPLOY_SSH_USER:?Set DEPLOY_SSH_USER}"
DEPLOY_SSH_PORT=${DEPLOY_SSH_PORT:-22}
DEPLOY_PATH=${DEPLOY_PATH:-/opt/e_shop}

API_PORT=${API_PORT:-8001}
DASHBOARD_PORT=${DASHBOARD_PORT:-9001}
STOREFRONT_PORT=${STOREFRONT_PORT:-3000}

ADMIN_EMAIL=${ADMIN_EMAIL:-328951525@qq.com}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-ww19880422.}
SITE_NAME=${SITE_NAME:-emerge}

ROOT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)

echo "[INFO] Creating remote dir: ${DEPLOY_PATH}"
ssh -p "$DEPLOY_SSH_PORT" "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}" "mkdir -p '${DEPLOY_PATH}'"

echo "[INFO] Syncing project to remote..."
(cd "$ROOT_DIR" && tar --exclude-vcs -czf - saleor-platform react-storefront scripts) \
  | ssh -p "$DEPLOY_SSH_PORT" "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}" "tar xzf - -C '${DEPLOY_PATH}'"

echo "[INFO] Running remote deploy.sh"
ssh -t -p "$DEPLOY_SSH_PORT" "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}" \
  "cd '${DEPLOY_PATH}' && \
   API_PORT='${API_PORT}' DASHBOARD_PORT='${DASHBOARD_PORT}' STOREFRONT_PORT='${STOREFRONT_PORT}' \
   ADMIN_EMAIL='${ADMIN_EMAIL}' ADMIN_PASSWORD='${ADMIN_PASSWORD}' SITE_NAME='${SITE_NAME}' \
   bash scripts/deploy.sh"

echo "[INFO] Done. Access via: http://${DEPLOY_SSH_HOST}:${STOREFRONT_PORT} (storefront), http://${DEPLOY_SSH_HOST}:${DASHBOARD_PORT} (dashboard)"
