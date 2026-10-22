FROM python:3.10-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 MSN_CONTAINER=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates build-essential && rm -rf /var/lib/apt/lists/*
COPY requirements-docker.txt ./
RUN pip install --no-cache-dir -r requirements-docker.txt
COPY . .
RUN chmod +x /app/deploy/entrypoint.sh && mkdir -p /data
EXPOSE 1863 1864 8081
VOLUME ["/data"]
ENTRYPOINT ["/app/deploy/entrypoint.sh"]
