"""Device state ORM model."""

from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Float, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.shelf import Shelf


class DeviceState(Base):
    """Represents current actuator/device states for one shelf."""

    __tablename__ = "device_states"

    shelf_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("shelves.id", ondelete="CASCADE"),
        primary_key=True,
    )
    light_brightness: Mapped[int] = mapped_column(Integer, nullable=False, default=50)
    fan_speed: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    target_temperature: Mapped[float] = mapped_column(Float, nullable=False, default=22.0)
    heater_on: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    humidifier_on: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_ai_mode: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    shelf: Mapped["Shelf"] = relationship(back_populates="device_state")

