"""Schemas for the AI assistant chat API."""

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """Request body for shelf-aware assistant chat."""

    shelf_id: int
    message: str = Field(..., min_length=1)


class ChatResponse(BaseModel):
    """Assistant reply payload."""

    reply: str
