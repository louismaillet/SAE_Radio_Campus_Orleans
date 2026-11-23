"""Relais vers l'API publique Radio Campus, pour l'app Flutter web.

Les navigateurs ne peuvent pas appeler api.radiocampus.org directement (CORS) :
l'app web passe donc par ici. Sur Android, l'app appelle l'API Radio Campus en direct.
Seul ce serveur est joignable, et seulement en lecture (GET sur /api/...).
"""

import re
import urllib.error
import urllib.parse
import urllib.request
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Request, Response, status

router = APIRouter(prefix="/proxy", tags=["proxy"])

RADIOCAMPUS_HOST = "https://api.radiocampus.org"
# Chemins autorisés : /api/ suivi de lettres, chiffres, -, _ et / (pas de "..", pas de "?")
CHEMIN_AUTORISE = re.compile(r"^/api/[A-Za-z0-9_\-/]*$")
TIMEOUT_SECONDES = 15


@router.get("/radiocampus")
def proxy_radiocampus(
    request: Request,
    chemin: Annotated[str, Query(examples=["/api/radios"])],
):
    """Relaie `GET https://api.radiocampus.org{chemin}`. Les autres paramètres
    de la requête (ex. `itemsPerPage`) sont transmis tels quels."""
    if not CHEMIN_AUTORISE.match(chemin) or ".." in chemin:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Chemin non autorisé")

    params = [(k, v) for k, v in request.query_params.multi_items() if k != "chemin"]
    url = RADIOCAMPUS_HOST + chemin
    if params:
        url += "?" + urllib.parse.urlencode(params)

    req = urllib.request.Request(url, headers={"Accept": "application/ld+json"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDES) as reponse:
            contenu = reponse.read()
            code = reponse.status
            type_contenu = reponse.headers.get("Content-Type", "application/json")
    except urllib.error.HTTPError as erreur:
        contenu = erreur.read()
        code = erreur.code
        type_contenu = erreur.headers.get("Content-Type", "application/json")
    except (urllib.error.URLError, TimeoutError):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="L'API Radio Campus ne répond pas",
        )

    return Response(content=contenu, status_code=code, media_type=type_contenu)
