from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import Optional


class ItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: int

    @field_validator("name")
    @classmethod
    def name_must_not_be_empty(cls, v):
        if not v.strip():
            raise ValueError("名前は空にできません")
        if len(v) > 255:
            raise ValueError("名前は255文字以内にしてください")
        return v

    @field_validator("price")
    @classmethod
    def price_must_be_positive(cls, v):
        if v < 0:
            raise ValueError("価格は0以上にしてください")
        return v


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[int] = None

    @field_validator("name")
    @classmethod
    def name_must_not_be_empty(cls, v):
        if v is not None and not v.strip():
            raise ValueError("名前は空にできません")
        return v

    @field_validator("price")
    @classmethod
    def price_must_be_positive(cls, v):
        if v is not None and v < 0:
            raise ValueError("価格は0以上にしてください")
        return v


class ItemResponse(ItemBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True