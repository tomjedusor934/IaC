# ==============================================================================
# FastAPI Task Manager - Task CRUD Router
# ==============================================================================
import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth.bearer import get_current_user
from app.schemas.task import (
    TaskCreate,
    TaskUpdate,
    TaskDelete,
    TaskResponse,
    TaskListResponse,
    ErrorResponse,
)
from app.services.task_service import TaskService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.post(
    "",
    response_model=TaskResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        409: {"model": ErrorResponse},
    },
)
async def create_task(
    task_data: TaskCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    _user: dict = Depends(get_current_user),
):
    """Create a new task."""
    cid = getattr(request.state, "correlation_id", "unknown")
    logger.info(f"[{cid}] Creating task: {task_data.title}")

    try:
        task = await TaskService.create_task(db, task_data)
        return task
    except Exception as e:
        logger.error(f"[{cid}] Error creating task: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create task",
        )


@router.get(
    "",
    response_model=TaskListResponse,
    responses={401: {"model": ErrorResponse}},
)
async def list_tasks(
    request: Request,
    db: AsyncSession = Depends(get_db),
    _user: dict = Depends(get_current_user),
):
    """List all tasks."""
    cid = getattr(request.state, "correlation_id", "unknown")
    logger.info(f"[{cid}] Listing tasks")

    tasks = await TaskService.list_tasks(db)
    return TaskListResponse(tasks=tasks, count=len(tasks))


@router.get(
    "/{task_id}",
    response_model=TaskResponse,
    responses={
        401: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
    },
)
async def get_task(
    task_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
    _user: dict = Depends(get_current_user),
):
    """Get a specific task by ID."""
    cid = getattr(request.state, "correlation_id", "unknown")
    logger.info(f"[{cid}] Getting task: {task_id}")

    task = await TaskService.get_task(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found",
        )
    return task


@router.put(
    "/{task_id}",
    response_model=TaskResponse,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        409: {"model": ErrorResponse},
    },
)
async def update_task(
    task_id: uuid.UUID,
    task_data: TaskUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    _user: dict = Depends(get_current_user),
):
    """Update a task. Rejects stale requests via request_timestamp."""
    cid = getattr(request.state, "correlation_id", "unknown")
    logger.info(f"[{cid}] Updating task: {task_id}")

    task = await TaskService.get_task(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found",
        )

    try:
        updated = await TaskService.update_task(db, task, task_data)
        return updated
    except ValueError as e:
        logger.warning(f"[{cid}] Conflict updating task {task_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )


@router.delete(
    "/{task_id}",
    status_code=status.HTTP_200_OK,
    responses={
        401: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        409: {"model": ErrorResponse},
    },
)
async def delete_task(
    task_id: uuid.UUID,
    task_data: TaskDelete,
    request: Request,
    db: AsyncSession = Depends(get_db),
    _user: dict = Depends(get_current_user),
):
    """Delete a task. Rejects stale requests via request_timestamp."""
    cid = getattr(request.state, "correlation_id", "unknown")
    logger.info(f"[{cid}] Deleting task: {task_id}")

    task = await TaskService.get_task(db, task_id)
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found",
        )

    try:
        await TaskService.delete_task(db, task, task_data.request_timestamp)
        return {"detail": f"Task {task_id} deleted", "correlation_id": cid}
    except ValueError as e:
        logger.warning(f"[{cid}] Conflict deleting task {task_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
