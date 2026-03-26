# ==============================================================================
# FastAPI Task Manager - Auth router (token generation endpoint)
# ==============================================================================
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.auth.bearer import create_access_token
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(prefix="/auth", tags=["Authentication"])


class TokenRequest(BaseModel):
    """Simple username/password login request."""

    username: str
    password: str


class TokenResponse(BaseModel):
    """JWT token response."""

    access_token: str
    token_type: str = "bearer"


# NOTE: Simple authentication pointing to DB User for demo
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.services.user_service import UserService


@router.post("/token", response_model=TokenResponse)
async def login(request: TokenRequest, db: AsyncSession = Depends(get_db)):
    """
    Generate a JWT access token.
    Validates credentials against the user database.
    """
    user = await UserService.get_user_by_username(db, request.username)
    if not user or user.password != request.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(data={"sub": request.username})
    logger.info(f"Token generated for user: {request.username}")
    return TokenResponse(access_token=token)
