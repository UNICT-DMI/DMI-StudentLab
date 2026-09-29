"""LM-18 subjects and first semester teaching timetable 2026/27.

Revision ID: b945lm18_timetable
Revises: b944notice_scope_l13_exams
"""
import json
from datetime import date, datetime, timedelta
from pathlib import Path

from alembic import op
import sqlalchemy as sa

revision = 'b945lm18_timetable'
down_revision = 'b944notice_scope_l13_exams'
branch_labels = None
depends_on = None

SOURCE = 'DMI LM-18 · orario 15/09/2026 · primo semestre 2026/27'


def upgrade():
    bind = op.get_bind()
    cols = {c['name'] for c in sa.inspect(bind).get_columns('calendar_events')}
    if 'curricula_json' not in cols:
        op.add_column('calendar_events', sa.Column('curricula_json', sa.Text(), nullable=True))
    data = json.loads((Path(__file__).resolve().parents[2] / 'data' /
                       'informatica_magistrale_lm18_2026_27.json').read_text(encoding='utf-8'))
    subject_ids = {}
    for row in data['subjects']:
        code = row['code']
        subject_id = bind.execute(sa.text('''SELECT id FROM subjects WHERE university_code='UNICT'
            AND department_code='DMI' AND course_code='LM-18' AND code=:code LIMIT 1'''),
                                  {'code': code}).scalar()
        if subject_id is None:
            subject_id = bind.execute(sa.text('''INSERT INTO subjects
                (code,name,university,university_code,department,department_code,course,course_code,
                 degree_type,study_year,is_active) VALUES
                (:code,:name,'Università degli Studi di Catania','UNICT',
                 'Dipartimento di Matematica e Informatica','DMI',
                 'Informatica magistrale (LM-18)','LM-18','LM-18',:year,true) RETURNING id'''),
                                      {'code': code, 'name': row['name'],
                                       'year': row['years'][0] if len(row['years']) == 1 else None}).scalar_one()
        subject_ids[row['name'].casefold()] = subject_id
        for offering in row['offerings']:
            module = offering['module']
            offering_id = bind.execute(sa.text('''SELECT id FROM subject_offerings
                WHERE subject_id=:subject_id AND module IS NOT DISTINCT FROM :module
                  AND channel IS NULL AND academic_year IS NULL LIMIT 1'''),
                                       {'subject_id': subject_id, 'module': module}).scalar()
            if offering_id is None:
                offering_id = bind.execute(sa.text('''INSERT INTO subject_offerings
                    (subject_id,module,channel,academic_year,source_url,is_active)
                    VALUES (:subject_id,:module,NULL,NULL,:url,true) RETURNING id'''),
                                           {'subject_id': subject_id, 'module': module,
                                            'url': row['source_url'] or data['program_url']}).scalar_one()
            for name in offering['teachers']:
                teacher_id = bind.execute(sa.text('''SELECT id FROM academic_teachers
                    WHERE lower(name)=lower(:name) LIMIT 1'''), {'name': name}).scalar()
                if teacher_id is None:
                    teacher_id = bind.execute(sa.text('INSERT INTO academic_teachers (name,is_active) VALUES (:name,true) RETURNING id'),
                                              {'name': name}).scalar_one()
                bind.execute(sa.text('''INSERT INTO subject_offering_teachers(offering_id,teacher_id)
                    SELECT :offering,:teacher WHERE NOT EXISTS
                    (SELECT 1 FROM subject_offering_teachers WHERE offering_id=:offering AND teacher_id=:teacher)'''),
                             {'offering': offering_id, 'teacher': teacher_id})

    # Some lesson names identify modules or differ from the teaching catalogue.
    aliases = {
        'algoritmi e complessità': "ALGORITMI E COMPLESSITA'",
        'artificial and swarm intelligence': 'Artificial and Evolutionary Intelligence',
        'advanced topics in mathematical logic for computer science': 'Logic and Formal Language Theory',
        'bioinformatics foundations': 'Bioinformatic Foundations',
        'deep learning: core models and methods': 'Deep Learning',
        'logica matematica per l’informatica': "Logica Matematica per l'Informatica",
        'introduzione alla meccanica quantistica': 'Fondamenti e Architetture della Computazione Quantistica',
    }
    insert = sa.text('''INSERT INTO calendar_events
        (university,department,course,subject_id,kind,title,starts_at,ends_at,all_day,room,
         teachers_json,notes,status,source,source_ref,curricula_json,
         created_by_name,updated_by_name,created_at,updated_at)
        SELECT 'Università di Catania','DMI','LM-18',:subject_id,'lessons',:title,
               :starts,:ends,false,:room,'[]',:notes,'confirmed','official',:source_ref,
               :curricula,'StudentLab','StudentLab',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP
        WHERE NOT EXISTS (SELECT 1 FROM calendar_events WHERE source_ref=:source_ref
                          AND title=:title AND starts_at=:starts AND room=:room)''')
    first, last = date(2026, 10, 1), date(2027, 1, 15)
    for lesson in data['lessons']:
        start_clock, end_clock = lesson['time'].split('-')
        subject_id = subject_ids.get(lesson['subject'].casefold())
        if subject_id is None:
            subject_id = subject_ids.get(aliases.get(lesson['subject'].casefold(), '').casefold())
        if subject_id is None:
            # Timetable-only entries have no published teaching code yet.
            subject_id = bind.execute(sa.text('''SELECT id FROM subjects WHERE course_code='LM-18'
                AND lower(name)=lower(:name) LIMIT 1'''), {'name': lesson['subject']}).scalar()
            if subject_id is None:
                subject_id = bind.execute(sa.text('''INSERT INTO subjects
                    (code,name,university,university_code,department,department_code,course,
                     course_code,degree_type,study_year,is_active) VALUES
                    (NULL,:name,'Università degli Studi di Catania','UNICT',
                     'Dipartimento di Matematica e Informatica','DMI',
                     'Informatica magistrale (LM-18)','LM-18','LM-18',:year,true) RETURNING id'''),
                                          {'name': lesson['subject'],
                                           'year': lesson['years'][0] if len(lesson['years']) == 1 else None}).scalar_one()
            subject_ids[lesson['subject'].casefold()] = subject_id
        current = first + timedelta(days=(lesson['weekday'] - first.weekday()) % 7)
        while current <= last:
            if not date(2026, 12, 17) <= current <= date(2027, 1, 6):
                bind.execute(insert, {
                    'subject_id': subject_id, 'title': lesson['subject'],
                    'starts': datetime.fromisoformat(f'{current}T{start_clock}'),
                    'ends': datetime.fromisoformat(f'{current}T{end_clock}'),
                    'room': lesson['room'], 'curricula': json.dumps(lesson['curricula']),
                    'source_ref': SOURCE,
                    'notes': ('LM-18 · primo semestre 2026/27 · anno ' +
                              ', '.join(str(year) for year in lesson['years']) +
                              '. Orario aggiornato al 15/09/2026; controlla gli avvisi per eventuali variazioni.')})
            current += timedelta(days=7)


def downgrade():
    # Preserve existing subjects and teachers, which may now have student associations.
    op.get_bind().execute(sa.text('DELETE FROM calendar_events WHERE source_ref=:source'), {'source': SOURCE})
    op.drop_column('calendar_events', 'curricula_json')
