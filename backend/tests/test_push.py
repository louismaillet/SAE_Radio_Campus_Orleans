from types import SimpleNamespace

from firebase_admin import exceptions, messaging

from app import push


def ok():
    return SimpleNamespace(success=True, exception=None)


def ko(error_class):
    return SimpleNamespace(success=False, exception=error_class("erreur", cause=None))


def test_sans_firebase_envoi_simule():
    assert push.send_push(["a", "b"], "t", "b", {}) == (2, [])
    assert push.send_push([], "t", "b", {}) == (0, [])


def test_jetons_invalides_detectes():
    batch = ["ok", "desinstalle", "autre_projet", "mal_forme", "quota"]
    responses = [
        ok(),
        ko(messaging.UnregisteredError),
        ko(messaging.SenderIdMismatchError),
        ko(exceptions.InvalidArgumentError),
        ko(messaging.QuotaExceededError),  # erreur temporaire : on garde l'appareil
    ]
    assert push._invalid_tokens(batch, responses) == [
        "desinstalle",
        "autre_projet",
        "mal_forme",
    ]


def test_tout_le_lot_invalid_argument_ne_supprime_rien():
    # Si tout le lot échoue en INVALID_ARGUMENT, c'est le message qui est en cause
    batch = ["a", "b"]
    responses = [ko(exceptions.InvalidArgumentError), ko(exceptions.InvalidArgumentError)]
    assert push._invalid_tokens(batch, responses) == []
