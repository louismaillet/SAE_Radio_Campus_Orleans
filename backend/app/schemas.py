from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, StringConstraints

HexColor = Annotated[str, Field(pattern=r"^#[0-9A-Fa-f]{6}$", examples=["#E30613"])]


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- Radios ----------
class RadioOut(ORMModel):
    id: int
    created_at: datetime
    slug: str
    # Catalogue
    position: int | None
    name: str
    city: str | None
    excerpt: str | None
    slogan: str | None
    category_color: str | None
    image_url: str | None
    live_url: str | None
    website_url: str | None
    # Réglages du gérant
    site: bool
    url: str | None
    color: str | None
    logo_url: str | None
    stream_url: str | None


class RadioUpdate(BaseModel):
    """Champs modifiables par l'admin de la radio. Tous optionnels :
    seuls les champs envoyés sont modifiés ; envoyer null pour effacer."""

    site: bool | None = None
    url: HttpUrl | None = None
    color: HexColor | None = None
    stream_url: HttpUrl | None = None


# ---------- Utilisateurs / Auth ----------
class UserCreate(BaseModel):
    name: str = Field(min_length=3, max_length=50)
    # bcrypt ignore tout au-delà de 72 octets : on le refuse explicitement
    password: str = Field(min_length=8, max_length=72)


class UserOut(ORMModel):
    id: int
    created_at: datetime
    name: str
    is_admin: bool
    radio_id: int | None
    radio_slug: str | None


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---------- Posts ----------
class PostAuthor(ORMModel):
    id: int
    name: str


class PostOut(ORMModel):
    id: int
    title: str
    content: str
    image_url: str | None
    author_id: int
    created_at: datetime
    author: PostAuthor


# ---------- Appareils ----------
class DeviceUpsert(BaseModel):
    push_token: str = Field(min_length=1, max_length=4096)
    platform: Literal["android", "ios"] = "android"
    # Slug de la radio suivie ; null = ne plus recevoir de notifications.
    # Obligatoire (même à null) pour ne pas désabonner par oubli.
    radio_slug: str | None


class DeviceOut(ORMModel):
    push_token: str
    platform: str
    radio_slug: str | None
    created_at: datetime
    updated_at: datetime


# ---------- Notifications ----------
# Texte brut ; les espaces autour sont retirés, un texte vide est refusé
NotificationTitle = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)
]
NotificationBody = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=500)
]


class NotificationCreate(BaseModel):
    title: NotificationTitle
    body: NotificationBody


class NotificationOut(ORMModel):
    id: int
    radio_id: int
    sender_id: int | None
    title: str
    body: str
    created_at: datetime
    recipients_count: int
    # null tant que l'envoi est en cours
    success_count: int | None


class NotificationHistory(BaseModel):
    daily_limit: int
    remaining_today: int
    subscribers_count: int
    notifications: list[NotificationOut]
