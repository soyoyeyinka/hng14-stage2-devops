import os
import signal
import time
import redis

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

RUNNING = True


def handle_shutdown(signum, frame):
    global RUNNING
    RUNNING = False
    print(f"Received signal {signum}. Shutting down worker...")


signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)


def process_job(job_id):
    print(f"Processing job {job_id}")
    time.sleep(2)
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")


while RUNNING:
    result = r.brpop(JOB_QUEUE_NAME, timeout=5)
    if not result:
        continue

    _, job_id = result
    process_job(job_id)
