# ==============================================================================
# FastAPI Task Manager - Pydantic schemas for request/response validation
# ==============================================================================
import uuid
from datetime import datetime, date
from typing import Optional

from pydantic import BaseModel, Field, ConfigDict


class TaskCreate(BaseModel):
    """Schema for creating a new task (POST /tasks)."""
    title: str = Field(..., min_length=1, max_length=255, examples=["Write report"])
    content: str = Field(..., min_length=1, examples=["Prepare lesson notes"])
    due_date: date = Field(..., examples=["2025-09-30"])
    request_timestamp: datetime = Field(
        ...,
        description="Client-side timestamp for out-of-order handling",
        examples=["2025-09-25T20:00:00Z"],
    )


class TaskUpdate(BaseModel):
    """Schema for updating a task (PUT /tasks/{id})."""
    title: Optional[str] = Field(None, min_length=1, max_length=255, examples=["Review slides"])
    content: Optional[str] = Field(None, min_length=1, examples=["Check slides content"])
    due_date: Optional[date] = Field(None, examples=["2025-10-01"])
    done: Optional[bool] = Field(None, examples=[True])
    request_timestamp: datetime = Field(
        ...,
        description="Client-side timestamp for out-of-order handling",
        examples=["2025-09-25T20:01:00Z"],
    )


class TaskDelete(BaseModel):
    """Schema for deleting a task (DELETE /tasks/{id})."""
    request_timestamp: datetime = Field(
        ...,
        description="Client-side timestamp for out-of-order handling",
        examples=["2025-09-25T20:02:00Z"],
    )


class TaskResponse(BaseModel):
    """Schema for task responses."""
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    content: str
    due_date: date
    done: bool
    created_at: datetime
    updated_at: datetime


class TaskListResponse(BaseModel):
    """Schema for listing tasks."""
    tasks: list[TaskResponse]
    count: int


class ErrorResponse(BaseModel):
    """Standard error response."""
    detail: str
    correlation_id: Optional[str] = None
