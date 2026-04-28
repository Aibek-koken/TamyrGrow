"""Shelf ORM model."""

from typing import TYPE_CHECKING

from sqlalchemy import Enum as SqlEnum
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.enums import ShelfStatus

if TYPE_CHECKING:
    from app.models.device_state import DeviceState
    from app.models.sensor_log import SensorLog


class Shelf(Base):
    """Represents a physical shelf within the hydroponics system."""

    __tablename__ = "shelves"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    device_id: Mapped[str] = mapped_column(String(100), nullable=False, unique=True, index=True)
    status: Mapped[ShelfStatus] = mapped_column(
        SqlEnum(ShelfStatus, name="shelf_status"),
        nullable=False,
        default=ShelfStatus.OK,
    )

    sensor_logs: Mapped[list["SensorLog"]] = relationship(
        back_populates="shelf",
        cascade="all, delete-orphan",
    )
    device_state: Mapped["DeviceState"] = relationship(
        back_populates="shelf",
        cascade="all, delete-orphan",
        uselist=False,
    )

