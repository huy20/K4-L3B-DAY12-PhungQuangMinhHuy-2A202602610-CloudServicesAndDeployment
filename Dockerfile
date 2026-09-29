# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (multi-stage, non-root, healthcheck)
#
# Stage `builder`: chỉ cài dependency → layer riêng, tận dụng cache.
# Stage `runtime`: chỉ copy kết quả, không mang theo compiler/venv.
# ═══════════════════════════════════════════════════════════════════

FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

# Copy dependency đã cài từ stage builder
COPY --from=builder /install /usr/local

# Copy source sau cùng để sửa code không phải cài lại thư viện
COPY app ./app
COPY utils ./utils

# Chạy bằng user thường, không phải root
RUN useradd --create-home --uid 1001 appuser

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://localhost:' + os.environ.get('PORT', '8000') + '/health')" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
