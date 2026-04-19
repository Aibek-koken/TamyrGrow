"""Utility helpers for hydroponics calculations."""

import math


def calculate_vpd(temperature: float, humidity: float) -> float:
    """Calculate Vapor Pressure Deficit (kPa) from temperature and RH."""
    if humidity < 0 or humidity > 100:
        raise ValueError("Humidity must be between 0 and 100.")

    saturation_vapor_pressure = 0.6108 * math.exp((17.27 * temperature) / (temperature + 237.3))
    actual_vapor_pressure = saturation_vapor_pressure * (humidity / 100.0)
    return round(saturation_vapor_pressure - actual_vapor_pressure, 3)

