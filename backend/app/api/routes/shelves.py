"""Shelf-specific endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session
from app.core.utils import calculate_vpd
from app.models.device_state import DeviceState
from app.models.sensor_log import SensorLog
from app.models.shelf import Shelf
from app.schemas.current import ShelfCurrentResponse
from app.schemas.device_state import DeviceStateControlPatch, DeviceStateRead
from app.schemas.sensor import SensorLogRead
from app.schemas.shelf import ShelfSummaryRead

router = APIRouter(prefix="/shelves", tags=["shelves"])


async def _get_shelf_or_404(session: AsyncSession, shelf_id: int) -> Shelf:
    """Fetch a shelf or raise 404 if not found."""
    shelf = await session.get(Shelf, shelf_id)
    if shelf is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Shelf {shelf_id} not found.",
        )
    return shelf


@router.get("/{shelf_id}/current", response_model=ShelfCurrentResponse)
async def get_current_shelf_state(
    shelf_id: int,
    session: AsyncSession = Depends(get_session),
) -> ShelfCurrentResponse:
    """Return the latest sensor values and device state for one shelf."""
    shelf = await _get_shelf_or_404(session, shelf_id)

    sensor_result = await session.execute(
        select(SensorLog)
        .where(SensorLog.shelf_id == shelf_id)
        .order_by(SensorLog.timestamp.desc())
        .limit(1)
    )
    latest_sensor = sensor_result.scalar_one_or_none()

    device_state = await session.get(DeviceState, shelf_id)

    vpd: float | None = None
    if latest_sensor is not None:
        vpd = calculate_vpd(latest_sensor.temperature, latest_sensor.humidity)

    return ShelfCurrentResponse(
        shelf=ShelfSummaryRead.model_validate(shelf),
        latest_sensor=(
            SensorLogRead.model_validate(latest_sensor) if latest_sensor is not None else None
        ),
        device_state=(
            DeviceStateRead.model_validate(device_state) if device_state is not None else None
        ),
        vpd=vpd,
    )


@router.get("/{shelf_id}/logs", response_model=list[SensorLogRead])
async def get_shelf_sensor_logs(
    shelf_id: int,
    limit: int = Query(default=200, ge=1, le=2000),
    session: AsyncSession = Depends(get_session),
) -> list[SensorLogRead]:
    """Return historical sensor logs for one shelf (oldest -> newest)."""
    await _get_shelf_or_404(session, shelf_id)

    result = await session.execute(
        select(SensorLog)
        .where(SensorLog.shelf_id == shelf_id)
        .order_by(SensorLog.timestamp.desc())
        .limit(limit)
    )
    rows = list(result.scalars().all())
    rows.reverse()
    return [SensorLogRead.model_validate(row) for row in rows]


@router.patch("/{shelf_id}/control", response_model=DeviceStateRead)
async def patch_shelf_control(
    shelf_id: int,
    payload: DeviceStateControlPatch,
    session: AsyncSession = Depends(get_session),
) -> DeviceStateRead:
    """Update device controls with AI-mode safety rules.

    Manual control updates are blocked while AI mode is enabled, except for
    toggling AI mode itself.
    """
    await _get_shelf_or_404(session, shelf_id)
    device_state = await session.get(DeviceState, shelf_id)

    if device_state is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device state for shelf {shelf_id} not found.",
        )

    updates = payload.model_dump(exclude_unset=True)
    if device_state.is_ai_mode and any(key != "is_ai_mode" for key in updates.keys()):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Manual control is disabled while AI mode is enabled.",
        )

    for key, value in updates.items():
        setattr(device_state, key, value)

    await session.commit()
    await session.refresh(device_state)
    return DeviceStateRead.model_validate(device_state)

