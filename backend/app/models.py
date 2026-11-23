from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String, Text, false, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

# int8 comme dans Supabase (variante INTEGER pour l'auto-incrément sous SQLite en test)
BigId = BigInteger().with_variant(Integer, "sqlite")


class Radio(Base):
    """Une radio campus. Reprend la table Supabase `Radio`."""

    __tablename__ = "radios"

    id: Mapped[int] = mapped_column(BigId, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    # true = l'app affiche le site web de la radio (url), false = la version appli
    site: Mapped[bool] = mapped_column(Boolean, server_default=false(), default=False)
    slug: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    # Adresse du site web de la radio
    url: Mapped[str | None] = mapped_column(String(500))
    # Couleur de la page de la radio, format "#RRGGBB" (null = couleur par défaut)
    color: Mapped[str | None] = mapped_column(String(7))
    # Logo de la radio, ex. "/media/logos/<uuid>.webp" (null = logo par défaut de l'app)
    logo_url: Mapped[str | None] = mapped_column(String(500))

    users: Mapped[list["User"]] = relationship(back_populates="radio")


class User(Base):
    """Reprend la table Supabase `User`. `password` contient le hash bcrypt,
    jamais le mot de passe en clair."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(BigId, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    # Radio gérée par l'utilisateur (null = simple auditeur)
    radio_id: Mapped[int | None] = mapped_column(
        "radio", BigId, ForeignKey("radios.id", ondelete="SET NULL"), index=True
    )
    is_admin: Mapped[bool] = mapped_column(Boolean, server_default=false(), default=False)
    password: Mapped[str] = mapped_column(Text)
    name: Mapped[str] = mapped_column(String(50), unique=True, index=True)

    radio: Mapped[Radio | None] = relationship(back_populates="users")
    devices: Mapped[list["UserDevice"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    posts: Mapped[list["Post"]] = relationship(
        back_populates="author", cascade="all, delete-orphan"
    )


class UserDevice(Base):
    """Un appareil (téléphone) capable de recevoir des notifications push.

    push_endpoint_url est unique : un même appareil qui change de compte
    est simplement réaffecté au nouvel utilisateur.
    """

    __tablename__ = "user_devices"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        BigId, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    push_endpoint_url: Mapped[str] = mapped_column(String(1000), unique=True)
    platform: Mapped[str] = mapped_column(String(20))  # android | ios | web
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped[User] = relationship(back_populates="devices")


class Post(Base):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(500))
    author_id: Mapped[int] = mapped_column(
        BigId, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    author: Mapped[User] = relationship(back_populates="posts")
