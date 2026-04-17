"""Sensor log ORM model."""

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Float, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.shelf import Shelf


class SensorLog(Base):
    """Represents a single sensor report captured for a shelf."""

    __tablename__ = "sensor_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    shelf_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("shelves.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    temperature: Mapped[float] = mapped_column(Float, nullable=False)
    humidity: Mapped[float] = mapped_column(Float, nullable=False)
    co2: Mapped[int] = mapped_column(Integer, nullable=False)
    tvoc: Mapped[int] = mapped_column(Integer, nullable=False)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    shelf: Mapped["Shelf"] = relationship(back_populates="sensor_logs")

