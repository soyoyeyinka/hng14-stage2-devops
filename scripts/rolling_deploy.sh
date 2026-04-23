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

wait_for_health() {
  local container_name="$1"
  local timeout_seconds="$2"
  local elapsed=0

  while [ "${elapsed}" -lt "${timeout_seconds}" ]; do
    status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_name}" 2>/dev/null || echo "missing")
    echo "${container_name} health=${status}"

    if [ "${status}" = "healthy" ]; then
      return 0
    fi

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

docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/current.env" -p "${CURRENT_PROJECT}" up -d
docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" up -d

if wait_for_health "${CANDIDATE_PROJECT}-api-1" "${TIMEOUT_SECONDS}" && wait_for_health "${CANDIDATE_PROJECT}-frontend-1" "${TIMEOUT_SECONDS}"; then
  echo "Candidate stack is healthy. Stopping current stack."
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/current.env" -p "${CURRENT_PROJECT}" down
  echo "Rolling update successful. Candidate stack remains running."
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" ps
else
  echo "Candidate stack failed health checks within ${TIMEOUT_SECONDS}s. Leaving current stack running."
  docker compose -f docker-compose.deploy.yml --env-file "${DEPLOY_DIR}/candidate.env" -p "${CANDIDATE_PROJECT}" logs --no-color || true
  exit 1
fi
