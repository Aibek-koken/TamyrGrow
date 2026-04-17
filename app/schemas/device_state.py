"""Device state schemas."""

from __future__ import annotations

from pydantic import Field

from app.schemas.common import ORMBaseSchema


class DeviceStateRead(ORMBaseSchema):
    """Read-only device state response."""

    shelf_id: int
    light_brightness: int
    fan_speed: int
    target_temperature: float
    heater_on: bool
    humidifier_on: bool
    is_ai_mode: bool


class DeviceStateControlPatch(ORMBaseSchema):
    """Partial control update for manual mode operations."""

    light_brightness: int | None = Field(default=None, ge=0, le=100)
    fan_speed: int | None = Field(default=None, ge=0, le=2)
    target_temperature: float | None = Field(default=None, ge=10, le=40)
    heater_on: bool | None = None
    humidifier_on: bool | None = None
    is_ai_mode: bool | None = None

