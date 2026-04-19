"""Dashboard response schemas."""

from app.schemas.common import ORMBaseSchema
from app.schemas.shelf import ShelfSummaryRead


class DashboardSummaryResponse(ORMBaseSchema):
    """Traffic-light summary for all shelves."""

    shelves: list[ShelfSummaryRead]

