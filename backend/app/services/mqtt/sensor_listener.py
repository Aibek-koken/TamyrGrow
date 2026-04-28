"""MQTT sensor listener service."""

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models.sensor_log import SensorLog
from app.models.shelf import Shelf
from app.realtime.hub import hub
from app.schemas.sensor import SensorLogRead

try:
    from aiomqtt import Client, TLSParameters
except ImportError:
    raise RuntimeError(
        "aiomqtt is not installed. Install it with: pip install aiomqtt"
    )

logger = logging.getLogger(__name__)
settings = get_settings()


async def start_mqtt_listener() -> Any:
    """Start the MQTT listener for sensor data."""
    if not settings.mqtt_enabled:
        logger.info("MQTT listener is disabled")
        return None

    logger.info(f"Starting MQTT listener connecting to {settings.mqtt_host}...")
    task = asyncio.create_task(_mqtt_listener_task())
    return task


async def stop_mqtt_listener(handle: Any) -> None:
    """Stop the MQTT listener."""
    if handle is None:
        return

    logger.info("Stopping MQTT listener...")
    if isinstance(handle, asyncio.Task):
        handle.cancel()
        try:
            await handle
        except asyncio.CancelledError:
            logger.info("MQTT listener task cancelled")


async def _mqtt_listener_task() -> None:
    """Background task for MQTT listening with auto-reconnect logic."""
    reconnect_delay = 5  # Start with 5 second delay
    max_reconnect_delay = 300  # Max 5 minutes
    
    while True:
        try:
            await _mqtt_connect_and_listen()
            # If connection was successful and then lost, reset delay
            reconnect_delay = 5
        except asyncio.CancelledError:
            logger.info("MQTT listener task was cancelled")
            raise
        except Exception as e:
            logger.error(f"MQTT connection error: {e}. Reconnecting in {reconnect_delay}s...")
            await asyncio.sleep(reconnect_delay)
            # Exponential backoff
            reconnect_delay = min(reconnect_delay * 2, max_reconnect_delay)


async def _mqtt_connect_and_listen() -> None:
    """Connect to MQTT broker and listen for messages."""
    tls_params = TLSParameters(ca_certs=None)  # Use system CA bundle
    
    async with Client(
        hostname=settings.mqtt_host,
        port=settings.mqtt_port,
        username=settings.mqtt_username,
        password=settings.mqtt_password,
        tls_params=tls_params,
    ) as client:
        logger.info(f"Connected to MQTT broker at {settings.mqtt_host}:{settings.mqtt_port}")
        
        # Subscribe to the configured topic
        await client.subscribe(settings.mqtt_topic)
        logger.info(f"Subscribed to topic: {settings.mqtt_topic}")
        
        async for message in client.messages:
            try:
                topic = message.topic
                payload = message.payload.decode("utf-8")
                logger.debug(f"Received message on {topic}: {payload}")
                
                await _process_sensor_message(payload)
            except json.JSONDecodeError as e:
                logger.warning(f"Invalid JSON in MQTT message: {e}. Payload: {payload}")
            except Exception as e:
                logger.error(f"Error processing MQTT message: {e}", exc_info=True)


async def _process_sensor_message(payload: str) -> None:
    """
    Process an incoming sensor message.
    
    Expected JSON format:
    {
        "deviceId": "esp32-001",
        "temperature": 24.5,
        "humidity": 65.3,
        "co2": 450,
        "tvoc": 120,
        "timestamp": "2026-04-27T10:30:00Z"
    }
    """
    data = json.loads(payload)
    print(f"[MQTT] Got message: {payload}", flush=True)
    
    device_id = data.get("deviceId")
    if not device_id:
        logger.warning("No deviceId in message")
        return
    
    async with AsyncSessionLocal() as session:
        # Find shelf by device_id
        stmt = select(Shelf).where(Shelf.device_id == device_id)
        result = await session.execute(stmt)
        shelf = result.scalar_one_or_none()
        
        if not shelf:
            logger.warning(f"No shelf found for device_id: {device_id}")
            return
        
        # Create and save sensor log
        sensor_log = SensorLog(
            shelf_id=shelf.id,
            temperature=data.get("temperature", 0.0),
            humidity=data.get("humidity", 0.0),
            co2=data.get("co2", 0),
            tvoc=data.get("tvoc", 0),
        )
        
        # Parse timestamp if provided
        ts_str = data.get("timestamp")
        if ts_str:
            try:
                if ts_str.endswith("Z"):
                    ts_str = ts_str[:-1] + "+00:00"
                sensor_log.timestamp = datetime.fromisoformat(ts_str).astimezone(timezone.utc)
            except ValueError as e:
                logger.warning(f"Failed to parse timestamp '{data.get('timestamp')}': {e}")
        
        session.add(sensor_log)
        await session.commit()
        
        # Refresh sensor_log from DB to get generated ID and defaults
        await session.refresh(sensor_log)
        
        logger.debug(
            f"Saved sensor log for shelf {shelf.name} "
            f"(temp: {sensor_log.temperature}°C, humidity: {sensor_log.humidity}%)"
        )
        
        # Broadcast to WebSocket hub
        event = SensorLogRead.model_validate(sensor_log).model_dump(mode="json")
        await hub.broadcast(shelf.id, {"type": "sensor_log", "payload": event})
