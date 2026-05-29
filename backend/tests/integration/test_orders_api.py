"""Integration tests: full HTTP round-trips against a real Postgres (testcontainers)."""

import uuid
from datetime import date
from decimal import Decimal

from app.models.order_combined import OrderCombined
from app.models.order_date import OrderDate
from app.models.order_detail import OrderDetail


def _seed(db, n=5):
    """Insert n order pairs and return their UUIDs."""
    ids = []
    for i in range(n):
        oid = uuid.uuid4()
        db.add(OrderDate(order_id=oid, order_date=date(2025, i + 1, 1)))
        db.add(
            OrderDetail(
                order_id=oid,
                order_amount=Decimal(str((i + 1) * 50)),
                order_description=f"item {i}",
            )
        )
        ids.append(oid)
    db.commit()
    return ids


# ── CRUD ──────────────────────────────────────────────────────────────────────

def test_create_order(client):
    resp = client.post(
        "/orders",
        json={"order_date": "2025-06-01", "order_amount": "199.99", "order_description": "test item"},  # noqa: E501
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["order_amount"] == "199.99"
    assert uuid.UUID(data["order_id"])


def test_list_orders(client, db_session):
    _seed(db_session)
    resp = client.get("/orders")
    assert resp.status_code == 200
    assert len(resp.json()) >= 5


def test_get_order(client, db_session):
    ids = _seed(db_session, 1)
    resp = client.get(f"/orders/{ids[0]}")
    assert resp.status_code == 200
    assert resp.json()["order_id"] == str(ids[0])


def test_get_order_not_found(client):
    resp = client.get(f"/orders/{uuid.uuid4()}")
    assert resp.status_code == 404


def test_update_order(client, db_session):
    ids = _seed(db_session, 1)
    resp = client.put(
        f"/orders/{ids[0]}",
        json={"order_description": "updated description"},
    )
    assert resp.status_code == 200
    assert resp.json()["order_description"] == "updated description"


def test_delete_order(client, db_session):
    ids = _seed(db_session, 1)
    resp = client.delete(f"/orders/{ids[0]}")
    assert resp.status_code == 204

    resp2 = client.get(f"/orders/{ids[0]}")
    assert resp2.status_code == 404


# ── combine ───────────────────────────────────────────────────────────────────

def test_combine_gt(client, db_session):
    _seed(db_session)
    resp = client.post(
        "/orders/combine",
        json={"amountOp": "GT", "amountValue": 100},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["count"] > 0
    for item in body["items"]:
        assert float(item["order_amount"]) > 100


def test_combine_lt(client, db_session):
    _seed(db_session)
    resp = client.post("/orders/combine", json={"amountOp": "LT", "amountValue": 200})
    assert resp.status_code == 200
    for item in resp.json()["items"]:
        assert float(item["order_amount"]) < 200


def test_combine_between(client, db_session):
    _seed(db_session)
    resp = client.post(
        "/orders/combine",
        json={"amountOp": "BETWEEN", "amountValue": 50, "amountValue2": 200},
    )
    assert resp.status_code == 200
    for item in resp.json()["items"]:
        assert 50 <= float(item["order_amount"]) <= 200


def test_combine_empty_result(client):
    resp = client.post(
        "/orders/combine",
        json={"amountOp": "GT", "amountValue": 9999999},
    )
    assert resp.status_code == 200
    assert resp.json()["count"] == 0


def test_combine_result_in_order_combined(client, db_session):
    _seed(db_session)
    resp = client.post("/orders/combine", json={"amountOp": "GT", "amountValue": 0})
    assert resp.status_code == 200
    expected_count = resp.json()["count"]
    actual_count = db_session.query(OrderCombined).count()
    assert actual_count == expected_count


def test_combine_dates_ascending(client, db_session):
    _seed(db_session)
    resp = client.post("/orders/combine", json={"amountOp": "GT", "amountValue": 0})
    items = resp.json()["items"]
    dates = [item["order_date"] for item in items]
    assert dates == sorted(dates)


def test_combine_no_n_plus_1(client, db_session):
    """Verify all data is loaded without extra per-row queries (selectin on relationship)."""
    _seed(db_session, 10)
    from sqlalchemy import event

    query_count = {"n": 0}

    @event.listens_for(db_session.bind, "before_cursor_execute")  # type: ignore[arg-type]
    def _count(conn, cursor, statement, *a, **kw):
        query_count["n"] += 1

    client.post("/orders/combine", json={"amountOp": "GT", "amountValue": 0})
    # selectinload issues at most 2 queries for a one-to-one (date + detail), not N+1
    assert query_count["n"] <= 10, f"Too many queries: {query_count['n']}"


# ── CSV export ────────────────────────────────────────────────────────────────

def test_export_csv(client, db_session):
    _seed(db_session)
    resp = client.get("/orders/export.csv?amountOp=GT&amountValue=0")
    assert resp.status_code == 200
    assert "text/csv" in resp.headers["content-type"]
    lines = resp.text.strip().splitlines()
    assert lines[0] == "order_id,order_date,order_amount,order_description"
    assert len(lines) > 1


# ── health ────────────────────────────────────────────────────────────────────

def test_healthz(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200


def test_readyz(client):
    resp = client.get("/readyz")
    assert resp.status_code == 200
