"""Application entrypoint for the Smart Hydroponics API."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.router import api_router
from app.core.config import get_settings
from app.db.session import engine
from app.models import Base
from app.services.mqtt.sensor_listener import start_mqtt_listener, stop_mqtt_listener

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Create tables during startup for local development."""
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
        # Local compatibility migration (SQLAlchemy create_all does not alter existing tables).
        await connection.execute(
            text(
                """
                ALTER TABLE device_states
                ADD COLUMN IF NOT EXISTS target_temperature DOUBLE PRECISION NOT NULL DEFAULT 22.0
                """
            )
        )
        await connection.execute(
            text(
                """
                ALTER TABLE shelves
                ADD COLUMN IF NOT EXISTS device_id VARCHAR(100)
                """
            )
        )

    mqtt_handle = await start_mqtt_listener()
    try:
        yield
    finally:
        await stop_mqtt_listener(mqtt_handle)


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
    ],
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/")
async def health_check() -> dict[str, str]:
    """Return basic health status."""
    return {"status": "ok", "service": settings.app_name}

