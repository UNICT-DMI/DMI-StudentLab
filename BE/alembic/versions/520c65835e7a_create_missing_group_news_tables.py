"""create missing group news tables

Revision ID: 520c65835e7a
Revises: cd1e6d3de3a3
Create Date: 2026-08-21 23:24:07.721584

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '520c65835e7a'
down_revision: Union[str, Sequence[str], None] = 'cd1e6d3de3a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
