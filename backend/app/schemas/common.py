"""Common schema mixins."""

from pydantic import BaseModel, ConfigDict


class ORMBaseSchema(BaseModel):
    """Base schema configured for ORM object parsing."""

    model_config = ConfigDict(from_attributes=True)

