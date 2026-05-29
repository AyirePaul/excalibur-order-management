import uuid
from datetime import date

from sqlalchemy import UUID, Date
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class OrderDate(Base):
    __tablename__ = "order_date"

    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    order_date: Mapped[date] = mapped_column(Date, nullable=False)

    detail: Mapped["OrderDetail"] = relationship(  # type: ignore[name-defined]
        "OrderDetail",
        back_populates="date_rec",
        uselist=False,
        lazy="selectin",
        cascade="all, delete-orphan",
    )
