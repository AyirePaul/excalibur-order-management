"""Strawberry GraphQL schema — Query, Mutation, Subscription (polling fallback)."""

import uuid
from collections.abc import AsyncGenerator
from datetime import UTC, date, datetime
from decimal import Decimal

import strawberry
from fastapi import Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from strawberry.fastapi import GraphQLRouter
from strawberry.types import Info

from app.core.security import get_current_user
from app.db.base import get_db
from app.models.order_combined import OrderCombined
from app.schemas.orders import OrderCreate, OrderUpdate
from app.services import orders as svc

# ── GraphQL types ──────────────────────────────────────────────────────────────

@strawberry.type
class GQLOrder:
    order_id: strawberry.ID
    order_date: date
    order_amount: Decimal
    order_description: str


@strawberry.input
class FiltersInput:
    date_from: date | None = None
    date_to: date | None = None
    amount_op: str | None = None
    amount_value: Decimal | None = None
    amount_value2: Decimal | None = None
    description_contains: str | None = None


@strawberry.input
class OrderInput:
    order_date: date
    order_amount: Decimal
    order_description: str
    order_id: strawberry.ID | None = None


@strawberry.type
class RegenerationEvent:
    timestamp: str
    row_count: int


# ── auth helpers ───────────────────────────────────────────────────────────────

def _require_viewer(info: Info) -> None:
    user = info.context.get("user", {})
    groups = user.get("cognito:groups", [])
    if not any(g in groups for g in ("viewer", "editor")):
        raise HTTPException(status_code=403, detail="Viewer role required")


def _require_editor(info: Info) -> None:
    user = info.context.get("user", {})
    groups = user.get("cognito:groups", [])
    if "editor" not in groups:
        raise HTTPException(status_code=403, detail="Editor role required")


# ── context helper ─────────────────────────────────────────────────────────────

def _db(info: Info) -> Session:
    return info.context["db"]


# ── Query ──────────────────────────────────────────────────────────────────────

@strawberry.type
class Query:
    @strawberry.field
    def joined_orders(self, filters: FiltersInput, info: Info) -> list[GQLOrder]:
        _require_viewer(info)
        db = _db(info)

        # P1.3: Apply current-year default when both dates are omitted (spec §1.2)
        date_from = filters.date_from
        date_to = filters.date_to
        if date_from is None and date_to is None:
            today = date.today()
            date_from = date(today.year, 1, 1)
            date_to = date(today.year, 12, 31)

        # P1.4: Validate BETWEEN requires both bounds
        if filters.amount_op == "BETWEEN" and filters.amount_value2 is None:
            raise ValueError("amount_value2 is required when amount_op is BETWEEN")

        q = select(OrderCombined)
        if date_from:
            q = q.where(OrderCombined.order_date >= date_from)
        if date_to:
            q = q.where(OrderCombined.order_date <= date_to)
        if filters.amount_op and filters.amount_value is not None:
            if filters.amount_op == "GT":
                q = q.where(OrderCombined.order_amount > filters.amount_value)
            elif filters.amount_op == "LT":
                q = q.where(OrderCombined.order_amount < filters.amount_value)
            elif filters.amount_op == "BETWEEN":
                q = q.where(
                    OrderCombined.order_amount.between(filters.amount_value, filters.amount_value2)
                )
        if filters.description_contains:
            q = q.where(
                OrderCombined.order_description.ilike(f"%{filters.description_contains}%")
            )
        rows = db.scalars(q).all()
        return [
            GQLOrder(
                order_id=strawberry.ID(str(r.order_id)),
                order_date=r.order_date,
                order_amount=r.order_amount,
                order_description=r.order_description,
            )
            for r in rows
        ]


# ── Mutation ───────────────────────────────────────────────────────────────────

@strawberry.type
class Mutation:
    @strawberry.mutation
    def upsert_order(self, input: OrderInput, info: Info) -> GQLOrder:
        _require_editor(info)
        db = _db(info)
        if input.order_id:
            oid = uuid.UUID(str(input.order_id))
            result = svc.update_order(
                db,
                oid,
                OrderUpdate(
                    order_date=input.order_date,
                    order_amount=input.order_amount,
                    order_description=input.order_description,
                ),
            )
            if result is None:
                raise ValueError(f"Order {input.order_id} not found")
        else:
            result = svc.create_order(
                db,
                OrderCreate(
                    order_date=input.order_date,
                    order_amount=input.order_amount,
                    order_description=input.order_description,
                ),
            )
        return GQLOrder(
            order_id=strawberry.ID(str(result.order_id)),
            order_date=result.order_date,
            order_amount=result.order_amount,
            order_description=result.order_description,
        )


# ── Subscription (polling fallback) ───────────────────────────────────────────
# Yields a single snapshot on subscribe. Full persistent WebSocket subscription
# would require a message broker (Redis pub/sub, etc.) — see README for rationale.

@strawberry.type
class Subscription:
    @strawberry.subscription
    async def order_combined_regenerated(self) -> AsyncGenerator[RegenerationEvent, None]:
        yield RegenerationEvent(
            timestamp=datetime.now(UTC).isoformat(),
            row_count=0,
        )


# ── context factory ───────────────────────────────────────────────────────────

async def get_context(
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    return {"db": db, "user": user}


schema = strawberry.Schema(query=Query, mutation=Mutation, subscription=Subscription)
graphql_app = GraphQLRouter(schema, context_getter=get_context)
