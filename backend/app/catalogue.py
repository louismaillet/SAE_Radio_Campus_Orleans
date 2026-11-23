"""Import du catalogue des radios depuis l'API publique Radio Campus.

Remplit (ou met à jour) la table `radios` : nom, ville, présentation, logo et
flux d'origine, site officiel, et rang dans la liste
(`position`, l'ordre de l'API). Les réglages des gérants (site, url, color,
logo_url, stream_url) ne sont jamais écrasés. Les radios absentes de l'API
sont gardées. Relançable sans risque :

    docker compose exec api python -m app.catalogue
"""

import json
import urllib.request

from sqlalchemy import select
from sqlalchemy.orm import Session

from app import database
from app.models import Radio

RADIOCAMPUS_RADIOS = "https://api.radiocampus.org/api/radios"

# Sites officiels (slug -> site). On ne prend pas le websiteUrl de l'API :
# il contient parfois des pages Facebook/Instagram. Une radio absente d'ici
# n'a pas de site : l'app affiche sa version appli.
SITES_OFFICIELS = {
    "radio-campus-47": "https://radiocampus47.fr/",
    "radio-campus-amiens-amiens": "http://www.radiocampusamiens.fr/",
    "radio-campus-angers": "https://www.radiocampusangers.com/",
    "radio-campus-avignon": "https://avignon.radiocampus.fr/",
    "radio-campus-besancon": "https://campusbesancon.fr/",
    "radio-campus-bordeaux": "https://www.radiocampusbordeaux.fr/",
    "programmationatradio-u-org": "https://www.radio-u.org/",
    "radio-phenix": "https://phenix.fm/",
    "radiom-campus-castres": "https://www.radiom.fr/",
    "radio-campus-clermont-ferrand": "https://campus-clermont.net/",
    "radio-dijon-campus": "https://radiodijoncampus.com/",
    "radio-campus-grenoble": "https://campusgrenoble.org/",
    "radio-campus-lille": "https://www.campuslille.com/",
    "radio-campus-tours": "https://www.radiocampustours.com/",
    "campus-fm-toulouse": "https://www.campusfm.net/",
    "radio-en-construction": "https://www.radioenconstruction.com/",
    "c-lab-campus-rennes": "https://www.c-lab.fr/",
    "radio-pulsar-poitiers": "https://www.radio-pulsar.org/",
    "radio-campus-pau": "https://radiocampuspau.fr/",
    "www-radiocampusparis-org": "https://www.radiocampusparis.org/",
    "radio-campus-orleans": "https://orleans.radiocampus.org/",
    "radio-mne-mulhouse": "https://www.radiomne.com/",
    "radio-campus-montpellier": "https://www.radiocampusmontpellier.fr/",
    "radio-grenouille-marseille": "https://www.radiogrenouille.com/",
    "radio-brume-lyon": "https://www.radiobrume.fr/",
    "radio-campus-lorraine-nancy-metz": "https://www.radiocampuslorraine.com/",
}


def _image(images) -> str | None:
    """L'API donne { "card": { "1x": "https://..." } } : on prend "card" en 1x."""
    if isinstance(images, dict) and isinstance(images.get("card"), dict):
        return images["card"].get("1x")
    return None


def catalogue_depuis_api(item: dict) -> dict:
    """Colonnes du catalogue pour une radio de l'API Radio Campus."""
    slug = item["slug"]
    return {
        "name": item.get("title") or slug,
        "city": item.get("city"),
        "excerpt": item.get("contentExcerpt"),
        "slogan": (item.get("playerMetadata") or {}).get("title"),
        "category_color": (item.get("category") or {}).get("color"),
        "image_url": _image(item.get("imageUrl")),
        "live_url": item.get("mediaUrl"),
        "website_url": SITES_OFFICIELS.get(slug),
    }


def importer(db: Session, items: list[dict]) -> tuple[int, int]:
    """Crée ou met à jour les radios. Renvoie (créées, mises à jour)."""
    existantes = {r.slug: r for r in db.scalars(select(Radio))}
    creees = mises_a_jour = 0
    for position, item in enumerate(items):
        slug = item["slug"]
        colonnes = catalogue_depuis_api(item)
        colonnes["position"] = position
        radio = existantes.get(slug)
        if radio is None:
            # Nouvelle radio : son site officiel est affiché par défaut s'il existe
            radio = Radio(slug=slug, site=colonnes["website_url"] is not None)
            db.add(radio)
            creees += 1
        else:
            mises_a_jour += 1
        for colonne, valeur in colonnes.items():
            setattr(radio, colonne, valeur)
    db.commit()
    return creees, mises_a_jour


def telecharger_radios() -> list[dict]:
    req = urllib.request.Request(RADIOCAMPUS_RADIOS, headers={"Accept": "application/ld+json"})
    with urllib.request.urlopen(req, timeout=30) as reponse:
        return json.loads(reponse.read().decode("utf-8"))["member"]


def main() -> None:
    items = telecharger_radios()
    with database.SessionLocal() as db:
        creees, mises_a_jour = importer(db, items)
    print(f"{len(items)} radios lues : {creees} créées, {mises_a_jour} mises à jour.")


if __name__ == "__main__":
    main()
