from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app import models  # noqa: F401  (enregistre les tables dans Base.metadata)
from app.config import settings
from app.database import Base, engine
from app.push import init_firebase
from app.routers import auth, devices, posts, radios


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Création des tables au démarrage. Pratique pour démarrer ;
    # passer à Alembic dès que le schéma devra évoluer sans perte de données.
    Base.metadata.create_all(bind=engine)
    settings.MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    init_firebase()
    yield


app = FastAPI(
    title="Radio Campus Orléans API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS ouvert pour les tests (Flutter web, émulateurs...).
# En production, remplacer "*" par la liste des origines autorisées.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,  # obligatoire avec "*" ; le JWT passe dans un header
    allow_methods=["*"],
    allow_headers=["*"],
)

settings.MEDIA_DIR.mkdir(parents=True, exist_ok=True)
app.mount(settings.MEDIA_URL_PREFIX, StaticFiles(directory=settings.MEDIA_DIR), name="media")

app.include_router(auth.router)
app.include_router(radios.router)
app.include_router(posts.router)
app.include_router(devices.router)


@app.get("/health", tags=["system"])
def health():
    return {"status": "ok"}
