from fastapi import FastAPI, HTTPException
import os
import redis
import uuid

app = FastAPI()

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
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
        raise HTTPException(status_code=503, detail=f"redis unavailable: {exc}")



@app.post("/jobs", status_code=201)
def create_job():
    try:
        job_id = str(uuid.uuid4())
        r.lpush(JOB_QUEUE_NAME, job_id)
        r.hset(f"job:{job_id}", mapping={"status": "queued"})
        return {"job_id": job_id, "status": "queued"}
    except redis.RedisError as exc:
        raise HTTPException(status_code=503, detail=f"failed to queue job: {exc}")



@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    try:
        status = r.hget(f"job:{job_id}", "status")
    except redis.RedisError as exc:
        raise HTTPException(status_code=503, detail=f"failed to fetch job: {exc}")

    if status is None:
        raise HTTPException(status_code=404, detail="job not found")

    return {"job_id": job_id, "status": status}
