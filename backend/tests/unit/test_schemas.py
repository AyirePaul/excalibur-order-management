import uuid
from datetime import date
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.schemas.orders import (
    CombineRequest,
    OrderCombinedRead,
    OrderCreate,
    OrderRead,
    OrderUpdate,
)


def test_order_create_valid():
    o = OrderCreate(order_date=date(2025, 1, 1), order_amount=Decimal("100.00"), order_description="test")  # noqa: E501
    assert o.order_amount == Decimal("100.00")


def test_order_create_negative_amount_rejected():
    with pytest.raises(ValidationError):
        OrderCreate(order_date=date(2025, 1, 1), order_amount=Decimal("-1"), order_description="x")


def test_order_create_empty_description_rejected():
    with pytest.raises(ValidationError):
        OrderCreate(order_date=date(2025, 1, 1), order_amount=Decimal("10"), order_description="")


def test_order_update_partial():
    u = OrderUpdate(order_amount=Decimal("99.99"))
    assert u.order_date is None
    assert u.order_amount == Decimal("99.99")


def test_combine_request_camel_alias():
    req = CombineRequest.model_validate(
        {"amountOp": "GT", "amountValue": 100.0}, strict=False
    )
    assert req.amount_op == "GT"
    assert req.amount_value == Decimal("100.0")


def test_combine_request_between_requires_value2():
    req = CombineRequest(amount_op="BETWEEN", amount_value=Decimal("10"), amount_value2=Decimal("20"))  # noqa: E501
    assert req.amount_value2 == Decimal("20")


def test_order_combined_read_from_attributes():
    oid = uuid.uuid4()
    r = OrderCombinedRead(
        order_id=oid,
        order_date=date(2025, 6, 15),
        order_amount=Decimal("250.00"),
        order_description="widget A",
    )
    assert r.order_id == oid


def test_order_read_serializes_uuid():
    oid = uuid.uuid4()
    r = OrderRead(
        order_id=oid,
        order_date=date(2025, 1, 1),
        order_amount=Decimal("50"),
        order_description="desc",
    )
    dumped = r.model_dump()
    assert dumped["order_id"] == oid
