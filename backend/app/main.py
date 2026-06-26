"""FastAPI application entry point."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models  # noqa: F401  (registers tables on Base.metadata)
from .config import settings
from .database import Base, engine
from .routers import items, me


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Convenience: create tables on startup. Swap for Alembic when the
    # schema starts to evolve.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Baseline API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(me.router)
app.include_router(items.router)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
