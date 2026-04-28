"""Domain logic for persisting incoming sensor readings."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sensor_log import SensorLog
from app.models.shelf import Shelf
from app.schemas.sensor import SensorReportCreate


async def persist_sensor_report(
    *,
    session: AsyncSession,
    payload: SensorReportCreate,
) -> SensorLog:
    """Validate shelf and persist a new sensor log row."""
    shelf = await session.get(Shelf, payload.shelf_id)
    if shelf is None:
        raise ValueError(f"Shelf {payload.shelf_id} not found.")

    sensor_log = SensorLog(
        shelf_id=payload.shelf_id,
        temperature=payload.temperature,
        humidity=payload.humidity,
        co2=payload.co2,
        tvoc=payload.tvoc,
        timestamp=payload.timestamp or datetime.now(timezone.utc),
    )

    session.add(sensor_log)
    await session.commit()
    await session.refresh(sensor_log)
    return sensor_log

