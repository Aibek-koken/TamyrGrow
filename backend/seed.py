"""Seed the database with realistic hydroponics time-series data.

This script is intended for local development/testing to provide realistic sensor
telemetry for the Flutter app.
"""

from __future__ import annotations

import asyncio
import argparse
import math
import random
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import create_async_engine

from app.db.session import AsyncSessionLocal, engine
from app.models import Base, DeviceState, SensorLog, Shelf, ShelfStatus


async def ensure_database_exists() -> None:
    """Create the configured database if it does not exist."""
    url = make_url(str(engine.url))
    database_name = url.database
    if not database_name:
        return

    admin_url = url.set(database="postgres")
    admin_engine = create_async_engine(str(admin_url), isolation_level="AUTOCOMMIT")
    try:
        async with admin_engine.connect() as conn:
            await conn.execute(text(f'CREATE DATABASE "{database_name}"'))
    except DBAPIError as exc:
        message = str(getattr(exc, "orig", exc)).lower()
        if "already exists" not in message and "duplicate_database" not in message:
            raise
    finally:
        await admin_engine.dispose()


async def reset_tables() -> None:
    """Ensure all tables exist before seeding."""
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


def _clamp(value: float, low: float, high: float) -> float:
    """Clamp a float to a target interval."""
    return max(low, min(high, value))


def _diurnal_factor(dt: datetime, lights_on_hour: int, lights_off_hour: int) -> float:
    """Return a smooth 0..1 factor representing day/night cycle.

    The curve ramps at lights on/off to produce more realistic transitions than a step.
    """
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)

    hour = dt.hour + (dt.minute / 60.0)

    def smoothstep(x: float) -> float:
        """Smoothly interpolate 0..1 for x in 0..1."""
        x = _clamp(x, 0.0, 1.0)
        return x * x * (3.0 - 2.0 * x)

    if lights_on_hour < lights_off_hour:
        if hour < lights_on_hour:
            return 0.0
        if lights_on_hour <= hour <= lights_on_hour + 1:
            return smoothstep(hour - lights_on_hour)
        if lights_on_hour + 1 < hour < lights_off_hour - 1:
            return 1.0
        if lights_off_hour - 1 <= hour <= lights_off_hour:
            return 1.0 - smoothstep(hour - (lights_off_hour - 1))
        return 0.0

    if hour >= lights_on_hour or hour <= lights_off_hour:
        if lights_on_hour <= hour <= lights_on_hour + 1:
            return smoothstep(hour - lights_on_hour)
        if hour >= lights_on_hour + 1 or hour <= lights_off_hour - 1:
            return 1.0
        if lights_off_hour - 1 <= hour <= lights_off_hour:
            return 1.0 - smoothstep(hour - (lights_off_hour - 1))
        return 1.0

    return 0.0


def _generate_sensor_row(
    dt: datetime,
    *,
    shelf_profile: dict[str, float],
    lights_on_hour: int,
    lights_off_hour: int,
    rng: random.Random,
) -> dict[str, float | int]:
    """Generate one realistic sensor row for a given timestamp."""
    day = _diurnal_factor(dt, lights_on_hour, lights_off_hour)

    weekly = math.sin((dt.timestamp() / 86400.0) * (2.0 * math.pi / 7.0))

    temp_base = shelf_profile["temp_base"]
    temp_swing = shelf_profile["temp_swing"]
    temp_noise = rng.gauss(0.0, 0.15)
    temperature = temp_base + temp_swing * day + 0.3 * weekly + temp_noise

    rh_base = shelf_profile["rh_base"]
    rh_swing = shelf_profile["rh_swing"]
    rh_noise = rng.gauss(0.0, 0.8)
    humidity = rh_base - rh_swing * day + 1.2 * (-weekly) + rh_noise
    humidity = _clamp(humidity, 35.0, 90.0)

    co2_base = shelf_profile["co2_base"]
    co2_swing = shelf_profile["co2_swing"]
    co2_noise = rng.gauss(0.0, 35.0)
    co2 = co2_base + co2_swing * day + 0.5 * weekly * 50.0 + co2_noise
    co2 = int(_clamp(co2, 380.0, 2000.0))

    tvoc_base = shelf_profile["tvoc_base"]
    tvoc_noise = rng.gauss(0.0, 25.0)
    tvoc_temp_component = (temperature - 22.0) * 6.0
    tvoc_humidity_component = (humidity - 55.0) * 2.0
    tvoc = tvoc_base + 0.6 * tvoc_temp_component + 0.3 * tvoc_humidity_component + tvoc_noise
    tvoc = int(_clamp(tvoc, 50.0, 1200.0))

    return {
        "temperature": round(float(temperature), 2),
        "humidity": round(float(humidity), 2),
        "co2": int(co2),
        "tvoc": int(tvoc),
    }


async def seed_shelves(
    *,
    shelves: list[str],
    minutes_interval: int,
    days: int,
    clear_existing: bool,
    seed: int,
) -> None:
    """Populate shelves, device states, and realistic time-series sensor logs."""
    async with AsyncSessionLocal() as session:
        if clear_existing:
            await session.execute(delete(SensorLog))
            await session.execute(delete(DeviceState))
            await session.execute(delete(Shelf))

        shelf_names = shelves
        statuses_cycle = [ShelfStatus.OK, ShelfStatus.WARNING, ShelfStatus.CRITICAL]

        shelves: list[Shelf] = []
        for index, name in enumerate(shelf_names):
            shelf_status = statuses_cycle[index % len(statuses_cycle)]
            device_room_number = len(shelf_names) - index
            device_id = f"ESP32-ROOM-{device_room_number:02d}"
            shelf = Shelf(name=name, status=shelf_status, device_id=device_id)
            session.add(shelf)
            shelves.append(shelf)

        await session.flush()

        rng = random.Random(seed)

        for shelf in shelves:
            device_state = DeviceState(
                shelf_id=shelf.id,
                light_brightness=rng.randint(60, 90),
                fan_speed=rng.randint(0, 2),
                heater_on=rng.choice([False, False, True]),
                humidifier_on=rng.choice([False, True]),
                is_ai_mode=rng.choice([True, True, False]),
            )
            session.add(device_state)

        shelf_profiles: dict[int, dict[str, float]] = {}
        for shelf in shelves:
            shelf_profiles[shelf.id] = {
                "temp_base": 21.6 + rng.uniform(-0.6, 0.6),
                "temp_swing": 3.2 + rng.uniform(-0.4, 0.6),
                "rh_base": 62.0 + rng.uniform(-4.0, 4.0),
                "rh_swing": 9.5 + rng.uniform(-2.5, 2.5),
                "co2_base": 520.0 + rng.uniform(-60.0, 90.0),
                "co2_swing": 220.0 + rng.uniform(-70.0, 110.0),
                "tvoc_base": 160.0 + rng.uniform(-60.0, 140.0),
            }

        lights_on_hour = 6
        lights_off_hour = 22

        now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
        start = now - timedelta(days=days)
        total_minutes = int((now - start).total_seconds() // 60)

        for shelf in shelves:
            profile = shelf_profiles[shelf.id]
            for offset in range(0, total_minutes + 1, minutes_interval):
                dt = start + timedelta(minutes=offset)
                row = _generate_sensor_row(
                    dt,
                    shelf_profile=profile,
                    lights_on_hour=lights_on_hour,
                    lights_off_hour=lights_off_hour,
                    rng=rng,
                )
                log = SensorLog(
                    shelf_id=shelf.id,
                    temperature=float(row["temperature"]),
                    humidity=float(row["humidity"]),
                    co2=int(row["co2"]),
                    tvoc=int(row["tvoc"]),
                    timestamp=dt,
                )
                session.add(log)

        await session.commit()


async def main() -> None:
    """Run all seeding tasks."""
    parser = argparse.ArgumentParser(description="Seed the hydroponics database.")
    parser.add_argument("--days", type=int, default=3, help="How many days back to generate.")
    parser.add_argument(
        "--interval-minutes",
        type=int,
        default=5,
        help="Sampling interval in minutes.",
    )
    parser.add_argument(
        "--shelves",
        nargs="+",
        default=["Shelf A", "Shelf B", "Shelf C"],
        help="Shelf names to create.",
    )
    parser.add_argument(
        "--no-clear",
        action="store_true",
        help="Do not delete existing rows before seeding.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducible data generation.",
    )
    args = parser.parse_args()

    await ensure_database_exists()
    await reset_tables()
    await seed_shelves(
        shelves=args.shelves,
        minutes_interval=args.interval_minutes,
        days=args.days,
        clear_existing=not args.no_clear,
        seed=args.seed,
    )

    async with AsyncSessionLocal() as session:
        total_shelves = (await session.execute(select(Shelf))).scalars().all()
        total_logs = (await session.execute(select(SensorLog))).scalars().all()
        print(f"Seed complete. Shelves: {len(total_shelves)} | SensorLogs: {len(total_logs)}")


if __name__ == "__main__":
    asyncio.run(main())

