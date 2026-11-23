from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import CurrentUser
from app.database import get_db
from app.media import delete_media, save_logo
from app.models import Radio, User
from app.schemas import RadioOut, RadioUpdate

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
            detail="Seul l'admin de cette radio peut la modifier",
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
