import pytest


@pytest.fixture(autouse=True)
def clear_app_env(monkeypatch):
    # Ensure unit tests don't require AWS/env vars.
    monkeypatch.delenv("DB_SECRET_ARN", raising=False)
    monkeypatch.delenv("REDIS_ENDPOINT", raising=False)
    monkeypatch.delenv("AWS_REGION", raising=False)


def test_health_endpoint():
    # Import inside test so env clearing happens before Flask app init.
    from main import app

    client = app.test_client()
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "ok"

