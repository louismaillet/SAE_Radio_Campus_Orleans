from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.models import Device, Notification
from tests.conftest import auth_header

URL = "/radios/orleans/notifications"
MESSAGE = {"title": "Concert ce soir", "body": "Rendez-vous à 20 h au campus"}


def subscribe(client, token, slug):
    client.put("/devices", json={"push_token": token, "platform": "android", "radio_slug": slug})


def test_non_connecte(client, users, fake_push):
    assert client.post(URL, json=MESSAGE).status_code == 401


def test_non_admin(client, users, fake_push):
    r = client.post(URL, json=MESSAGE, headers=auth_header(users["membre_orleans"]))
    assert r.status_code == 403


def test_admin_d_une_autre_radio(client, users, fake_push):
    r = client.post(URL, json=MESSAGE, headers=auth_header(users["admin_tours"]))
    assert r.status_code == 403
    r = client.get(URL, headers=auth_header(users["admin_tours"]))
    assert r.status_code == 403


def test_texte_vide_ou_trop_long(client, users, fake_push):
    h = auth_header(users["admin_orleans"])
    assert client.post(URL, json={"title": "   ", "body": "x"}, headers=h).status_code == 422
    assert client.post(URL, json={"title": "x" * 101, "body": "x"}, headers=h).status_code == 422
    assert client.post(URL, json={"title": "x", "body": "x" * 501}, headers=h).status_code == 422


def test_seuls_les_abonnes_de_cette_radio(client, db, users, fake_push):
    subscribe(client, "o1", "orleans")
    subscribe(client, "o2", "orleans")
    subscribe(client, "t1", "tours")
    subscribe(client, "aucune", None)

    r = client.post(URL, json=MESSAGE, headers=auth_header(users["admin_orleans"]))
    assert r.status_code == 202
    body = r.json()
    assert body["recipients_count"] == 2
    assert body["sender_id"] == users["admin_orleans"].id

    assert len(fake_push.calls) == 1
    call = fake_push.calls[0]
    assert sorted(call["tokens"]) == ["o1", "o2"]
    assert call["title"] == MESSAGE["title"]
    assert call["data"] == {"radio_slug": "orleans", "notification_id": str(body["id"])}
    # FCM n'accepte que des chaînes dans data
    assert all(isinstance(v, str) for v in call["data"].values())

    notification = db.get(Notification, body["id"])
    db.refresh(notification)
    assert notification.success_count == 2


def test_sans_abonne(client, users, fake_push):
    r = client.post(URL, json=MESSAGE, headers=auth_header(users["admin_orleans"]))
    assert r.status_code == 202
    assert r.json()["recipients_count"] == 0
    assert r.json()["success_count"] == 0
    assert fake_push.calls == []


def test_limite_par_jour(client, users, fake_push):
    h = auth_header(users["admin_orleans"])
    for _ in range(5):
        assert client.post(URL, json=MESSAGE, headers=h).status_code == 202
    r = client.post(URL, json=MESSAGE, headers=h)
    assert r.status_code == 429
    assert "5 notifications" in r.json()["detail"]

    # La limite est par radio : Tours peut toujours envoyer
    r = client.post(
        "/radios/tours/notifications", json=MESSAGE, headers=auth_header(users["admin_tours"])
    )
    assert r.status_code == 202


def test_un_envoi_de_plus_de_24h_ne_compte_plus(client, db, users, radios, fake_push):
    orleans, _ = radios
    old = datetime.now(timezone.utc) - timedelta(hours=25)
    recent = datetime.now(timezone.utc) - timedelta(hours=23)
    db.add_all(
        [Notification(radio_id=orleans.id, title="t", body="b", created_at=old) for _ in range(5)]
        + [Notification(radio_id=orleans.id, title="t", body="b", created_at=recent)]
    )
    db.commit()

    h = auth_header(users["admin_orleans"])
    assert client.get(URL, headers=h).json()["remaining_today"] == 4
    assert client.post(URL, json=MESSAGE, headers=h).status_code == 202


def test_jeton_invalide_supprime(client, db, users, fake_push):
    subscribe(client, "valide", "orleans")
    subscribe(client, "desinstalle", "orleans")
    fake_push.invalid = {"desinstalle"}

    r = client.post(URL, json=MESSAGE, headers=auth_header(users["admin_orleans"]))
    assert r.status_code == 202

    tokens = db.scalars(select(Device.push_token)).all()
    assert tokens == ["valide"]
    notification = db.get(Notification, r.json()["id"])
    db.refresh(notification)
    assert notification.success_count == 1
    assert notification.recipients_count == 2


def test_historique(client, users, fake_push):
    subscribe(client, "o1", "orleans")
    h = auth_header(users["admin_orleans"])
    client.post(URL, json={"title": "Premier", "body": "a"}, headers=h)
    client.post(URL, json={"title": "Second", "body": "b"}, headers=h)

    r = client.get(URL, headers=h)
    assert r.status_code == 200
    data = r.json()
    assert data["daily_limit"] == 5
    assert data["remaining_today"] == 3
    assert data["subscribers_count"] == 1
    assert [n["title"] for n in data["notifications"]] == ["Second", "Premier"]

    r = client.get("/radios/orleans/subscribers/count", headers=h)
    assert r.json() == {"count": 1}
