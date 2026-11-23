"""Abonnement d'un appareil aux notifications d'une radio.

Routes publiques : les auditeurs n'ont pas de compte. Le jeton FCM fait office
d'identifiant secret (seul l'appareil le connaît).
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Device, Radio
from app.schemas import DeviceOut, DeviceUpsert

router = APIRouter(prefix="/devices", tags=["devices"])


def get_device_or_404(db: Session, push_token: str) -> Device:
    device = db.scalar(select(Device).where(Device.push_token == push_token))
    if device is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appareil inconnu")
    return device


@router.put("", response_model=DeviceOut)
def upsert_device(data: DeviceUpsert, db: Annotated[Session, Depends(get_db)]):
    """Crée l'appareil ou met à jour sa radio (upsert sur `push_token`).

    À appeler au démarrage de l'app, quand le jeton change (`onTokenRefresh`)
    et quand l'auditeur choisit une radio. `radio_slug: null` = se désabonner.
    Choisir une autre radio remplace la précédente.
    """
    radio_id = None
    if data.radio_slug is not None:
        radio_id = db.scalar(select(Radio.id).where(Radio.slug == data.radio_slug))
        if radio_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Radio introuvable")

    def apply() -> Device:
        device = db.scalar(select(Device).where(Device.push_token == data.push_token))
        if device is None:
            device = Device(push_token=data.push_token)
            db.add(device)
        device.platform = data.platform
        device.radio_id = radio_id
        db.commit()
        return device

    try:
        device = apply()
    except IntegrityError:
        # Deux requêtes simultanées ont créé le même jeton : on met à jour l'existant
        db.rollback()
        device = apply()

    db.refresh(device)
    return device


@router.get("/{push_token}", response_model=DeviceOut)
def get_device(push_token: str, db: Annotated[Session, Depends(get_db)]):
    """Radio actuellement suivie par l'appareil (404 si l'appareil est inconnu)."""
    return get_device_or_404(db, push_token)


@router.delete("/{push_token}", status_code=status.HTTP_204_NO_CONTENT)
def delete_device(push_token: str, db: Annotated[Session, Depends(get_db)]):
    """Oublie l'appareil. Répond 204 même s'il était déjà inconnu."""
    db.execute(delete(Device).where(Device.push_token == push_token))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
