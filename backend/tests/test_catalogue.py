from app.catalogue import importer
from app.models import Radio

ORLEANS_API = {
    "slug": "radio-campus-orleans",
    "title": "Radio Campus Orléans",
    "city": "Orléans",
    "contentExcerpt": "La radio des étudiants",
    "playerMetadata": {"title": "RADIO CAMPUS ORLÉANS - 88.3 FM"},
    "category": {"color": "#2154ff"},
    "imageUrl": {"card": {"1x": "https://api.radio-campus.org/orleans.png"}},
    "mediaUrl": "https://www.radiocampus.fr/audio/live/radio-campus-orleans",
}
SANS_SITE_API = {"slug": "radio-campus-france", "title": "Radio Campus France"}


def test_import_cree_les_radios(client, db):
    assert importer(db, [ORLEANS_API, SANS_SITE_API]) == (2, 0)

    radios = client.get("/radios").json()
    # Dans l'ordre de l'API Radio Campus
    assert [r["slug"] for r in radios] == ["radio-campus-orleans", "radio-campus-france"]
    assert [r["position"] for r in radios] == [0, 1]
    orleans = radios[0]
    assert orleans["name"] == "Radio Campus Orléans"
    assert orleans["city"] == "Orléans"
    assert orleans["slogan"] == "RADIO CAMPUS ORLÉANS - 88.3 FM"
    assert orleans["category_color"] == "#2154ff"
    assert orleans["image_url"] == "https://api.radio-campus.org/orleans.png"
    assert orleans["live_url"].endswith("/radio-campus-orleans")
    assert orleans["website_url"] == "https://orleans.radiocampus.org/"
    # Site officiel connu -> affiché par défaut ; sinon version appli
    assert orleans["site"] is True
    assert radios[1]["site"] is False and radios[1]["website_url"] is None


def test_reimport_garde_les_reglages_du_gerant(db):
    importer(db, [ORLEANS_API])
    radio = db.query(Radio).one()
    radio.site = False
    radio.color = "#E30613"
    radio.stream_url = "https://flux.perso.fr/live"
    db.commit()

    renomme = {**ORLEANS_API, "title": "Radio Campus Orléans 88.3"}
    assert importer(db, [renomme]) == (0, 1)
    db.refresh(radio)
    assert radio.name == "Radio Campus Orléans 88.3"
    assert (radio.site, radio.color, radio.stream_url) == (False, "#E30613", "https://flux.perso.fr/live")


def test_radio_ajoutee_a_la_main_en_fin_de_liste(client, db):
    importer(db, [ORLEANS_API, SANS_SITE_API])
    db.add(Radio(slug="a-la-main", name="AAA radio ajoutée à la main"))
    db.commit()
    slugs = [r["slug"] for r in client.get("/radios").json()]
    assert slugs == ["radio-campus-orleans", "radio-campus-france", "a-la-main"]
