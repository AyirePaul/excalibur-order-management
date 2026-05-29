"""Unit tests for services that don't need a database (pure logic)."""
import uuid
from datetime import date
from decimal import Decimal
from unittest.mock import MagicMock

from app.schemas.orders import CombineRequest
from app.services.sort import sort_by


def _make_combine_request(**kwargs) -> CombineRequest:
    defaults = {"amount_op": "GT", "amount_value": Decimal("0")}
    defaults.update(kwargs)
    return CombineRequest(**defaults)


def test_sort_by_used_in_combine(monkeypatch):
    """Verify sort_by is called twice (once for dates, once for amounts)."""
    call_count = {"n": 0}
    original = sort_by

    def counted_sort(items, key_fn, reverse=False):
        call_count["n"] += 1
        return original(items, key_fn, reverse=reverse)

    monkeypatch.setattr("app.services.orders.sort_by", counted_sort)

    from app.services.orders import combine_orders

    db = MagicMock()
    db.scalars.return_value.all.return_value = []
    db.execute.return_value = None

    combine_orders(db, _make_combine_request())
    assert call_count["n"] == 2, "sort_by must be called for dates and details"


def test_combine_inner_join_semantics():
    """combine_orders only includes rows in both date and detail lists."""
    oid1, oid2, oid3 = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()

    from unittest.mock import MagicMock

    date_obj1 = MagicMock(order_id=oid1, order_date=date(2025, 1, 1))
    date_obj2 = MagicMock(order_id=oid2, order_date=date(2025, 2, 1))
    date_obj3 = MagicMock(order_id=oid3, order_date=date(2025, 3, 1))

    detail_obj1 = MagicMock(order_id=oid1, order_amount=Decimal("100"), order_description="A")
    # oid2 has no detail — should be excluded
    detail_obj3 = MagicMock(order_id=oid3, order_amount=Decimal("300"), order_description="C")

    db = MagicMock()
    # First call: date rows, second call: detail rows
    db.scalars.return_value.all.side_effect = [
        [date_obj1, date_obj2, date_obj3],
        [detail_obj1, detail_obj3],
    ]
    db.execute.return_value = None

    from app.services.orders import combine_orders

    result = combine_orders(db, _make_combine_request())
    result_ids = {r.order_id for r in result}
    assert oid1 in result_ids
    assert oid3 in result_ids
    assert oid2 not in result_ids  # no matching detail


def test_combine_date_sort_ascending():
    """Dates in result must be ascending."""
    oid1, oid2 = uuid.uuid4(), uuid.uuid4()

    date_obj1 = MagicMock(order_id=oid1, order_date=date(2025, 3, 1))
    date_obj2 = MagicMock(order_id=oid2, order_date=date(2025, 1, 1))

    detail_obj1 = MagicMock(order_id=oid1, order_amount=Decimal("10"), order_description="B")
    detail_obj2 = MagicMock(order_id=oid2, order_amount=Decimal("20"), order_description="A")

    db = MagicMock()
    db.scalars.return_value.all.side_effect = [
        [date_obj1, date_obj2],
        [detail_obj1, detail_obj2],
    ]
    db.execute.return_value = None

    from app.services.orders import combine_orders

    result = combine_orders(db, _make_combine_request())
    dates = [r.order_date for r in result]
    assert dates == sorted(dates)
