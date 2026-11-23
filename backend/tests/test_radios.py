import io

from app.routers import proxy
from tests.conftest import auth_header


def test_me_donne_le_slug_de_la_radio(client, users):
    r = client.get("/auth/me", headers=auth_header(users["admin_orleans"]))
    assert r.status_code == 200
    assert r.json()["radio_slug"] == "orleans"
    assert r.json()["is_admin"] is True


def test_reglages_de_la_radio(client, users):
    h = auth_header(users["admin_orleans"])
    r = client.patch(
        "/radios/orleans",
        headers=h,
        json={
            "site": True,
            "url": "https://orleans.radiocampus.org/",
            "color": "#e30613",
            "stream_url": "https://flux.exemple.fr/live",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["color"] == "#E30613"
    assert data["stream_url"] == "https://flux.exemple.fr/live"

    # null efface le réglage
    r = client.patch("/radios/orleans", headers=h, json={"stream_url": None, "color": None})
    assert r.json()["stream_url"] is None and r.json()["color"] is None
    assert client.get("/radios/orleans").json()["site"] is True


def test_flux_invalide(client, users):
    r = client.patch(
        "/radios/orleans",
        headers=auth_header(users["admin_orleans"]),
        json={"stream_url": "pas une url"},
    )
    assert r.status_code == 422


class _FausseReponse(io.BytesIO):
    status = 200
    headers = {"Content-Type": "application/ld+json; charset=utf-8"}

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


def test_proxy_radiocampus(client, monkeypatch):
    appels = []

    def faux_urlopen(req, timeout):
        appels.append(req)
        return _FausseReponse(b'{"member": []}')

    monkeypatch.setattr(proxy.urllib.request, "urlopen", faux_urlopen)
    r = client.get("/proxy/radiocampus", params={"chemin": "/api/podcasts", "itemsPerPage": "300"})
    assert r.status_code == 200
    assert r.json() == {"member": []}
    assert appels[0].full_url == "https://api.radiocampus.org/api/podcasts?itemsPerPage=300"
    assert appels[0].get_header("Accept") == "application/ld+json"


def test_proxy_refuse_les_autres_chemins(client, monkeypatch):
    monkeypatch.setattr(proxy.urllib.request, "urlopen", lambda *a, **k: 1 / 0)
    for chemin in ["/admin", "/api/../secret", "//evil.com/api/x", "/api/x?y=1", "https://evil.com"]:
        assert client.get("/proxy/radiocampus", params={"chemin": chemin}).status_code == 400
