"""repair missing group news tables

Revision ID: 3a3f2761892f
Revises: 9bb198f2af51
Create Date: 2026-08-21 23:18:46.604171

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3a3f2761892f'
down_revision: Union[str, Sequence[str], None] = '9bb198f2af51'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
