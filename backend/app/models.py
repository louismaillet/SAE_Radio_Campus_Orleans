from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    false,
    func,
)
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
    posts: Mapped[list["Post"]] = relationship(
        back_populates="author", cascade="all, delete-orphan"
    )


class Device(Base):
    """Un appareil (téléphone) qui reçoit les notifications d'une radio.

    Les auditeurs n'ont pas de compte : l'appareil, identifié par son jeton FCM,
    tient lieu d'utilisateur. Une seule colonne `radio` = une seule radio suivie.
    """

    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(BigId, primary_key=True)
    # Jeton FCM. Fait office d'identifiant secret : seul l'appareil le connaît.
    push_token: Mapped[str] = mapped_column(Text, unique=True)
    platform: Mapped[str] = mapped_column(String(20))  # android (ios plus tard)
    # Radio suivie (null = aucune)
    radio_id: Mapped[int | None] = mapped_column(
        "radio", BigId, ForeignKey("radios.id", ondelete="SET NULL"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    radio: Mapped[Radio | None] = relationship()

    @property
    def radio_slug(self) -> str | None:
        return self.radio.slug if self.radio else None


class Notification(Base):
    """Historique des notifications envoyées par le gérant d'une radio.
    Sert aussi à appliquer la limite d'envois par jour."""

    __tablename__ = "notifications"
    __table_args__ = (Index("ix_notifications_radio_created", "radio_id", "created_at"),)

    id: Mapped[int] = mapped_column(BigId, primary_key=True)
    radio_id: Mapped[int] = mapped_column(
        BigId, ForeignKey("radios.id", ondelete="CASCADE")
    )
    sender_id: Mapped[int | None] = mapped_column(
        BigId, ForeignKey("users.id", ondelete="SET NULL")
    )
    title: Mapped[str] = mapped_column(String(100))
    body: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    # Nombre d'appareils visés au moment de l'envoi
    recipients_count: Mapped[int] = mapped_column(Integer, default=0)
    # Rempli à la fin de l'envoi (tâche de fond). null = envoi en cours
    success_count: Mapped[int | None] = mapped_column(Integer)


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
