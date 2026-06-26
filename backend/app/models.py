"""Database models."""

from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Item(Base):
    """A trivial owned resource, used to demo auth + DB together.

    Each item belongs to the Keycloak user (`owner_sub` = the token `sub`), so
    the API only ever returns the caller's own items.
    """

    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    done: Mapped[bool] = mapped_column(default=False)
    owner_sub: Mapped[str] = mapped_column(String(64), index=True)
    owner_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
