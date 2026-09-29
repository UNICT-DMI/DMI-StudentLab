"""Store the official listing from which each notice was fetched.

Revision ID: b948notice_listing_source
Revises: b947academic_catalog
"""
from alembic import op
import sqlalchemy as sa

revision = 'b948notice_listing_source'
down_revision = 'b947academic_catalog'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('dmi_external_notices', sa.Column('source_url', sa.Text(), nullable=True))


def downgrade():
    op.drop_column('dmi_external_notices', 'source_url')
