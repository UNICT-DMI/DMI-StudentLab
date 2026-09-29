"""Ambito degli avvisi e appelli Scienze Biologiche 2027.

Revision ID: b944notice_scope_l13_exams
Revises: b943student_verification
"""
import json
from datetime import date, datetime, time
from pathlib import Path

from alembic import op
import sqlalchemy as sa

revision = 'b944notice_scope_l13_exams'
down_revision = 'b943student_verification'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    columns = {col['name'] for col in sa.inspect(bind).get_columns('dmi_external_notices')}
    if 'university' not in columns:
        op.add_column('dmi_external_notices', sa.Column('university', sa.String(255), nullable=False,
                      server_default='Università di Catania'))
    if 'department' not in columns:
        op.add_column('dmi_external_notices', sa.Column('department', sa.String(255), nullable=True))
    if 'course' not in columns:
        op.add_column('dmi_external_notices', sa.Column('course', sa.String(255), nullable=True))
    bind.execute(sa.text("UPDATE dmi_external_notices SET department='DMI', course='L-31' "
                         "WHERE original_url LIKE 'https://web.dmi.unict.it/%/l-31/%' AND course IS NULL"))

    path = Path(__file__).resolve().parents[2] / 'data' / 'scienze_biologiche_esami_2027.json'
    entries = json.loads(path.read_text(encoding='utf-8'))['exams']
    statement = sa.text("""INSERT INTO calendar_events
        (university,department,course,kind,title,starts_at,all_day,teachers_json,
         notes,status,source,source_ref,created_by_name,updated_by_name,created_at,updated_at)
        SELECT :university,:department,:course,'exam',:title,:starts_at,true,'[]',
               :notes,'provisional','pdf',:source_ref,'StudentLab','StudentLab',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP
        WHERE NOT EXISTS (SELECT 1 FROM calendar_events WHERE course=:course AND
             title=:title AND starts_at=:starts_at AND kind='exam')""")
    for day, subject, restricted in entries:
        if date.fromisoformat(day) < date.today():
            continue
        bind.execute(statement, {'university':'Università di Catania', 'department':'DSBGA',
            'course':'L-13', 'title':subject, 'starts_at':datetime.combine(date.fromisoformat(day),time()),
            'notes':('Appello riservato a studenti fuori corso e/o in difficoltà. '
                     if restricted else '') + 'Ora e aula da confermare con il docente; prenotazione dal portale studente.',
            'source_ref':'Scienze Biologiche · esami 2027 · aggiornato 23/06/2026'})


def downgrade():
    bind = op.get_bind()
    bind.execute(sa.text("DELETE FROM calendar_events WHERE source_ref="
                         "'Scienze Biologiche · esami 2027 · aggiornato 23/06/2026'"))
    op.drop_column('dmi_external_notices','course')
    op.drop_column('dmi_external_notices','department')
    op.drop_column('dmi_external_notices','university')
