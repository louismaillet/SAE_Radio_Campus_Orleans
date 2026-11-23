from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import CurrentUser
from app.database import get_db
from app.models import UserDevice
from app.schemas import DeviceOut, DeviceRegister

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", response_model=DeviceOut)
def register_device(
    data: DeviceRegister,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
):
    """Upsert : crée l'appareil ou le met à jour (et le rattache à l'utilisateur
    connecté) s'il existe déjà. À appeler au démarrage de l'app et à chaque
    changement d'endpoint."""
    device = db.scalar(
        select(UserDevice).where(UserDevice.push_endpoint_url == data.push_endpoint_url)
    )
    if device is None:
        device = UserDevice(
            user_id=current_user.id,
            push_endpoint_url=data.push_endpoint_url,
            platform=data.platform,
        )
        db.add(device)
    else:
        device.user_id = current_user.id
        device.platform = data.platform

    db.commit()
    db.refresh(device)
    return device
