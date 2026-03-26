# ==============================================================================
# FastAPI Task Manager - Correlation ID Middleware
# ==============================================================================
import contextvars
import logging
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Context variable to store correlation_id across the request lifecycle
correlation_id_ctx: contextvars.ContextVar[str] = contextvars.ContextVar(
    "correlation_id", default=""
)

logger = logging.getLogger(__name__)


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """
    Middleware that reads `correlation_id` from request headers.
    If absent, generates a new UUID4.
    Stores it in contextvars for logging and attaches it to the response.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        # Read from header or generate
        cid = request.headers.get("correlation_id") or str(uuid.uuid4())
        correlation_id_ctx.set(cid)

        # Add to request state for easy access in route handlers
        request.state.correlation_id = cid

        logger.info(f"[{cid}] {request.method} {request.url.path} - Start")

        response: Response = await call_next(request)

        # Attach correlation_id to response headers
        response.headers["correlation_id"] = cid
        logger.info(f"[{cid}] {request.method} {request.url.path} - Status {response.status_code}")

        return response
