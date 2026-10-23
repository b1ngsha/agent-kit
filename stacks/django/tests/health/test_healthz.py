from django.test import Client


def test_healthz_returns_no_content(client: Client) -> None:
    response = client.get("/healthz")

    assert response.status_code == 204
    assert response.content == b""


def test_healthz_accepts_only_get(client: Client) -> None:
    response = client.post("/healthz")

    assert response.status_code == 405
