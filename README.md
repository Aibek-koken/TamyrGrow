# Tamyr — Smart Hydroponics (monorepo)

Монорепозиторий **цифрового двойника** гидропоники: FastAPI-бэкенд и Flutter-клиент.

## Структура

```text
Tamyr/
  backend/          # FastAPI, SQLAlchemy async, seed, Python venv
  frontend/         # Flutter-приложение
  docker-compose.yml
  README.md
```

## Технологии

- **Backend:** FastAPI, PostgreSQL 16, SQLAlchemy 2 async (`asyncpg`), Pydantic v2
- **Frontend:** Flutter
- **Инфраструктура:** Docker Compose (PostgreSQL + образ API из `./backend`)

## Быстрый старт — база и API в Docker

Из корня репозитория:

```bash
docker compose up -d --build
```

- PostgreSQL: `localhost:5432`
- API: `http://localhost:8000`

Переменная `DATABASE_URL` для сервиса `api` задаётся в `docker-compose.yml` (подключение к контейнеру `postgres`).

## Локальная разработка — только PostgreSQL в Docker

```bash
docker compose up -d postgres
```

## Локальная разработка — API на хосте

1. Запустите PostgreSQL (команда выше).

2. Создайте виртуальное окружение и зависимости:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

3. Скопируйте `backend/.env.example` в `backend/.env` при необходимости и поправьте `DATABASE_URL` (по умолчанию `localhost:5432`).

4. Заполните тестовыми данными:

```bash
cd backend
python seed.py
```

5. Запуск API:

```bash
cd backend
uvicorn app.main:app --reload
```

## Flutter (frontend)

```bash
cd frontend
flutter pub get
flutter run
```

Базовый URL API в клиенте по умолчанию: `http://localhost:8000` (см. `frontend/lib/core/network/api_service.dart`).

## Основные HTTP-эндпоинты

- `GET /dashboard/summary`
- `GET /shelves/{id}/current`
- `GET /shelves/{id}/logs`
- `PATCH /shelves/{id}/control`
- `POST /sensors/report`

Подробнее см. `backend/PROJECT_SPEC.md`.
