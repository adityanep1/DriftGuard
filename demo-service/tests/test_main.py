from fastapi.testclient import TestClient

from app.main import app, ready


def test_healthz_reports_ready_after_startup():
    with TestClient(app) as client:
        response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_healthz_never_reports_false_readiness():
    ready.clear()
    with TestClient(app) as client:
        # The lifespan establishes readiness only after startup completes.
        assert client.get("/healthz").status_code == 200
    ready.clear()
    response = TestClient(app, raise_server_exceptions=False).get("/healthz")
    assert response.status_code == 503
    assert response.json() == {"status": "not_ready"}


def test_metrics_is_prometheus_exposition():
    with TestClient(app) as client:
        response = client.get("/metrics")
    assert response.status_code == 200
    assert "# HELP" in response.text
    assert "demo_service_requests_total" in response.text


def test_work_route_returns_service_payload():
    with TestClient(app) as client:
        response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "demo-service"
