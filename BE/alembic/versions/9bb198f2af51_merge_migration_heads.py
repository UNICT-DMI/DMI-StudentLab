"""merge migration heads

Revision ID: 9bb198f2af51
Revises: d9a81c7f2b44, f1a2b3c4d5e6
Create Date: 2026-08-21 22:49:53.342383

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9bb198f2af51'
down_revision: Union[str, Sequence[str], None] = ('d9a81c7f2b44', 'f1a2b3c4d5e6')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
