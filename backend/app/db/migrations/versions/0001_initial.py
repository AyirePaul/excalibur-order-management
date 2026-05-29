"""Initial schema: order_date, order_detail, order_combined

Revision ID: 0001
Revises:
Create Date: 2025-01-01 00:00:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "order_date",
        sa.Column("order_id", sa.UUID(as_uuid=True), primary_key=True),
        sa.Column("order_date", sa.Date(), nullable=False),
    )

    op.create_table(
        "order_detail",
        sa.Column(
            "order_id",
            sa.UUID(as_uuid=True),
            sa.ForeignKey("order_date.order_id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("order_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("order_description", sa.String(500), nullable=False),
    )

    op.create_table(
        "order_combined",
        sa.Column("order_id", sa.UUID(as_uuid=True), primary_key=True),
        sa.Column("order_date", sa.Date(), nullable=False),
        sa.Column("order_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("order_description", sa.String(500), nullable=False),
    )

    op.create_index("ix_order_date_date", "order_date", ["order_date"])
    op.create_index("ix_order_detail_amount", "order_detail", ["order_amount"])
    op.create_index("ix_order_combined_date", "order_combined", ["order_date"])


def downgrade() -> None:
    op.drop_table("order_combined")
    op.drop_table("order_detail")
    op.drop_table("order_date")
