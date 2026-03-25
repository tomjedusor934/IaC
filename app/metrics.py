# ==============================================================================
# FastAPI Task Manager - Prometheus metrics
# ==============================================================================
from prometheus_fastapi_instrumentator import Instrumentator


def setup_metrics(app):
    """
    Instrument the FastAPI app with Prometheus metrics.
    Exposes /metrics endpoint for Prometheus scraping.
    """
    instrumentator = Instrumentator(
        should_group_status_codes=False,
        should_ignore_untemplated=True,
        excluded_handlers=["/healthz", "/readyz", "/metrics"],
        should_instrument_requests_inprogress=True,
    )
    instrumentator.instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
