# TamyrGrow

A smart-hydroponics digital twin. A FastAPI backend ingests sensor telemetry
from grow shelves (over MQTT from ESP32 devices, or via a direct REST report),
stores time-series readings, exposes dashboards and device controls, and answers
grower questions through an AI "agronomist" assistant grounded in each shelf's
live data. A Flutter client provides the mobile and web UI.

Won the Narxoz Incubator startup-idea competition.

## Features

- **Shelf telemetry** — per-shelf temperature, humidity, CO2, and TVOC readings,
  with vapour-pressure deficit (VPD) computed from temperature and humidity.
- **Sensor ingestion** — devices report either over MQTT (an ESP32 listener) or
  via `POST /sensors/report`.
- **Device control** — set per-shelf device state (AI mode, fan speed, light
  brightness) via `PATCH /shelves/{id}/control`.
- **Realtime updates** — a WebSocket channel (`/ws`) pushes new readings to
  connected clients.
- **Dashboard** — an aggregate summary across shelves (`GET /dashboard/summary`).
- **AI agronomist** — `POST /assistant/chat` runs a Groq / Llama 3 chat
  completion with a system prompt built from the shelf's current telemetry and
  device state, so answers reference real conditions and flag issues such as high
  VPD or low CO2.

## Tech stack

- **Backend:** FastAPI, SQLAlchemy 2 (async, `asyncpg`), Pydantic v2, PostgreSQL 16
- **Realtime / ingestion:** WebSockets, MQTT (ESP32 sensors)
- **AI:** Groq API (Llama 3) for the assistant
- **Frontend:** Flutter (mobile and web)
- **Infrastructure:** Docker Compose (PostgreSQL + API image)

## Repository layout

```
backend/    FastAPI service, async SQLAlchemy models, MQTT listener, seed script
frontend/   Flutter client
docker-compose.yml
```

## Getting started

### Backend and database with Docker

```bash
docker compose up -d --build
```

- PostgreSQL: `localhost:5432`
- API: `http://localhost:8000`

### Backend on the host (Postgres in Docker)

```bash
docker compose up -d postgres

cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env             # then edit DATABASE_URL and GROQ_API_KEY
python seed.py                   # load sample data
uvicorn app.main:app --reload
```

The AI assistant requires `GROQ_API_KEY` in `backend/.env` (a Groq Cloud key,
starting with `gsk_`); without it the assistant endpoint cannot call the model.
Database and MQTT settings are read from the same env file.

### Flutter client

```bash
cd frontend
flutter pub get
flutter run
```

The client defaults to `http://localhost:8000` (see
`frontend/lib/core/network/api_service.dart`).

## API overview

| Method | Path | Purpose |
|---|---|---|
| GET | `/dashboard/summary` | Aggregate summary across shelves |
| GET | `/shelves/{id}/current` | Latest reading and status for a shelf |
| GET | `/shelves/{id}/logs` | Historical readings for a shelf |
| PATCH | `/shelves/{id}/control` | Update device state (AI mode, fan, light) |
| POST | `/sensors/report` | Ingest a sensor reading |
| POST | `/assistant/chat` | Ask the AI agronomist about a shelf |
| WS | `/ws` | Realtime reading updates |

See `backend/PROJECT_SPEC.md` for more detail.
