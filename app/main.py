# ==============================================================================
# FastAPI Task Manager - Main application entry point
# Trigger CI/CD pipeline update (GitHub Actions) when this file is modified.
# ==============================================================================
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.config import get_settings
from app.database import init_db
from app.metrics import setup_metrics
from app.middleware.correlation import CorrelationIdMiddleware
from app.routers import auth, health, tasks, users

settings = get_settings()

# Configure structured logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: init DB on startup."""
    logger.info(f"Starting {settings.APP_NAME} ({settings.ENVIRONMENT})")
    await init_db()
    logger.info("Database tables initialized")
    yield
    logger.info("Shutting down")


# --- Create FastAPI app ---
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Task Manager CRUD API with out-of-order request handling",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# --- Rate Limiting ---
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# --- Middleware ---
app.add_middleware(CorrelationIdMiddleware)

# --- Prometheus Metrics ---
setup_metrics(app)

# --- Include Routers ---
app.include_router(health.router)
app.include_router(users.router)
app.include_router(auth.router)
app.include_router(tasks.router)


# --- Global Exception Handler ---
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch-all exception handler returning 500."""
    cid = getattr(request.state, "correlation_id", "unknown")
    logger.error(f"[{cid}] Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error",
            "correlation_id": cid,
        },
    )
