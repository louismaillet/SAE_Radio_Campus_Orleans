FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Couche dépendances séparée : rebuild rapide tant que requirements.txt ne change pas
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app
RUN mkdir -p /app/media

EXPOSE 8000

# Commande de prod par défaut ; docker-compose la surcharge avec --reload en dev
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
