# ==============================================================================
# FastAPI Task Manager - Auth router (token generation endpoint)
# ==============================================================================
import logging

from fastapi import APIRouter, HTTPException, status
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


# NOTE: In production, validate against a real user store.
# This is a simplified demo endpoint for the school project.
DEMO_USERS = {
    "admin": "admin",  # Replace with real auth in production
}


@router.post("/token", response_model=TokenResponse)
async def login(request: TokenRequest):
    """
    Generate a JWT access token.
    In a real application, validate credentials against a user database.
    """
    if request.username not in DEMO_USERS or DEMO_USERS[request.username] != request.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(data={"sub": request.username})
    logger.info(f"Token generated for user: {request.username}")
    return TokenResponse(access_token=token)
