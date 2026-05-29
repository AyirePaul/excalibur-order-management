import uuid

from sqlalchemy import insert, select, text
from sqlalchemy.orm import Session

from app.models.order_combined import OrderCombined
from app.models.order_date import OrderDate
from app.models.order_detail import OrderDetail
from app.schemas.orders import (
    CombineRequest,
    OrderCombinedRead,
    OrderCreate,
    OrderRead,
    OrderUpdate,
)
from app.services.sort import sort_by

# ── helpers ───────────────────────────────────────────────────────────────────

def order_to_read(od: OrderDate) -> OrderRead:
    return OrderRead(
        order_id=od.order_id,
        order_date=od.order_date,
        order_amount=od.detail.order_amount,
        order_description=od.detail.order_description,
    )


# ── CRUD ──────────────────────────────────────────────────────────────────────

def list_orders(db: Session) -> list[OrderRead]:
    rows = db.scalars(select(OrderDate)).all()
    return [order_to_read(r) for r in rows if r.detail]


def get_order(db: Session, order_id: uuid.UUID) -> OrderDate | None:
    return db.get(OrderDate, order_id)


def create_order(db: Session, payload: OrderCreate) -> OrderRead:
    oid = uuid.uuid4()
    db.add(OrderDate(order_id=oid, order_date=payload.order_date))
    db.add(
        OrderDetail(
            order_id=oid,
            order_amount=payload.order_amount,
            order_description=payload.order_description,
        )
    )
    db.commit()
    od = db.get(OrderDate, oid)
    return order_to_read(od)  # type: ignore[arg-type]


def update_order(db: Session, order_id: uuid.UUID, payload: OrderUpdate) -> OrderRead | None:
    od = db.get(OrderDate, order_id)
    if od is None:
        return None
    if payload.order_date is not None:
        od.order_date = payload.order_date
    if od.detail:
        if payload.order_amount is not None:
            od.detail.order_amount = payload.order_amount
        if payload.order_description is not None:
            od.detail.order_description = payload.order_description
    db.commit()
    db.refresh(od)
    return order_to_read(od)


def delete_order(db: Session, order_id: uuid.UUID) -> bool:
    od = db.get(OrderDate, order_id)
    if od is None:
        return False
    db.delete(od)
    db.commit()
    return True


# ── combine ───────────────────────────────────────────────────────────────────

def combine_orders(db: Session, req: CombineRequest) -> list[OrderCombinedRead]:
    # CombineRequest.model_validator already applies the current-year default
    # for missing date_from/date_to and validates BETWEEN requires amount_value2.

    # 1. Load order_date rows matching date filter
    date_q = select(OrderDate)
    if req.date_from:
        date_q = date_q.where(OrderDate.order_date >= req.date_from)
    if req.date_to:
        date_q = date_q.where(OrderDate.order_date <= req.date_to)
    date_rows: list[OrderDate] = list(db.scalars(date_q).all())

    # 2. Load order_detail rows matching amount + description filter
    detail_q = select(OrderDetail)
    if req.amount_op == "GT":
        detail_q = detail_q.where(OrderDetail.order_amount > req.amount_value)
    elif req.amount_op == "LT":
        detail_q = detail_q.where(OrderDetail.order_amount < req.amount_value)
    elif req.amount_op == "BETWEEN":
        detail_q = detail_q.where(
            OrderDetail.order_amount.between(req.amount_value, req.amount_value2)
        )
    if req.description_contains:
        detail_q = detail_q.where(
            OrderDetail.order_description.ilike(f"%{req.description_contains}%")
        )
    detail_rows: list[OrderDetail] = list(db.scalars(detail_q).all())

    # 3. Sort source collections
    sorted_dates = sort_by(date_rows, key_fn=lambda r: r.order_date)
    sorted_details = sort_by(detail_rows, key_fn=lambda r: r.order_amount, reverse=True)

    # 4. Join via comprehension (inner join on order_id)
    detail_map = {d.order_id: d for d in sorted_details}
    joined: list[OrderCombinedRead] = [
        OrderCombinedRead(
            order_id=od.order_id,
            order_date=od.order_date,
            order_amount=detail_map[od.order_id].order_amount,
            order_description=detail_map[od.order_id].order_description,
        )
        for od in sorted_dates
        if od.order_id in detail_map
    ]

    # 5. Apply final sort: primary = date ASC, secondary = amount DESC.
    # The dict lookup in step 4 discards the amount-DESC ordering from sorted_details,
    # so we re-apply it here as a secondary sort for rows sharing the same date.
    joined.sort(key=lambda r: (r.order_date, -r.order_amount))

    # 6. Single transaction: TRUNCATE + bulk INSERT
    try:
        # TRUNCATE is intentional here — faster than DELETE for full-table wipe at this scale
        db.execute(text("TRUNCATE TABLE order_combined"))
        if joined:
            db.execute(
                insert(OrderCombined),
                [r.model_dump() for r in joined],
            )
        db.commit()
    except Exception:
        db.rollback()
        raise

    return joined
