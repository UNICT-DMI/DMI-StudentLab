"""merge study plan and news reports heads

Revision ID: 62ebe54d89b6
Revises: c9k2studyplan, d4n1reports
Create Date: 2026-09-05 21:21:56.845248

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '62ebe54d89b6'
down_revision: Union[str, Sequence[str], None] = ('c9k2studyplan', 'd4n1reports')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
