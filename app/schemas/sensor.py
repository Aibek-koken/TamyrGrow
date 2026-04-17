"""Sensor log schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import Field

from app.schemas.common import ORMBaseSchema


class SensorLogRead(ORMBaseSchema):
    """Read-only schema for sensor log entries."""

    id: int
    shelf_id: int
    temperature: float
    humidity: float
    co2: int
    tvoc: int
    timestamp: datetime


class SensorReportCreate(ORMBaseSchema):
    """Incoming payload from ESP32 sensor data reports."""

    shelf_id: int
    temperature: float
    humidity: float = Field(ge=0, le=100)
    co2: int = Field(ge=0)
    tvoc: int = Field(ge=0)
    timestamp: datetime | None = None

