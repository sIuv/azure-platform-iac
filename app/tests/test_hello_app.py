"""Enhetstester för hello_app. Körs utan Kubernetes, direkt mot Flask."""

import pytest

from hello_app import GREETING, HEALTHY_STATUS, create_app


@pytest.fixture
def client():
    """En testklient som anropar appen utan att starta någon server."""
    return create_app().test_client()


def test_health_returns_200(client):
    response = client.get("/health")

    assert response.status_code == 200


def test_health_reports_ok_status(client):
    response = client.get("/health")

    assert response.get_json() == {"status": HEALTHY_STATUS}


def test_index_returns_greeting(client):
    response = client.get("/")

    assert response.get_json()["message"] == GREETING


def test_index_includes_hostname(client):
    response = client.get("/")

    assert response.get_json()["hostname"] != ""


def test_unknown_path_returns_404(client):
    response = client.get("/does-not-exist")

    assert response.status_code == 404
