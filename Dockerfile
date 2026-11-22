# syntax=docker/dockerfile:1
FROM public.ecr.aws/docker/library/python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /srv

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/app.py .

# Run as an unprivileged user
RUN useradd --uid 10001 --no-create-home appuser
USER 10001

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:8080/health'); sys.exit(0)"
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "app:app"]
