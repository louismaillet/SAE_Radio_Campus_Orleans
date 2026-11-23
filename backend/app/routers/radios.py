import logging
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app import database
from app.auth import CurrentUser
from app.config import settings
from app.database import get_db
from app.media import delete_media, save_logo
from app.models import Device, Notification, Radio, User
from app.push import send_push
from app.schemas import (
    NotificationCreate,
    NotificationHistory,
    NotificationOut,
    RadioOut,
    RadioUpdate,
)

logger = logging.getLogger("uvicorn.error")

router = APIRouter(prefix="/radios", tags=["radios"])


def get_radio_or_404(db: Session, slug: str) -> Radio:
    radio = db.scalar(select(Radio).where(Radio.slug == slug))
    if radio is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Radio introuvable")
    return radio


def ensure_radio_admin(user: User, radio: Radio) -> None:
    """Seul l'admin de CETTE radio (is_admin = true et users.radio = radio.id) passe."""
    if not (user.is_admin and user.radio_id == radio.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seul l'admin de cette radio peut faire cette action",
        )


@router.get("", response_model=list[RadioOut])
def list_radios(db: Annotated[Session, Depends(get_db)]):
    return db.scalars(select(Radio).order_by(Radio.slug)).all()


@router.get("/{slug}", response_model=RadioOut)
def get_radio(slug: str, db: Annotated[Session, Depends(get_db)]):
    return get_radio_or_404(db, slug)


@router.patch("/{slug}", response_model=RadioOut)
def update_radio(
    slug: str,
    data: RadioUpdate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
):
    radio = get_radio_or_404(db, slug)
    ensure_radio_admin(current_user, radio)

    changes = data.model_dump(exclude_unset=True, mode="json")
    if changes.get("color"):
        changes["color"] = changes["color"].upper()
    for field, value in changes.items():
        setattr(radio, field, value)

    if radio.site and not radio.url:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Une url est obligatoire pour afficher le site de la radio",
        )

    db.commit()
    db.refresh(radio)
    return radio


@router.put("/{slug}/logo", response_model=RadioOut)
def upload_logo(
    slug: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    image: Annotated[UploadFile, File(description="PNG, JPEG, WebP ou GIF")],
):
    """multipart/form-data, champ `image`. Le logo est redimensionné (512×512 max),
    converti en WebP, et remplace l'ancien (qui est supprimé du disque)."""
    radio = get_radio_or_404(db, slug)
    ensure_radio_admin(current_user, radio)

    old_logo = radio.logo_url
    new_logo = save_logo(image)
    radio.logo_url = new_logo
    try:
        db.commit()
    except Exception:
        db.rollback()
        delete_media(new_logo)  # pas de fichier orphelin si la base refuse
        raise

    delete_media(old_logo)
    db.refresh(radio)
    return radio


@router.delete("/{slug}/logo", response_model=RadioOut)
def delete_logo(
    slug: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
):
    """Retire le logo : l'app reviendra à son logo par défaut."""
    radio = get_radio_or_404(db, slug)
    ensure_radio_admin(current_user, radio)

    old_logo = radio.logo_url
    radio.logo_url = None
    db.commit()
    delete_media(old_logo)
    db.refresh(radio)
    return radio


# ---------- Notifications ----------
def _sent_last_24h(db: Session, radio_id: int) -> int:
    since = datetime.now(timezone.utc) - timedelta(hours=24)
    return db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.radio_id == radio_id, Notification.created_at >= since)
    )


def _subscribers_count(db: Session, radio_id: int) -> int:
    return db.scalar(select(func.count()).select_from(Device).where(Device.radio_id == radio_id))


def deliver_notification(
    notification_id: int, radio_slug: str, title: str, body: str, tokens: list[str]
) -> None:
    """Tâche de fond : envoie la notification, supprime les appareils dont le
    jeton est rejeté (app désinstallée) et enregistre le nombre de réussites.
    Ouvre sa propre session : celle de la requête est déjà fermée."""
    data = {"radio_slug": radio_slug, "notification_id": str(notification_id)}
    try:
        success_count, invalid_tokens = send_push(tokens, title, body, data)
    except Exception:
        logger.exception("Échec de l'envoi de la notification %d", notification_id)
        success_count, invalid_tokens = 0, []

    with database.SessionLocal() as db:
        if invalid_tokens:
            db.execute(delete(Device).where(Device.push_token.in_(invalid_tokens)))
        notification = db.get(Notification, notification_id)
        if notification is not None:
            notification.success_count = success_count
        db.commit()


@router.post(
    "/{slug}/notifications",
    response_model=NotificationOut,
    status_code=status.HTTP_202_ACCEPTED,
)
def send_notification(
    slug: str,
    data: NotificationCreate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    background_tasks: BackgroundTasks,
):
    """Envoie une notification à tous les appareils abonnés à la radio.

    Réservé à l'admin de la radio. Limite : `NOTIFICATIONS_PER_DAY` (5) envois
    sur 24 h glissantes, sinon 429. Répond 202 tout de suite : l'envoi se fait
    en tâche de fond et `success_count` est rempli à la fin.
    """
    radio = get_radio_or_404(db, slug)
    ensure_radio_admin(current_user, radio)

    # Verrouille la radio jusqu'au commit : deux envois simultanés ne peuvent pas
    # dépasser la limite ensemble (sans effet sous SQLite, utilisé en test)
    db.execute(select(Radio.id).where(Radio.id == radio.id).with_for_update())

    if _sent_last_24h(db, radio.id) >= settings.NOTIFICATIONS_PER_DAY:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Limite de {settings.NOTIFICATIONS_PER_DAY} notifications par jour atteinte",
        )

    tokens = list(db.scalars(select(Device.push_token).where(Device.radio_id == radio.id)))

    # Créée même sans abonné : elle compte dans la limite (pas de contournement)
    notification = Notification(
        radio_id=radio.id,
        sender_id=current_user.id,
        title=data.title,
        body=data.body,
        created_at=datetime.now(timezone.utc),
        recipients_count=len(tokens),
        success_count=None if tokens else 0,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)

    if tokens:
        background_tasks.add_task(
            deliver_notification, notification.id, radio.slug, data.title, data.body, tokens
        )
    return notification


@router.get("/{slug}/notifications", response_model=NotificationHistory)
def list_notifications(
    slug: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
):
    """Historique des envois (plus récents d'abord), envois restants
    aujourd'hui et nombre d'appareils abonnés. Réservé à l'admin de la radio."""
    radio = get_radio_or_404(db, slug)
    ensure_radio_admin(current_user, radio)

    notifications = db.scalars(
        select(Notification)
        .where(Notification.radio_id == radio.id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .limit(limit)
    ).all()
    remaining = settings.NOTIFICATIONS_PER_DAY - _sent_last_24h(db, radio.id)
    return NotificationHistory(
        daily_limit=settings.NOTIFICATIONS_PER_DAY,
        remaining_today=max(remaining, 0),
        subscribers_count=_subscribers_count(db, radio.id),
        notifications=notifications,
    )


@router.get("/{slug}/subscribers/count")
def subscribers_count(
    slug: str,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, int]:
    """Nombre d'appareils abonnés, à afficher au gérant avant d'envoyer.
    Réservé à l'admin de la radio (aussi présent dans GET /notifications)."""
    radio = get_radio_or_404(db, slug)
    ensure_radio_admin(current_user, radio)
    return {"count": _subscribers_count(db, radio.id)}
