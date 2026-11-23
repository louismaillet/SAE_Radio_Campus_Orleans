from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl

HexColor = Annotated[str, Field(pattern=r"^#[0-9A-Fa-f]{6}$", examples=["#E30613"])]


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- Radios ----------
class RadioOut(ORMModel):
    id: int
    created_at: datetime
    site: bool
    slug: str
    url: str | None
    color: str | None
    logo_url: str | None


class RadioUpdate(BaseModel):
    """Champs modifiables par l'admin de la radio. Tous optionnels :
    seuls les champs envoyés sont modifiés ; envoyer null pour effacer."""

    site: bool | None = None
    url: HttpUrl | None = None
    color: HexColor | None = None


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
class DeviceRegister(BaseModel):
    push_endpoint_url: str = Field(min_length=1, max_length=1000)
    platform: Literal["android", "ios", "web"]


class DeviceOut(ORMModel):
    id: int
    user_id: int
    push_endpoint_url: str
    platform: str
    updated_at: datetime
