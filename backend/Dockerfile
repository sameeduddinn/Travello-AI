# FILE: Dockerfile
# Multi-stage build for minimal image size.
# Compatible with Render.com free tier and Railway.app.
#
# Build:  docker build -t travello-backend .
# Run:    docker run -p 8000:8000 --env-file .env travello-backend

# ── Stage 1: dependency builder 
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build tools needed for some Python packages (asyncpg, bcrypt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install dependencies first (layer cache optimisation)
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --prefix=/install --no-cache-dir -r requirements.txt


# ── Stage 2: final runtime image 
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy application source
COPY . .

# Create a non-root user for security
RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup --no-create-home appuser && \
    chown -R appuser:appgroup /app

USER appuser

# Expose the port Uvicorn listens on
EXPOSE 8000

# Health check — Render.com also hits /health via its own check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Start command
# --workers 1    → free tier has limited RAM; 1 worker is enough for FYP demo
# --timeout-keep-alive 65  → slightly above Render's 60s idle timeout
CMD ["uvicorn", "main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--timeout-keep-alive", "65", \
     "--log-level", "info"]
