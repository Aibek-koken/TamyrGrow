"""Realtime WebSocket endpoints."""

from __future__ import annotations

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.realtime.hub import hub

router = APIRouter(prefix="/ws", tags=["realtime"])


@router.websocket("/shelves/{shelf_id}/sensors")
async def shelf_sensors_ws(websocket: WebSocket, shelf_id: int) -> None:
    """Stream live SensorLog events for a specific shelf."""
    await hub.connect(shelf_id, websocket)
    try:
        # Keep connection open; client may send pings/keepalive frames.
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await hub.disconnect(shelf_id, websocket)

