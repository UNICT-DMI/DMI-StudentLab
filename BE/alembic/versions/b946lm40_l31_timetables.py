"""Mathematics LM-40 programme and 2026/27 first semester L-31/LM-40 timetables.

Revision ID: b946lm40_l31_times
Revises: b945lm18_timetable
"""
import csv
import json
from datetime import date, datetime, timedelta
from pathlib import Path

from alembic import op
import sqlalchemy as sa

revision = 'b946lm40_l31_times'
down_revision = 'b945lm18_timetable'
branch_labels = None
depends_on = None

DATA = Path(__file__).resolve().parents[2] / 'data'
SOURCE_LM40 = 'LM-40 · orario I semestre 2026/27 · PDF fornito dal DMI'
SOURCE_L31 = 'L-31 · orario I semestre 2026/27 · PDF 1°, 2°, 3° anno'


def _rows(filename):
    with (DATA / filename).open(encoding='utf-8', newline='') as file:
        yield from csv.DictReader(file, delimiter='\t')


def _subject(bind, course_code, name, year=None, code=None):
    args = {'course_code': course_code, 'name': name, 'code': code}
    subject_id = None
    if code:
        subject_id = bind.execute(sa.text('''SELECT id FROM subjects WHERE university_code='UNICT'
            AND department_code='DMI' AND course_code=:course_code AND code=:code LIMIT 1'''), args).scalar()
    if subject_id is None and not code:
        subject_id = bind.execute(sa.text('''SELECT id FROM subjects WHERE university_code='UNICT'
            AND course_code=:course_code AND lower(name)=lower(:name) LIMIT 1'''), args).scalar()
    if subject_id is not None:
        return subject_id
    args.update(year=year, course='Matematica magistrale (LM-40)' if course_code == 'LM-40' else 'Informatica')
    return bind.execute(sa.text('''INSERT INTO subjects
        (code,name,university,university_code,department,department_code,course,
         course_code,degree_type,study_year,is_active) VALUES
        (:code,:name,'Università degli Studi di Catania','UNICT',
         'Dipartimento di Matematica e Informatica','DMI',:course,
         :course_code,:course_code,:year,true) RETURNING id'''), args).scalar_one()


def _offering_teacher(bind, subject_id, module, teacher):
    if not module and not teacher:
        return
    args = {'subject_id': subject_id, 'module': module or None}
    offering = bind.execute(sa.text('''SELECT id FROM subject_offerings WHERE subject_id=:subject_id
        AND module IS NOT DISTINCT FROM :module AND channel IS NULL AND academic_year IS NULL LIMIT 1'''), args).scalar()
    if offering is None:
        offering = bind.execute(sa.text('''INSERT INTO subject_offerings
            (subject_id,module,channel,academic_year,source_url,is_active)
            VALUES (:subject_id,:module,NULL,NULL,'https://web.dmi.unict.it/corsi/lm-40/programmi',true)
            RETURNING id'''), args).scalar_one()
    if teacher:
        teacher_id = bind.execute(sa.text('SELECT id FROM academic_teachers WHERE lower(name)=lower(:name) LIMIT 1'),
                                  {'name': teacher}).scalar()
        if teacher_id is None:
            teacher_id = bind.execute(sa.text('INSERT INTO academic_teachers(name,is_active) VALUES (:name,true) RETURNING id'),
                                      {'name': teacher}).scalar_one()
        bind.execute(sa.text('''INSERT INTO subject_offering_teachers (offering_id,teacher_id)
            SELECT :offering,:teacher WHERE NOT EXISTS (SELECT 1 FROM subject_offering_teachers
            WHERE offering_id=:offering AND teacher_id=:teacher)'''),
                     {'offering': offering, 'teacher': teacher_id})


def _lessons(bind, records, code, source):
    insert = sa.text('''INSERT INTO calendar_events
        (university,department,course,subject_id,kind,title,starts_at,ends_at,all_day,room,
         teachers_json,notes,status,source,source_ref,curricula_json,
         created_by_name,updated_by_name,created_at,updated_at)
        SELECT 'Università di Catania','DMI',:course,:subject_id,'lessons',:title,
               :starts,:ends,false,:room,:teachers,:notes,'confirmed','official',:source_ref,
               :curricula,'StudentLab','StudentLab',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP
        WHERE NOT EXISTS (SELECT 1 FROM calendar_events WHERE source_ref=:source_ref
              AND title=:title AND starts_at=:starts AND room=:room)''')
    for item in records:
        name = item['subject']
        subject_id = _subject(bind, code, name)
        start_clock, end_clock = item['time'].split('-')
        first, last = date(2026, 10, 1), date(2027, 1, 15)
        current = first + timedelta(days=(item['weekday'] - first.weekday()) % 7)
        while current <= last:
            if not date(2026, 12, 17) <= current <= date(2027, 1, 6):
                bind.execute(insert, {'course': code, 'subject_id': subject_id,
                    'title': name, 'starts': datetime.fromisoformat(f'{current}T{start_clock}'),
                    'ends': datetime.fromisoformat(f'{current}T{end_clock}'),
                    'room': item['room'], 'teachers': json.dumps(item.get('teachers', []), ensure_ascii=False),
                    'curricula': json.dumps(item.get('channels', []), ensure_ascii=False),
                    'notes': f'Primo semestre 2026/27 · orario PDF; controlla gli avvisi per variazioni.',
                    'source_ref': source})
            current += timedelta(days=7)


def upgrade():
    bind = op.get_bind()
    program = list(_rows('matematica_magistrale_lm40_programmi.tsv'))
    years = {}
    for item in program:
        years.setdefault(item['code'], set()).add(int(item['year']))
    for item in program:
        ys = years[item['code']]
        subject_id = _subject(bind, 'LM-40', item['name'], next(iter(ys)) if len(ys) == 1 else None, item['code'])
        _offering_teacher(bind, subject_id, item['module'], item['teacher'])

    teachers_by_subject = {}
    for row in program:
        if row['teacher']:
            teachers_by_subject.setdefault(row['name'].casefold(), set()).add(row['teacher'])
    lm40 = [{'subject': r['subject'], 'weekday': int(r['weekday']),
             'time': r['start'] + '-' + r['end'], 'room': r['room'],
             'teachers': sorted(teachers_by_subject.get(r['subject'].casefold(), ())) }
            for r in _rows('matematica_lm40_orario_2026_27.tsv')]
    _lessons(bind, lm40, 'LM-40', SOURCE_LM40)
    l31 = json.loads((DATA / 'informatica_l31_orario_2026_27.json').read_text(encoding='utf-8'))
    _lessons(bind, l31['lessons'], 'L-31', SOURCE_L31)


def downgrade():
    # Do not delete subjects/teachers: students may already follow them.
    op.get_bind().execute(sa.text('DELETE FROM calendar_events WHERE source_ref IN (:lm40,:l31)'),
                          {'lm40': SOURCE_LM40, 'l31': SOURCE_L31})
