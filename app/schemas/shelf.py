"""Shelf related schemas."""

from app.models.enums import ShelfStatus
from app.schemas.common import ORMBaseSchema


class ShelfSummaryRead(ORMBaseSchema):
    """Dashboard-oriented shelf summary payload."""

    id: int
    name: str
    status: ShelfStatus

