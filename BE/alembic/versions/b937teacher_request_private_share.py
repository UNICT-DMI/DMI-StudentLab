"""Record the private share that fulfills a teacher material request.

Revision ID: b937teacherprivateshare
Revises: b936requestforward
"""
from alembic import op
import sqlalchemy as sa

revision = 'b937teacherprivateshare'
down_revision = 'b936requestforward'
branch_labels = None
depends_on = None


TABLE = 'teacher_material_requests'
COLUMN = 'fulfilled_share_id'
INDEX = 'ix_teacher_material_requests_fulfilled_share_id'
FOREIGN_KEY = 'fk_teacher_material_requests_fulfilled_share'


def upgrade():
    inspector = sa.inspect(op.get_bind())
    columns = {col['name']: col for col in inspector.get_columns(TABLE)}
    existing = columns.get(COLUMN)
    if existing is not None and (not isinstance(existing['type'], sa.Integer) or not existing['nullable']):
        raise RuntimeError(f'{TABLE}.{COLUMN} non è una colonna INTEGER facoltativa.')

    indexes = inspector.get_indexes(TABLE)
    if any(index['name'] == INDEX and index['column_names'] != [COLUMN] for index in indexes):
        raise RuntimeError(f'L’indice {INDEX} esiste ma punta a colonne diverse.')

    foreign_keys = inspector.get_foreign_keys(TABLE)
    matches = [key for key in foreign_keys if COLUMN in key['constrained_columns']]
    if matches and not any(
        key['constrained_columns'] == [COLUMN]
        and key['referred_table'] == 'material_shares'
        and key['referred_columns'] == ['id']
        and (key.get('options') or {}).get('ondelete', '').upper() == 'SET NULL'
        for key in matches
    ):
        raise RuntimeError(f'{TABLE}.{COLUMN} ha un vincolo esterno incompatibile.')
    if not matches and any(key['name'] == FOREIGN_KEY for key in foreign_keys):
        raise RuntimeError(f'Il nome del vincolo {FOREIGN_KEY} è già utilizzato.')

    if existing is None:
        op.add_column(TABLE, sa.Column(COLUMN, sa.Integer(), nullable=True))
    if not any(index['column_names'] == [COLUMN] for index in indexes):
        op.create_index(INDEX, TABLE, [COLUMN])
    if not matches:
        op.create_foreign_key(FOREIGN_KEY, TABLE, 'material_shares', [COLUMN], ['id'], ondelete='SET NULL')


def downgrade():
    raise RuntimeError('Downgrade b937 disabilitato: la colonna preesisteva alla migrazione e contiene potenzialmente dati.')
