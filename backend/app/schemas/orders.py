import uuid
from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator
from pydantic.alias_generators import to_camel


class _CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


# ── order_date ──────────────────────────────────────────────────────────────

class OrderDateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    order_id: uuid.UUID
    order_date: date


# ── order_detail ─────────────────────────────────────────────────────────────

class OrderDetailRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    order_id: uuid.UUID
    order_amount: Decimal
    order_description: str


# ── combined order view (REST CRUD) ──────────────────────────────────────────

class OrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    order_id: uuid.UUID
    order_date: date
    order_amount: Decimal
    order_description: str


class OrderCreate(BaseModel):
    order_date: date
    order_amount: Decimal = Field(gt=Decimal("0"), le=Decimal("9999999999.99"))
    order_description: str = Field(min_length=1, max_length=500)


class OrderUpdate(BaseModel):
    order_date: date | None = None
    order_amount: Decimal | None = Field(default=None, gt=Decimal("0"), le=Decimal("9999999999.99"))
    order_description: str | None = Field(default=None, min_length=1, max_length=500)


# ── order_combined ───────────────────────────────────────────────────────────

class OrderCombinedRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    order_id: uuid.UUID
    order_date: date
    order_amount: Decimal
    order_description: str


# ── /orders/combine ──────────────────────────────────────────────────────────

class CombineRequest(_CamelModel):
    date_from: date | None = None
    date_to: date | None = None
    amount_op: Literal["GT", "LT", "BETWEEN"]
    amount_value: Decimal
    amount_value2: Decimal | None = None
    description_contains: str | None = None

    @model_validator(mode="after")
    def _apply_defaults_and_validate(self) -> "CombineRequest":
        # P1.3: Default to current calendar year when no date range is given (spec §1.2)
        if self.date_from is None and self.date_to is None:
            today = date.today()
            self.date_from = date(today.year, 1, 1)
            self.date_to = date(today.year, 12, 31)
        # P1.4: BETWEEN requires both bounds
        if self.amount_op == "BETWEEN" and self.amount_value2 is None:
            raise ValueError("amount_value2 is required when amount_op is BETWEEN")
        return self


class CombineResponse(BaseModel):
    items: list[OrderCombinedRead]
    count: int


# ── /orders/export.csv (query params reuse CombineRequest fields) ─────────────

class ExportParams(_CamelModel):
    date_from: date | None = None
    date_to: date | None = None
    amount_op: Literal["GT", "LT", "BETWEEN"] = "GT"
    amount_value: Decimal = Decimal("0")
    amount_value2: Decimal | None = None
    description_contains: str | None = None

    @model_validator(mode="after")
    def _validate_between(self) -> "ExportParams":
        if self.amount_op == "BETWEEN" and self.amount_value2 is None:
            raise ValueError("amount_value2 is required when amount_op is BETWEEN")
        return self
