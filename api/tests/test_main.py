from unittest.mock import Mock

from fastapi.testclient import TestClient
from redis import RedisError

import main


client = TestClient(main.app)


def test_health_returns_ok_when_redis_is_available(monkeypatch):
    fake_redis = Mock()
    fake_redis.ping.return_value = True
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_returns_503_when_redis_is_unavailable(monkeypatch):
    fake_redis = Mock()
    fake_redis.ping.side_effect = RedisError("redis unavailable")
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.get("/health")

    assert response.status_code == 503
    assert "redis unavailable" in response.json()["detail"]


def test_create_job_returns_queued_job(monkeypatch):
    fake_redis = Mock()
    fake_redis.lpush.return_value = 1
    fake_redis.hset.return_value = 1
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.post("/jobs")

    assert response.status_code == 201
    data = response.json()
    assert "job_id" in data
    assert data["status"] == "queued"
    fake_redis.hset.assert_called_once()
    fake_redis.lpush.assert_called_once()


def test_create_job_returns_503_when_queue_fails(monkeypatch):
    fake_redis = Mock()
    fake_redis.lpush.side_effect = RedisError("queue failed")
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.post("/jobs")

    assert response.status_code == 503
    assert "failed" in response.json()["detail"] or "queue" in response.json()["detail"]
