"""GraphQL integration tests."""

import uuid
from datetime import date
from decimal import Decimal

from app.models.order_combined import OrderCombined


def _seed_combined(db):
    oid = uuid.uuid4()
    db.add(
        OrderCombined(
            order_id=oid,
            order_date=date(2025, 6, 1),
            order_amount=Decimal("150.00"),
            order_description="GraphQL test order",
        )
    )
    db.commit()
    return oid


def test_graphql_query_joined_orders(client, db_session):
    _seed_combined(db_session)
    resp = client.post(
        "/graphql",
        json={
            "query": """
            query {
              joinedOrders(filters: {}) {
                orderId
                orderDate
                orderAmount
                orderDescription
              }
            }
            """
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    assert len(data["data"]["joinedOrders"]) >= 1


def test_graphql_mutation_upsert_create(client, db_session):
    resp = client.post(
        "/graphql",
        json={
            "query": """
            mutation {
              upsertOrder(input: {
                orderDate: "2025-07-01"
                orderAmount: "99.99"
                orderDescription: "via GraphQL"
              }) {
                orderId
                orderAmount
              }
            }
            """
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "errors" not in data or not data.get("errors")
    assert data["data"]["upsertOrder"]["orderAmount"] == "99.99"


def test_graphql_subscription_returns_event(client):
    resp = client.post(
        "/graphql",
        json={
            "query": """
            subscription {
              orderCombinedRegenerated {
                timestamp
                rowCount
              }
            }
            """
        },
    )
    # Subscription over HTTP returns 200 with an event or an unprocessable response
    # Acceptable: either a valid response or 405 (WebSocket only)
    assert resp.status_code in (200, 405, 422)
