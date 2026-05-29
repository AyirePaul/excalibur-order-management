import csv
import io
import uuid
from datetime import date as dt_date
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.security import EditorRequired, ViewerRequired
from app.db.base import get_db
from app.schemas.orders import (
    CombineRequest,
    CombineResponse,
    OrderCombinedRead,
    OrderCreate,
    OrderRead,
    OrderUpdate,
)
from app.services import orders as svc

router = APIRouter(tags=["orders"])


@router.get("", response_model=list[OrderRead])
def list_orders(_user: ViewerRequired, db: Session = Depends(get_db)):
    return svc.list_orders(db)


# /orders/combine must be declared before /{order_id} to avoid route ambiguity
@router.post("/combine", response_model=CombineResponse)
def combine_orders(req: CombineRequest, _user: ViewerRequired, db: Session = Depends(get_db)):
    items = svc.combine_orders(db, req)
    return CombineResponse(items=items, count=len(items))


@router.get("/export.csv")
def export_csv(
    _user: ViewerRequired,
    db: Session = Depends(get_db),
    date_from: str | None = Query(default=None, alias="dateFrom"),
    date_to: str | None = Query(default=None, alias="dateTo"),
    amount_op: str = Query(default="GT", alias="amountOp"),
    amount_value: float = Query(default=0.0, alias="amountValue"),
    amount_value2: float | None = Query(default=None, alias="amountValue2"),
    description_contains: str | None = Query(default=None, alias="descriptionContains"),
):
    req = CombineRequest(
        date_from=dt_date.fromisoformat(date_from) if date_from else None,
        date_to=dt_date.fromisoformat(date_to) if date_to else None,
        amount_op=amount_op,  # type: ignore[arg-type]
        amount_value=Decimal(str(amount_value)),
        amount_value2=Decimal(str(amount_value2)) if amount_value2 else None,
        description_contains=description_contains,
    )
    items: list[OrderCombinedRead] = svc.combine_orders(db, req)

    buf = io.StringIO()
    writer = csv.DictWriter(
        buf, fieldnames=["order_id", "order_date", "order_amount", "order_description"]
    )
    writer.writeheader()
    for row in items:
        writer.writerow(row.model_dump())

    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=orders.csv"},
    )


@router.post("", response_model=OrderRead, status_code=201)
def create_order(payload: OrderCreate, _user: EditorRequired, db: Session = Depends(get_db)):
    return svc.create_order(db, payload)


@router.get("/{order_id}", response_model=OrderRead)
def get_order(order_id: uuid.UUID, _user: ViewerRequired, db: Session = Depends(get_db)):
    od = svc.get_order(db, order_id)
    if od is None or od.detail is None:
        raise HTTPException(status_code=404, detail="Order not found")
    return svc.order_to_read(od)


@router.put("/{order_id}", response_model=OrderRead)
def update_order(
    order_id: uuid.UUID,
    payload: OrderUpdate,
    _user: EditorRequired,
    db: Session = Depends(get_db),
):
    result = svc.update_order(db, order_id, payload)
    if result is None:
        raise HTTPException(status_code=404, detail="Order not found")
    return result


@router.delete("/{order_id}", status_code=204)
def delete_order(order_id: uuid.UUID, _user: EditorRequired, db: Session = Depends(get_db)):
    if not svc.delete_order(db, order_id):
        raise HTTPException(status_code=404, detail="Order not found")
