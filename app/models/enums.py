"""Enumerations for domain entities."""

from enum import Enum


class ShelfStatus(str, Enum):
    """Status indicator used by the dashboard traffic light."""

    OK = "OK"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"

