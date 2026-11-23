"""Tests sans Docker ni Firebase : SQLite en mémoire, `send_push` remplacé par un faux.

Lancer depuis backend/ :
    python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
    .venv/bin/pytest
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import database
from app.auth import create_access_token, hash_password
from app.database import Base, get_db
from app.main import app
from app.models import Radio, User
from app.routers import radios as radios_router


@pytest.fixture
def session_factory(monkeypatch):
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,  # une seule connexion : la base en mémoire est partagée
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    # La tâche de fond ouvre sa propre session via database.SessionLocal
    monkeypatch.setattr(database, "SessionLocal", factory)
    yield factory
    engine.dispose()


@pytest.fixture
def db(session_factory):
    with session_factory() as session:
        yield session


@pytest.fixture
def client(session_factory):
    def override_get_db():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    # Sans "with" : le lifespan (Postgres, Firebase) n'est pas lancé
    yield TestClient(app)
    app.dependency_overrides.clear()


class FakePush:
    """Remplace send_push : mémorise les appels et renvoie des jetons invalides au choix."""

    def __init__(self):
        self.calls: list[dict] = []
        self.invalid: set[str] = set()

    def __call__(self, tokens, title, body, data):
        self.calls.append({"tokens": list(tokens), "title": title, "body": body, "data": data})
        invalid = [t for t in tokens if t in self.invalid]
        return len(tokens) - len(invalid), invalid


@pytest.fixture
def fake_push(monkeypatch):
    fake = FakePush()
    monkeypatch.setattr(radios_router, "send_push", fake)
    return fake


@pytest.fixture
def radios(db):
    orleans = Radio(slug="orleans")
    tours = Radio(slug="tours")
    db.add_all([orleans, tours])
    db.commit()
    return orleans, tours


def _user(db, name, radio=None, is_admin=False) -> User:
    user = User(
        name=name,
        password=hash_password("motdepasse1"),
        radio_id=radio.id if radio else None,
        is_admin=is_admin,
    )
    db.add(user)
    db.commit()
    return user


def auth_header(user: User) -> dict[str, str]:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


@pytest.fixture
def users(db, radios):
    orleans, tours = radios
    return {
        "admin_orleans": _user(db, "admin_orleans", orleans, is_admin=True),
        "admin_tours": _user(db, "admin_tours", tours, is_admin=True),
        "membre_orleans": _user(db, "membre_orleans", orleans, is_admin=False),
    }
