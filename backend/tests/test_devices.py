from sqlalchemy import func, select

from app.models import Device


def put(client, token="tok-1", slug="orleans", platform="android"):
    return client.put(
        "/devices", json={"push_token": token, "platform": platform, "radio_slug": slug}
    )


def test_creation(client, radios):
    r = put(client)
    assert r.status_code == 200
    assert r.json()["radio_slug"] == "orleans"
    assert r.json()["platform"] == "android"


def test_changer_de_radio_remplace_l_ancienne(client, db, radios):
    put(client, slug="orleans")
    r = put(client, slug="tours")
    assert r.json()["radio_slug"] == "tours"
    assert db.scalar(select(func.count()).select_from(Device)) == 1


def test_se_desabonner(client, radios):
    put(client)
    r = put(client, slug=None)
    assert r.status_code == 200
    assert r.json()["radio_slug"] is None


def test_slug_inconnu(client, radios):
    assert put(client, slug="inexistante").status_code == 404


def test_radio_slug_obligatoire(client, radios):
    r = client.put("/devices", json={"push_token": "tok-1", "platform": "android"})
    assert r.status_code == 422


def test_meme_jeton_deux_fois_une_seule_ligne(client, db, radios):
    put(client)
    put(client)
    assert db.scalar(select(func.count()).select_from(Device)) == 1


def test_get_et_delete(client, radios):
    put(client, token="a:b-c_d")  # caractères présents dans les vrais jetons FCM
    r = client.get("/devices/a:b-c_d")
    assert r.status_code == 200 and r.json()["radio_slug"] == "orleans"

    assert client.delete("/devices/a:b-c_d").status_code == 204
    assert client.get("/devices/a:b-c_d").status_code == 404
    assert client.delete("/devices/a:b-c_d").status_code == 204  # idempotent
