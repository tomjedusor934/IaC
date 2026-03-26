# ==============================================================================
# FastAPI Task Manager - Pydantic schemas for request/response validation
# ==============================================================================
import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


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

    title: str | None = Field(None, min_length=1, max_length=255, examples=["Review slides"])
    content: str | None = Field(None, min_length=1, examples=["Check slides content"])
    due_date: date | None = Field(None, examples=["2025-10-01"])
    done: bool | None = Field(None, examples=[True])
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
    correlation_id: str | None = None
