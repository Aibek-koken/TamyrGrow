"""Sensor ingestion endpoints."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session
from app.models.sensor_log import SensorLog
from app.models.shelf import Shelf
from app.schemas.sensor import SensorLogRead, SensorReportCreate

router = APIRouter(prefix="/sensors", tags=["sensors"])


@router.post("/report", response_model=SensorLogRead, status_code=status.HTTP_201_CREATED)
async def report_sensor_data(
    payload: SensorReportCreate,
    session: AsyncSession = Depends(get_session),
) -> SensorLogRead:
    """Persist a new sensor report submitted by ESP32 devices."""
    shelf = await session.get(Shelf, payload.shelf_id)
    if shelf is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Shelf {payload.shelf_id} not found.",
        )

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
    return SensorLogRead.model_validate(sensor_log)

