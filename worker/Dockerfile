FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system appgroup \
    && adduser --system --ingroup appgroup appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY worker.py .

USER appuser

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import os, redis; r=redis.Redis(host=os.getenv('REDIS_HOST','redis'), port=int(os.getenv('REDIS_PORT','6379')), db=int(os.getenv('REDIS_DB','0')), decode_responses=True); r.ping()" || exit 1

CMD ["python", "worker.py"]
