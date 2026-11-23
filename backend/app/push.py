"""Envoi des notifications push via Firebase Cloud Messaging (FCM).

Toute la logique FCM est ici. Sans clé Firebase (FIREBASE_CREDENTIALS absent),
les envois sont seulement écrits dans les logs et considérés comme réussis :
le reste de l'API se développe et se teste sans compte Firebase.
"""

import logging

from app.config import settings

logger = logging.getLogger("uvicorn.error")

# Limite FCM : 500 jetons maximum par envoi groupé
FCM_BATCH_SIZE = 500

_firebase_ready = False


def init_firebase() -> None:
    """À appeler une seule fois au démarrage de l'API (lifespan)."""
    global _firebase_ready
    path = settings.FIREBASE_CREDENTIALS
    if path is None:
        logger.warning(
            "FIREBASE_CREDENTIALS non défini : les notifications sont simulées (logs uniquement)"
        )
        return
    if not path.is_file():
        raise RuntimeError(
            f"FIREBASE_CREDENTIALS pointe vers {path}, mais ce fichier n'existe pas. "
            "Placer la clé dans backend/secrets/firebase.json ou retirer la variable du .env."
        )

    import firebase_admin
    from firebase_admin import credentials

    try:
        firebase_admin.get_app()
    except ValueError:  # pas encore initialisée (le --reload peut rappeler le lifespan)
        firebase_admin.initialize_app(credentials.Certificate(path))
    _firebase_ready = True
    logger.info("Firebase initialisé : les notifications sont envoyées pour de vrai")


def send_push(
    tokens: list[str], title: str, body: str, data: dict[str, str]
) -> tuple[int, list[str]]:
    """Envoie la notification à tous les jetons.

    Renvoie (nombre de réussites, jetons invalides). Les jetons invalides
    correspondent à des appareils où l'app a été désinstallée : à supprimer.
    """
    if not tokens:
        return 0, []

    if not _firebase_ready:
        logger.info(
            "[notification simulée] %d appareil(s) | %s | %s | %s",
            len(tokens), title, body, data,
        )
        return len(tokens), []

    from firebase_admin import exceptions, messaging

    success_count = 0
    invalid_tokens: list[str] = []

    for start in range(0, len(tokens), FCM_BATCH_SIZE):
        batch = tokens[start : start + FCM_BATCH_SIZE]
        message = messaging.MulticastMessage(
            tokens=batch,
            notification=messaging.Notification(title=title, body=body),
            data=data,
            android=messaging.AndroidConfig(priority="high"),
        )
        try:
            response = messaging.send_each_for_multicast(message)
        except exceptions.FirebaseError:
            # Échec global (clé révoquée, réseau...) : on passe au lot suivant
            logger.exception("Échec de l'envoi FCM d'un lot de %d jetons", len(batch))
            continue

        success_count += response.success_count
        invalid_tokens.extend(_invalid_tokens(batch, response.responses))

    return success_count, invalid_tokens


def _invalid_tokens(batch: list[str], responses: list) -> list[str]:
    from firebase_admin import exceptions, messaging

    invalid: list[str] = []
    bad_argument: list[str] = []
    for token, response in zip(batch, responses):
        if response.success:
            continue
        error = response.exception
        if isinstance(error, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
            invalid.append(token)
        elif isinstance(error, exceptions.InvalidArgumentError):
            bad_argument.append(token)
        else:
            logger.warning("Envoi FCM refusé pour un jeton : %s", error)

    # INVALID_ARGUMENT vise d'habitude un jeton mal formé. Mais si TOUT le lot
    # échoue ainsi, c'est le message qui est en cause : on ne supprime rien.
    if bad_argument and len(bad_argument) == len(batch):
        logger.error("FCM a refusé tout le lot (INVALID_ARGUMENT) : message invalide ?")
    else:
        invalid.extend(bad_argument)
    return invalid
