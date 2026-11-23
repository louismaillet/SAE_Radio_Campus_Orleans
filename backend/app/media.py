"""Enregistrement et suppression des fichiers uploadés (dossier MEDIA_DIR, servi sur /media)."""

import io
import uuid
import warnings

from fastapi import HTTPException, UploadFile, status
from PIL import Image, ImageOps, UnidentifiedImageError

from app.config import settings

CHUNK_SIZE = 1024 * 1024

# Type MIME autorisé -> extension du fichier enregistré (images des posts)
ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}

# Logos : formats réellement lus par Pillow (on ne se fie pas au type MIME envoyé).
# Pas de SVG : il peut contenir du JavaScript.
LOGO_FORMATS = {"JPEG", "PNG", "WEBP", "GIF"}
LOGO_MAX_SIZE = (512, 512)
LOGO_SUBDIR = "logos"

# Protection contre les "bombes de décompression" (petit fichier, image géante)
Image.MAX_IMAGE_PIXELS = 25_000_000


def _too_large() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        detail=f"Image trop lourde (max {settings.MAX_UPLOAD_SIZE_MB} Mo)",
    )


def _max_bytes() -> int:
    return settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024


def save_image(upload: UploadFile) -> str:
    """Image de post : vérifie le type MIME, enregistre le fichier tel quel sous
    un nom UUID et renvoie son URL relative."""
    extension = ALLOWED_IMAGE_TYPES.get(upload.content_type or "")
    if extension is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Type non supporté. Autorisés : {', '.join(ALLOWED_IMAGE_TYPES)}",
        )

    settings.MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex}{extension}"
    destination = settings.MEDIA_DIR / filename

    # Écriture par morceaux pour ne jamais charger un gros fichier en mémoire
    written = 0
    with destination.open("wb") as out:
        while chunk := upload.file.read(CHUNK_SIZE):
            written += len(chunk)
            if written > _max_bytes():
                out.close()
                destination.unlink(missing_ok=True)
                raise _too_large()
            out.write(chunk)

    return f"{settings.MEDIA_URL_PREFIX}/{filename}"


def _read_limited(upload: UploadFile) -> bytes:
    data = upload.file.read(_max_bytes() + 1)
    if len(data) > _max_bytes():
        raise _too_large()
    return data


def save_logo(upload: UploadFile) -> str:
    """Logo de radio : vérifie que c'est une vraie image, la redresse (EXIF),
    la réduit à 512×512 max et la convertit en WebP. Renvoie son URL relative.

    Chaque upload a un nouveau nom : les téléphones ne gardent pas l'ancien
    logo en cache.
    """
    data = _read_limited(upload)

    try:
        with warnings.catch_warnings():
            # Une image juste au-dessus de la limite ne lève qu'un warning : on la refuse aussi
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as source:
                if source.format not in LOGO_FORMATS:
                    raise HTTPException(
                        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                        detail="Formats acceptés : PNG, JPEG, WebP, GIF",
                    )
                img = ImageOps.exif_transpose(source)  # photo de téléphone prise de travers
                img.thumbnail(LOGO_MAX_SIZE, Image.Resampling.LANCZOS)

                has_alpha = img.mode in ("RGBA", "LA", "PA") or (
                    img.mode == "P" and "transparency" in img.info
                )
                img = img.convert("RGBA" if has_alpha else "RGB")
    except HTTPException:
        raise
    except (UnidentifiedImageError, Image.DecompressionBombError,
            Image.DecompressionBombWarning, OSError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Fichier illisible : ce n'est pas une image valide",
        )

    folder = settings.MEDIA_DIR / LOGO_SUBDIR
    folder.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex}.webp"
    img.save(folder / filename, "WEBP", quality=85, method=6)

    return f"{settings.MEDIA_URL_PREFIX}/{LOGO_SUBDIR}/{filename}"


def delete_media(url: str | None) -> None:
    """Supprime le fichier correspondant à une URL /media/... (sans erreur s'il
    n'existe plus). Ignore toute URL qui sortirait du dossier media."""
    prefix = f"{settings.MEDIA_URL_PREFIX}/"
    if not url or not url.startswith(prefix):
        return

    media_root = settings.MEDIA_DIR.resolve()
    path = (media_root / url.removeprefix(prefix)).resolve()
    if path.is_relative_to(media_root) and path != media_root:
        path.unlink(missing_ok=True)
