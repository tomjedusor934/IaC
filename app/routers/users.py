# ==============================================================================
# FastAPI Task Manager - Users router
# ==============================================================================
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.task import ErrorResponse
from app.schemas.user import UserCreate, UserResponse
from app.services.user_service import UserService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["Users"])


@router.post(
    "",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    responses={400: {"model": ErrorResponse}, 409: {"model": ErrorResponse}},
)
async def create_user(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new user.
    """
    logger.info(f"Received user creation request: {user_data.username}")

    # Check if username exists
    existing_user = await UserService.get_user_by_username(db, user_data.username)
    if existing_user:
        logger.warning(f"Registration failed: Username '{user_data.username}' already exists.")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already registered.",
        )

    try:
        new_user = await UserService.create_user(db, user_data)
        logger.info(f"User created successfully: {new_user.username}")
        return new_user
    except IntegrityError as e:
        logger.error(f"Database IntegrityError while creating user: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid database operation. Potential conflict.",
        )
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred.",
        )
