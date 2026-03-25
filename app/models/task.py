# ==============================================================================
# FastAPI Task Manager - SQLAlchemy ORM model for Task
# ==============================================================================
import uuid
from datetime import datetime, date

from sqlalchemy import String, Text, Boolean, DateTime, Date
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.database import Base


class Task(Base):
    """Task database model."""

    __tablename__ = "tasks"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    done: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Tracks the last request_timestamp applied (for out-of-order handling)
    last_request_timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
