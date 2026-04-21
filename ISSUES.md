# ISSUES

## Stage 2 Project Context

This project is a microservices job-processing system made up of:
- a Node.js frontend for submitting and tracking jobs
- a FastAPI service for job creation and status retrieval
- a Python worker for processing queued jobs
- a Redis instance shared by the API and the worker

The Stage 2 assessment requires the application to be made production-ready through debugging, containerization, health checks, environment-driven configuration, and CI/CD automation.

This document records the issues identified during the initial source-code review of the starter application before full container, integration, and pipeline validation.

---

## 1. Hardcoded API address in the frontend

**File:** `frontend/app.js`  
**Issue:** The frontend defines the API base URL as `http://localhost:8000`.

**Why this is a problem:**  
In a containerized microservices environment, `localhost` refers to the frontend container itself, not the API container. This means the frontend will fail to communicate with the API once the services are separated into containers.

**Project impact:**  
This directly breaks job submission and job status tracking from the frontend in Docker Compose and CI integration testing.

---

## 2. Hardcoded Redis connection in the API

**File:** `api/main.py`  
**Issue:** The API connects to Redis using a hardcoded `localhost:6379`.

**Why this is a problem:**  
Inside containers, Redis will run as its own service, so `localhost` will not point to the Redis container. The API will therefore fail to create jobs or retrieve job state correctly when deployed in the intended microservice setup.

**Project impact:**  
This breaks the API’s ability to push jobs to the queue and store or read job status.

---

## 3. Hardcoded Redis connection in the worker

**File:** `worker/worker.py`  
**Issue:** The worker connects to Redis using a hardcoded `localhost:6379`.

**Why this is a problem:**  
Like the API, the worker cannot depend on localhost in a multi-container environment. It must connect to Redis by service name or environment variable.

**Project impact:**  
This prevents the worker from pulling jobs from the queue and marking them completed.

---

## 4. Missing health endpoint in the API

**File:** `api/main.py`  
**Issue:** The API does not expose a dedicated health endpoint.

**Why this is a problem:**  
The task requires Docker health checks and dependency startup based on healthy services, not merely started containers. Without a health endpoint, the API cannot be checked reliably by Docker Compose or deployment scripts.

**Project impact:**  
This weakens orchestration, deployment safety, and automated validation in CI/CD.

---

## 5. Missing health endpoint in the frontend

**File:** `frontend/app.js`  
**Issue:** The frontend does not expose a dedicated health endpoint.

**Why this is a problem:**  
The brief requires every service image to include a working health check. Without a defined health route, the frontend cannot be validated reliably in Docker or during rolling deployment.

**Project impact:**  
This increases the risk of false-positive container startups and weakens deployment verification.

---

## 6. Configuration is not environment-driven

**Files:** `frontend/app.js`, `api/main.py`, `worker/worker.py`  
**Issue:** Important runtime values are hardcoded directly in source files.

**Why this is a problem:**  
The task explicitly requires configuration to come from environment variables. Hardcoded configuration reduces portability and makes the application fragile across local, Docker, CI, and deployment environments.

**Project impact:**  
This makes the stack harder to containerize, test, and deploy consistently.

---

## 7. Weak production error handling

**Files:** `frontend/app.js`, `api/main.py`  
**Issue:** Error handling is minimal and returns overly generic responses.

**Why this is a problem:**  
Generic failure messages make debugging harder during integration testing, pipeline execution, and deployment troubleshooting.

**Project impact:**  
This slows down fault diagnosis and reduces observability when something fails in the job flow.

---

## 8. Missing proper HTTP semantics for not-found jobs

**File:** `api/main.py`  
**Issue:** When a job does not exist, the API returns a JSON error payload instead of a proper HTTP 404 response.

**Why this is a problem:**  
APIs should communicate failure conditions using the correct HTTP status codes. Returning a normal JSON object for missing resources makes the API less predictable and less testable.

**Project impact:**  
This weakens API correctness and complicates unit and integration tests.

---

## 9. Worker lacks graceful shutdown handling

**File:** `worker/worker.py`  
**Issue:** The worker runs in an infinite loop without proper shutdown handling.

**Why this is a problem:**  
Containers are routinely stopped and restarted during deploys, compose restarts, and health-related replacements. Without signal handling, the worker may terminate abruptly.

**Project impact:**  
This reduces reliability during rolling updates and controlled shutdowns.

---

## 10. Initial repository safety gaps

**Scope:** repository configuration  
**Issue:** The starter structure does not yet provide a clear committed `.env.example` and proper repository protection for environment files.

**Why this is a problem:**  
The brief explicitly forbids committing real `.env` files and requires a `.env.example` with placeholder values.


