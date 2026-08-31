"""repair missing group news tables

Revision ID: cd1e6d3de3a3
Revises: 3a3f2761892f
Create Date: 2026-08-21 23:19:43.271214

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'cd1e6d3de3a3'
down_revision: Union[str, Sequence[str], None] = '3a3f2761892f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
