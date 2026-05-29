import uuid
from decimal import Decimal

from sqlalchemy import UUID, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class OrderDetail(Base):
    __tablename__ = "order_detail"

    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("order_date.order_id", ondelete="CASCADE"),
        primary_key=True,
    )
    order_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    order_description: Mapped[str] = mapped_column(String(500), nullable=False)

    date_rec: Mapped["OrderDate"] = relationship(  # type: ignore[name-defined]
        "OrderDate",
        back_populates="detail",
    )
