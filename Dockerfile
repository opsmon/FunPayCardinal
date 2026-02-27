FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gcc \
    libxml2 \
    libxslt1.1 \
    libjpeg62-turbo \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python -m pip install --upgrade pip && pip install -r requirements.txt

COPY . .

RUN mkdir -p \
    /app/configs \
    /app/logs \
    /app/storage/cache \
    /app/storage/plugins \
    /app/storage/products \
    /app/plugins

VOLUME ["/app/configs", "/app/logs", "/app/storage", "/app/plugins"]

CMD ["python", "main.py"]
