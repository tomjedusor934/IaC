# ==============================================================================
# FastAPI Task Manager - Business logic layer for Task CRUD
# ==============================================================================
import uuid
import logging
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.task import Task
from app.schemas.task import TaskCreate, TaskUpdate

logger = logging.getLogger(__name__)


class TaskService:
    """Service layer encapsulating Task business logic."""

    @staticmethod
    async def create_task(db: AsyncSession, task_data: TaskCreate) -> Task:
        """
        Create a new task.
        Returns the created Task ORM object.
        """
        task = Task(
            title=task_data.title,
            content=task_data.content,
            due_date=task_data.due_date,
            done=False,
            last_request_timestamp=task_data.request_timestamp,
        )
        db.add(task)
        await db.flush()
        await db.refresh(task)
        logger.info(f"Task created: id={task.id}, title={task.title}")
        return task

    @staticmethod
    async def get_task(db: AsyncSession, task_id: uuid.UUID) -> Task | None:
        """Get a single task by ID."""
        result = await db.execute(select(Task).where(Task.id == task_id))
        return result.scalar_one_or_none()

    @staticmethod
    async def list_tasks(db: AsyncSession) -> list[Task]:
        """List all tasks."""
        result = await db.execute(select(Task).order_by(Task.created_at.desc()))
        return list(result.scalars().all())

    @staticmethod
    async def update_task(
        db: AsyncSession,
        task: Task,
        task_data: TaskUpdate,
    ) -> Task:
        """
        Update a task. Checks request_timestamp for out-of-order handling.
        Raises ValueError if the request is stale (out-of-order conflict).
        """
        # Out-of-order detection: reject if incoming timestamp is older
        if task_data.request_timestamp <= task.last_request_timestamp:
            raise ValueError(
                f"Stale request: request_timestamp ({task_data.request_timestamp}) "
                f"<= last_request_timestamp ({task.last_request_timestamp})"
            )

        # Apply partial updates
        if task_data.title is not None:
            task.title = task_data.title
        if task_data.content is not None:
            task.content = task_data.content
        if task_data.due_date is not None:
            task.due_date = task_data.due_date
        if task_data.done is not None:
            task.done = task_data.done

        task.last_request_timestamp = task_data.request_timestamp

        await db.flush()
        await db.refresh(task)
        logger.info(f"Task updated: id={task.id}")
        return task

    @staticmethod
    async def delete_task(
        db: AsyncSession,
        task: Task,
        request_timestamp: datetime,
    ) -> None:
        """
        Delete a task. Checks request_timestamp for out-of-order handling.
        Raises ValueError if the request is stale.
        """
        if request_timestamp <= task.last_request_timestamp:
            raise ValueError(
                f"Stale request: request_timestamp ({request_timestamp}) "
                f"<= last_request_timestamp ({task.last_request_timestamp})"
            )

        await db.delete(task)
        await db.flush()
        logger.info(f"Task deleted: id={task.id}")
