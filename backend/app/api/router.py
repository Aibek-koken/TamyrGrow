"""Application API router."""

from fastapi import APIRouter

from app.api.routes.assistant import router as assistant_router
from app.api.routes.dashboard import router as dashboard_router
from app.api.routes.sensors import router as sensors_router
from app.api.routes.shelves import router as shelves_router

api_router = APIRouter()
api_router.include_router(dashboard_router)
api_router.include_router(shelves_router)
api_router.include_router(sensors_router)
api_router.include_router(assistant_router)

