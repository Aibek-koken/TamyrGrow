"""Dashboard endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session
from app.models.shelf import Shelf
from app.schemas.dashboard import DashboardSummaryResponse
from app.schemas.shelf import ShelfSummaryRead

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/summary", response_model=DashboardSummaryResponse)
async def get_dashboard_summary(
    session: AsyncSession = Depends(get_session),
) -> DashboardSummaryResponse:
    """Return traffic-light status summary for all shelves."""
    result = await session.execute(select(Shelf).order_by(Shelf.id))
    shelves = result.scalars().all()
    return DashboardSummaryResponse(
        shelves=[ShelfSummaryRead.model_validate(shelf) for shelf in shelves]
    )

