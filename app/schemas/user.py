# ==============================================================================
# FastAPI Task Manager - Pydantic schemas for User request/response validation
# ==============================================================================
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    """Schema for creating a new user (POST /users)."""
    username: str = Field(..., min_length=3, max_length=255, examples=["johndoe"])
    password: str = Field(..., min_length=6, max_length=255, examples=["secret123"])


class UserResponse(BaseModel):
    """Schema for returning user data (without password)."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    username: str
    created_at: datetime
