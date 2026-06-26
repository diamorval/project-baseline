"""`/api/items` — a minimal CRUD scoped to the authenticated user."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..models import Item
from ..schemas import ItemCreate, ItemOut, ItemUpdate

router = APIRouter(prefix="/api/items", tags=["items"])


@router.get("", response_model=list[ItemOut])
def list_items(
    db: Session = Depends(get_db),
    user: CurrentUser = Depends(get_current_user),
) -> list[Item]:
    stmt = select(Item).where(Item.owner_sub == user.sub).order_by(Item.created_at.desc())
    return list(db.scalars(stmt).all())


@router.post("", response_model=ItemOut, status_code=status.HTTP_201_CREATED)
def create_item(
    payload: ItemCreate,
    db: Session = Depends(get_db),
    user: CurrentUser = Depends(get_current_user),
) -> Item:
    item = Item(
        title=payload.title,
        description=payload.description,
        owner_sub=user.sub,
        owner_name=user.display_name,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def _get_owned(item_id: int, db: Session, user: CurrentUser) -> Item:
    item = db.get(Item, item_id)
    if item is None or item.owner_sub != user.sub:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@router.patch("/{item_id}", response_model=ItemOut)
def update_item(
    item_id: int,
    payload: ItemUpdate,
    db: Session = Depends(get_db),
    user: CurrentUser = Depends(get_current_user),
) -> Item:
    item = _get_owned(item_id, db, user)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(
    item_id: int,
    db: Session = Depends(get_db),
    user: CurrentUser = Depends(get_current_user),
) -> None:
    item = _get_owned(item_id, db, user)
    db.delete(item)
    db.commit()
