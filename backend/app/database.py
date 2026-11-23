from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings

# Moteur synchrone : FastAPI exécute les routes "def" dans un threadpool,
# ce qui est simple et largement suffisant pour ce projet.
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    """Dépendance FastAPI : une session par requête, toujours refermée."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
