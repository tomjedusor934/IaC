# ==============================================================================
# FastAPI Task Manager - Health check endpoints for K8s probes
# ==============================================================================
import logging

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Health"])


@router.get("/healthz")
async def liveness():
    """
    Liveness probe: returns 200 if the application process is alive.
    Used by Kubernetes to detect deadlocked processes.
    """
    return {"status": "ok"}


@router.get("/readyz")
async def readiness(db: AsyncSession = Depends(get_db)):
    """
    Readiness probe: returns 200 if the application can serve traffic.
    Checks database connectivity.
    """
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return {"status": "not ready", "error": str(e)}


@router.get("/")
async def root():
    """Root endpoint — API info."""
    return {
        "service": "Task Manager API",
        "version": "1.0.0",
        "docs": "/docs",
    }
