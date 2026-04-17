"""Current shelf state schemas."""

from __future__ import annotations

from app.schemas.common import ORMBaseSchema
from app.schemas.device_state import DeviceStateRead
from app.schemas.sensor import SensorLogRead
from app.schemas.shelf import ShelfSummaryRead


class ShelfCurrentResponse(ORMBaseSchema):
    """Current snapshot payload for one shelf."""

    shelf: ShelfSummaryRead
    latest_sensor: SensorLogRead | None
    device_state: DeviceStateRead | None
    vpd: float | None

