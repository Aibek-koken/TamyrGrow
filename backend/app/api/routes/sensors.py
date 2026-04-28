"""Sensor ingestion endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session
from app.schemas.sensor import SensorLogRead, SensorReportCreate
from app.services.sensors.ingest import persist_sensor_report

router = APIRouter(prefix="/sensors", tags=["sensors"])


# Legacy endpoint — kept for manual testing only.
# Primary ingestion is via MQTT listener.
@router.post("/report", response_model=SensorLogRead, status_code=status.HTTP_201_CREATED)
async def report_sensor_data(
    payload: SensorReportCreate,
    session: AsyncSession = Depends(get_session),
) -> SensorLogRead:
    """Persist a new sensor report submitted by ESP32 devices."""
    try:
        sensor_log = await persist_sensor_report(session=session, payload=payload)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        ) from e
    return SensorLogRead.model_validate(sensor_log)

