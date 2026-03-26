# ==============================================================================
# FastAPI Task Manager - Business logic layer for User CRUD
# ==============================================================================
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserCreate

logger = logging.getLogger(__name__)


class UserService:
    """Service layer encapsulating User business logic."""

    @staticmethod
    async def create_user(db: AsyncSession, user_data: UserCreate) -> User:
        """
        Create a new user.
        In a real application, password should be hashed! We keep it plain for demo simplicity.
        """
        user = User(
            username=user_data.username,
            password=user_data.password,  # In production: hash the password (e.g. passlib)
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        logger.info(f"User created: id={user.id}, username={user.username}")
        return user

    @staticmethod
    async def get_user_by_username(db: AsyncSession, username: str) -> User | None:
        """Get a single user by username."""
        result = await db.execute(select(User).where(User.username == username))
        return result.scalar_one_or_none()
