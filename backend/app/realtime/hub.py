"""In-memory WebSocket hub for live sensor events.

Note: This works for a single API instance. For multiple replicas, replace
with a shared pub/sub (e.g. Redis) and per-instance fanout.
"""

from __future__ import annotations

import asyncio
from collections import defaultdict
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketState


class ConnectionHub:
    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)

    async def connect(self, shelf_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[shelf_id].add(websocket)

    async def disconnect(self, shelf_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            sockets = self._connections.get(shelf_id)
            if not sockets:
                return
            sockets.discard(websocket)
            if not sockets:
                self._connections.pop(shelf_id, None)

    async def broadcast(self, shelf_id: int, message: dict[str, Any]) -> None:
        async with self._lock:
            sockets = list(self._connections.get(shelf_id, set()))

        if not sockets:
            return

        dead: list[WebSocket] = []
        for ws in sockets:
            if ws.client_state != WebSocketState.CONNECTED:
                dead.append(ws)
                continue
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)

        if dead:
            async with self._lock:
                shelf_sockets = self._connections.get(shelf_id)
                if shelf_sockets:
                    for ws in dead:
                        shelf_sockets.discard(ws)
                    if not shelf_sockets:
                        self._connections.pop(shelf_id, None)


hub = ConnectionHub()

