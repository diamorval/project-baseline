"""`/api/me` — echoes the authenticated identity back to the caller."""

from fastapi import APIRouter, Depends

from ..auth import CurrentUser, get_current_user
from ..schemas import UserOut

router = APIRouter(prefix="/api/me", tags=["me"])


@router.get("", response_model=UserOut)
def read_me(user: CurrentUser = Depends(get_current_user)) -> UserOut:
    return UserOut(
        sub=user.sub,
        username=user.username,
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        roles=user.roles,
    )
