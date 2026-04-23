from fastapi import FastAPI, HTTPException
import os
import uuid

import redis

app = FastAPI(title="HNG Stage 2 Job API")

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
JOB_QUEUE_NAME = os.getenv("JOB_QUEUE_NAME", "job")

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    db=REDIS_DB,
    decode_responses=True,
)


@app.get("/health")
def health():
    try:
        r.ping()
        return {"status": "ok"}
    except redis.RedisError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"redis unavailable: {exc}",
        ) from exc


@app.post("/jobs", status_code=201)
def create_job():
    job_id = str(uuid.uuid4())

    try:
        r.hset(f"job:{job_id}", mapping={"status": "queued"})
        r.lpush(JOB_QUEUE_NAME, job_id)
        return {"job_id": job_id, "status": "queued"}
    except redis.RedisError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"failed to queue job: {exc}",
        ) from exc


@app.get("/jobs/{job_id}")
@app.get("/status/{job_id}")
def get_job(job_id: str):
    try:
        job = r.hgetall(f"job:{job_id}")
    except redis.RedisError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"failed to fetch job: {exc}",
        ) from exc

    if not job:
        raise HTTPException(status_code=404, detail="job not found")

    return {
        "job_id": job_id,
        "status": job.get("status", "unknown"),
    }
