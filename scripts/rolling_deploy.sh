#!/usr/bin/env bash
set -euo pipefail

APP_NAME="hng14-stage2-devops"
NEW_TAG="${1:?usage: rolling_deploy.sh <sha-tag> [timeout-seconds]}"
TIMEOUT_SECONDS="${2:-60}"

CURRENT_PROJECT="deploy-current"
CANDIDATE_PROJECT="deploy-candidate"
DEPLOY_DIR=".deploy"

mkdir -p "${DEPLOY_DIR}"

write_env_file() {
  local target_file="$1"
  local api_image="$2"
  local worker_image="$3"
  local frontend_image="$4"
  local network_name="$5"

  cat > "${target_file}" <<ENV
REDIS_IMAGE=redis:7-alpine
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
JOB_QUEUE_NAME=job
API_URL=http://api:8000
PORT=3000
REDIS_MEM_LIMIT=256m
REDIS_CPUS=0.50
API_MEM_LIMIT=256m
API_CPUS=0.50
WORKER_MEM_LIMIT=256m
WORKER_CPUS=0.50
FRONTEND_MEM_LIMIT=256m
FRONTEND_CPUS=0.50
COMPOSE_NETWORK_NAME=${network_name}
API_IMAGE=${api_image}
WORKER_IMAGE=${worker_image}
FRONTEND_IMAGE=${frontend_image}
ENV
}

wait_for_api_http() {
  local container_name="$1"
  local timeout_seconds="$2"
  local elapsed=0

  while [ "${elapsed}" -lt "${timeout_seconds}" ]; do
    if docker exec "${container_name}" python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health'); print('ok')" >/dev/null 2>&1; then
      echo "${container_name} api health=ok"
      return 0
    fi

    echo "${container_name} api health=waiting"
    sleep 5
    elapsed=$((elapsed + 5))
  done

  return 1
}

wait_for_frontend_http() {
  local container_name="$1"
  local timeout_seconds="$2"
  local elapsed=0

  while [ "${elapsed}" -lt "${timeout_seconds}" ]; do
    if docker exec "${container_name}" node -e "fetch('http://127.0.0.1:3000/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" >/dev/null 2>&1; then
      echo "${container_name} frontend health=ok"
      return 0
    fi

    echo "${container_name} frontend health=waiting"
    sleep 5
    elapsed=$((elapsed + 5))
  done

  return 1
}

docker tag "${APP_NAME}-api:${NEW_TAG}" "${APP_NAME}-api:latest"
docker tag "${APP_NAME}-worker:${NEW_TAG}" "${APP_NAME}-worker:latest"
docker tag "${APP_NAME}-frontend:${NEW_TAG}" "${APP_NAME}-frontend:latest"

write_env_file "${DEPLOY_DIR}/current.env" \
  "${APP_NAME}-api:latest" \
  "${APP_NAME}-worker:latest" \
  "${APP_NAME}-frontend:latest" \
  "${CURRENT_PROJECT}-backend"

write_env_file "${DEPLOY_DIR}/candidate.env" \
  "${APP_NAME}-api:${NEW_TAG}" \
  "${APP_NAME}-worker:${NEW_TAG}" \
  "${APP_NAME}-frontend:${NEW_TAG}" \
  "${CANDIDATE_PROJECT}-backend"

docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/current.env" -p "${CURRENT_PROJECT}" down -v --remove-orphans || true
docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" down -v --remove-orphans || true

docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/current.env" -p "${CURRENT_PROJECT}" up -d
docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" up -d

echo "Current stack:"
docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/current.env" -p "${CURRENT_PROJECT}" ps

echo "Candidate stack:"
docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" ps

if wait_for_api_http "${CANDIDATE_PROJECT}-api-1" "${TIMEOUT_SECONDS}" && wait_for_frontend_http "${CANDIDATE_PROJECT}-frontend-1" "${TIMEOUT_SECONDS}"; then
  echo "Candidate stack is healthy. Stopping current stack."
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/current.env" -p "${CURRENT_PROJECT}" down -v
  echo "Rolling update successful. Candidate stack remains running."
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" ps
else
  echo "Candidate stack failed health checks within ${TIMEOUT_SECONDS}s. Leaving current stack running."
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" ps || true
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" logs --no-color || true
  exit 1
fi
