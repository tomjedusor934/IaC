# ==============================================================================
# FastAPI Task Manager - Multi-stage Dockerfile
# ==============================================================================

# --- Stage 1: Build ---
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- Stage 2: Runtime ---
FROM python:3.12-slim AS runtime

# Security: run as non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /src -s /sbin/nologin appuser

WORKDIR /src

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source inside an 'app' directory block 
# so 'from app.config import...' and 'uvicorn app.main...' work natively
COPY . /src/app

# Set ownership
RUN chown -R appuser:appuser /src

USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1

# Run with uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
