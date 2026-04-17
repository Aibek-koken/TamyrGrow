# Smart Hydroponics Management API

FastAPI backend boilerplate for a smart hydroponics "Digital Twin" system.
It bridges ESP32 sensor input with a Flutter mobile app.

## Tech Stack

- FastAPI
- PostgreSQL
- SQLAlchemy Async ORM (`asyncpg`)
- Pydantic v2

## Project Structure

```text
app/
  api/
    routes/
  core/
  db/
  models/
  schemas/
  main.py
seed.py
docker-compose.yml
requirements.txt
```

## Quick Start

1. Start PostgreSQL:

```bash
docker compose up -d
```

2. Install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

3. (Optional) create `.env` from `.env.example`.

4. Seed mock data:

```bash
python seed.py
```

5. Run API:

```bash
uvicorn app.main:app --reload
```

## API Endpoints

- `GET /dashboard/summary`
- `GET /shelves/{id}/current`
- `PATCH /shelves/{id}/control`
- `POST /sensors/report`

