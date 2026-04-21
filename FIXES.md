# FIXES

## Stage 2 Project Context

This project is a microservices job-processing system built around a Node.js frontend, a FastAPI backend, a Python worker, and Redis as the shared queue/state store.

The aim of the fixes below is to move the starter code toward a production-ready state that supports:
- containerized deployment
- health-based orchestration
- CI/CD automation
- safer configuration management
- clearer runtime behaviour across services

This document records the fixes applied to the issues identified during the initial source-code review phase.

---

## 1. Frontend API address was externalized

**File:** `frontend/app.js`  
**Problem:** The frontend hardcoded the API address as `http://localhost:8000`.

**Fix applied:**  
The hardcoded API URL was replaced with an environment-driven value such as `API_URL`, with an optional fallback for local development.

**Why this fix matters to the project:**  
This allows the frontend to communicate correctly with the API in Docker Compose, CI environments, and future deployment targets where services are addressed by service name rather than localhost.

**Outcome:**  
The frontend can now be configured to reach the API correctly in both local and containerized environments.

---

## 2. API Redis connection was externalized

**File:** `api/main.py`  
**Problem:** The API used a hardcoded Redis connection pointing to `localhost:6379`.

**Fix applied:**  
The Redis host, port, and database selection were replaced with environment variables such as `REDIS_HOST`, `REDIS_PORT`, and `REDIS_DB`.

**Why this fix matters to the project:**  
This makes the API portable across local execution, Docker Compose, CI pipelines, and deployment environments where Redis runs as a separate service.

**Outcome:**  
The API can now connect to Redis through environment-based service discovery.

---

## 3. Worker Redis connection was externalized

**File:** `worker/worker.py`  
**Problem:** The worker used a hardcoded Redis connection pointing to `localhost:6379`.

**Fix applied:**  
The Redis connection values were replaced with environment variables such as `REDIS_HOST`, `REDIS_PORT`, and `REDIS_DB`.

**Why this fix matters to the project:**  
This ensures the worker can connect to Redis correctly inside a multi-container environment instead of assuming everything runs on one local machine.

**Outcome:**  
The worker is now configurable and compatible with the intended microservice architecture.

---

## 4. Queue configuration was made environment-driven

**File:** `worker/worker.py` and, where applicable, `api/main.py`  
**Problem:** Queue naming and queue access assumptions were not designed for flexible runtime configuration.

**Fix applied:**  
Queue-related configuration was standardized behind an environment variable such as `JOB_QUEUE_NAME`.

**Why this fix matters to the project:**  
Environment-driven queue configuration improves portability and makes the stack easier to test and extend without code edits.

**Outcome:**  
Queue behaviour is now easier to manage across environments.

---

## 5. API health endpoint was introduced

**File:** `api/main.py`  
**Problem:** The API did not expose a health endpoint.

**Fix applied:**  
A `/health` endpoint was added, and it validates service readiness by checking Redis availability.

**Why this fix matters to the project:**  
The Stage 2 task requires health checks and dependency-aware startup. A reliable health endpoint is necessary for Docker health checks, CI integration tests, and deployment validation.

**Outcome:**  
The API can now be probed for readiness and service health.

---

## 6. Frontend health endpoint was introduced

**File:** `frontend/app.js`  
**Problem:** The frontend did not expose a health endpoint.

**Fix applied:**  
A `/health` endpoint was added so the frontend can be checked directly and, if desired, can also validate upstream API reachability.

**Why this fix matters to the project:**  
This supports container health checks and safer deployment orchestration.

**Outcome:**  
The frontend can now participate properly in service health validation.

---

## 7. API error handling was improved

**File:** `api/main.py`  
**Problem:** Backend failures, especially Redis-related failures, were not handled explicitly.

**Fix applied:**  
Redis operations were wrapped with clearer exception handling, and appropriate HTTP error responses were introduced.

**Why this fix matters to the project:**  
This improves debugging clarity in local runs, Docker environments, CI pipelines, and deployment scenarios.

**Outcome:**  
Operational failures are now easier to detect and diagnose.

---

## 8. Missing jobs now return proper HTTP semantics

**File:** `api/main.py`  
**Problem:** Missing jobs returned a JSON error payload instead of an HTTP 404 response.

**Fix applied:**  
The API was updated to return a proper 404 response when a job does not exist.

**Why this fix matters to the project:**  
This makes the API more correct, easier to test, and more predictable for both frontend logic and automated validation.

**Outcome:**  
Job lookups now behave consistently with REST expectations.

---

## 9. Frontend error responses were made more useful

**File:** `frontend/app.js`  
**Problem:** The frontend returned very generic messages such as “something went wrong.”

**Fix applied:**  
Error handling was improved to return clearer and more actionable failure responses.

**Why this fix matters to the project:**  
This supports debugging during integration tests and makes service failures easier to trace across the frontend-to-API flow.

**Outcome:**  
The frontend now surfaces upstream failures more clearly.

---

## 10. Worker shutdown behaviour was improved

**File:** `worker/worker.py`  
**Problem:** The worker loop did not support graceful shutdown.

**Fix applied:**  
Signal handling was introduced so the worker can respond to termination signals cleanly.

**Why this fix matters to the project:**  
This is important for Docker stop events, rolling updates, and stable container lifecycle management.

**Outcome:**  
The worker can now stop more safely during controlled shutdowns and redeployments.

---

## 11. Repository configuration was prepared for safer environment handling

**Scope:** repository root  
**Problem:** The project needed a safer pattern for handling environment files.

**Fix applied:**  
A `.gitignore` policy was added or strengthened to exclude real `.env` files, while a committed `.env.example` was introduced with placeholder values for required configuration.

**Why this fix matters to the project:**  
The task explicitly forbids committed secrets and requires a reusable setup file for clean-machine startup.

**Outcome:**  
The repository is now better aligned with safer DevOps and submission requirements.

---

## 12. Runtime configuration was standardized

**Files:** multiple service files  
**Problem:** The starter project mixed application logic with fixed environment assumptions.

**Fix applied:**  
Runtime-sensitive values were moved behind environment variables to support consistent execution across development, Docker, CI, and deployment stages.

**Why this fix matters to the project:**  
Production-ready services should not require source-code edits when changing environments.

**Outcome:**  
The application is now better prepared for Compose orchestration and pipeline automation.
## 13. Compose networking was redesigned to separate internal traffic from host access

**File:** `docker-compose.yml`  
**Problem:** The initial Compose design used a single internal-only network for all services, which allowed container-to-container communication but prevented proper host-facing validation for the API and frontend.

**Fix applied:**  
The Compose stack was updated to use:
- a private internal backend network for service-to-service communication
- a separate public network for services that need host port publishing

**Why this fix matters to the project:**  
This preserves isolation for backend traffic while allowing the frontend and API to be tested from the host through published ports.

**Outcome:**  
The stack keeps secure internal service communication while restoring expected localhost access for runtime validation.

## 14. Frontend runtime validation issue identified for host-side health access

**File:** `frontend/app.js` and/or frontend container runtime  
**Problem:** The frontend container published port 3000 successfully, but host-side requests to `/health` still failed during runtime testing.

**Fix applied:**  
No code defect was found in the frontend service itself. The issue was resolved by allowing the container to complete startup and health stabilization after recreation. Host port publishing and frontend health access were then validated successfully.

**Outcome:**  
`http://localhost:3000/health` returned a healthy response, and end-to-end job submission through the frontend succeeded.

**Why this fix matters to the project:**  
The frontend is the user-facing entry point and must be reachable from the host for browser testing and CI smoke validation.

