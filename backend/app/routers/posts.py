from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.auth import CurrentUser
from app.database import get_db
from app.media import delete_media, save_image
from app.models import Post
from app.schemas import PostOut

router = APIRouter(prefix="/posts", tags=["posts"])

@router.get("", response_model=list[PostOut])
def list_posts(
    db: Annotated[Session, Depends(get_db)],
    skip: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
):
    stmt = (
        select(Post)
        .options(selectinload(Post.author))
        .order_by(Post.created_at.desc(), Post.id.desc())
        .offset(skip)
        .limit(limit)
    )
    return db.scalars(stmt).all()


@router.get("/{post_id}", response_model=PostOut)
def get_post(post_id: int, db: Annotated[Session, Depends(get_db)]):
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post introuvable")
    return post


@router.post("", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    title: Annotated[str, Form(min_length=1, max_length=200)],
    content: Annotated[str, Form(min_length=1)],
    image: Annotated[UploadFile | None, File()] = None,
):
    """multipart/form-data : champs `title`, `content` et fichier optionnel `image`."""
    image_url = save_image(image) if image is not None and image.filename else None

    post = Post(title=title, content=content, image_url=image_url, author_id=current_user.id)
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_post(post_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    post = db.get(Post, post_id)
    if post is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post introuvable")
    if post.author_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Action non autorisée")

    image_url = post.image_url
    db.delete(post)
    db.commit()
    delete_media(image_url)
