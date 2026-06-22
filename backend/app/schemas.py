"""Pydantic request/response models."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ItemCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = ""


class ItemUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    done: bool | None = None


class ItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str
    done: bool
    owner_sub: str
    owner_name: str | None
    created_at: datetime


class UserOut(BaseModel):
    sub: str
    username: str | None
    email: str | None
    first_name: str | None
    last_name: str | None
    roles: list[str]
