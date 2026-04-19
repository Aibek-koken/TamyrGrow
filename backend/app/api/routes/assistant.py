"""AI assistant chat endpoint (Groq / Llama 3)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from groq import APIStatusError, AsyncGroq, GroqError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session
from app.core.config import get_settings
from app.core.utils import calculate_vpd
from app.models.device_state import DeviceState
from app.models.sensor_log import SensorLog
from app.models.shelf import Shelf
from app.schemas.assistant import ChatRequest, ChatResponse

router = APIRouter(prefix="/assistant", tags=["assistant"])

GROQ_MODEL = "llama3-8b-8192"


async def _get_shelf_or_404(session: AsyncSession, shelf_id: int) -> Shelf:
    """Fetch a shelf or raise 404 if not found."""
    shelf = await session.get(Shelf, shelf_id)
    if shelf is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Shelf {shelf_id} not found.",
        )
    return shelf


def _build_system_prompt(
    shelf: Shelf,
    log: SensorLog | None,
    device_state: DeviceState | None,
    vpd: float | None,
) -> str:
    """Build the agronomist system prompt from shelf telemetry and device state."""
    if device_state is not None:
        device_line = (
            f"Current Device States: AI Mode: {device_state.is_ai_mode}, "
            f"Fan Speed: {device_state.fan_speed}, Light: {device_state.light_brightness}%."
        )
    else:
        device_line = (
            "Current Device States: AI Mode: unknown, Fan Speed: unknown, Light: unknown."
        )

    if log is not None:
        vpd_val = vpd if vpd is not None else calculate_vpd(log.temperature, log.humidity)
        return (
            "You are a professional AI Agronomist. "
            f"Current telemetry for Shelf '{shelf.name}':\n"
            f"Temp: {log.temperature}°C, Humidity: {log.humidity}%, "
            f"CO2: {log.co2}ppm, TVOC: {log.tvoc}, VPD: {vpd_val}kPa.\n"
            f"{device_line}\n"
            f"System Status: {shelf.status.value}.\n"
            "Answer the user's question using this specific data. If the data indicates issues "
            "(like high VPD or low CO2), provide actionable advice."
        )

    return (
        "You are a professional AI Agronomist. "
        f"Live sensor telemetry is unavailable for Shelf '{shelf.name}'. "
        "You must inform the user that live data is currently unavailable when they ask about "
        "current readings or real-time conditions, while still answering helpfully with general "
        "agronomic guidance where appropriate.\n"
        f"{device_line}\n"
        f"System Status: {shelf.status.value}.\n"
        "If the user asks about current environment numbers, clearly state that live data is "
        "currently unavailable."
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(
    payload: ChatRequest,
    session: AsyncSession = Depends(get_session),
) -> ChatResponse:
    """Run a shelf-contextual chat completion via Groq."""
    settings = get_settings()
    if not settings.groq_api_key.strip():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GROQ_API_KEY is not configured.",
        )

    shelf = await _get_shelf_or_404(session, payload.shelf_id)

    sensor_result = await session.execute(
        select(SensorLog)
        .where(SensorLog.shelf_id == payload.shelf_id)
        .order_by(SensorLog.timestamp.desc())
        .limit(1)
    )
    latest_log = sensor_result.scalar_one_or_none()

    device_state = await session.get(DeviceState, payload.shelf_id)

    vpd: float | None = None
    if latest_log is not None:
        vpd = calculate_vpd(latest_log.temperature, latest_log.humidity)

    system_prompt = _build_system_prompt(shelf, latest_log, device_state, vpd)

    client = AsyncGroq(api_key=settings.groq_api_key)
    try:
        completion = await client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": payload.message},
            ],
            temperature=0.4,
        )
    except APIStatusError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Groq API error: {exc}",
        ) from exc
    except GroqError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Groq client error: {exc}",
        ) from exc

    choice = completion.choices[0].message
    content = choice.content if choice and choice.content else ""
    if not content.strip():
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Groq returned an empty reply.",
        )

    return ChatResponse(reply=content.strip())
