import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import UUID, Date, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class OrderCombined(Base):
    __tablename__ = "order_combined"

    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    order_date: Mapped[date] = mapped_column(Date, nullable=False)
    order_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    order_description: Mapped[str] = mapped_column(String(500), nullable=False)
