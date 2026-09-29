"""Test della moderazione del Dizionario (fonti, bozze, permessi docente).

Usa un database SQLite in memoria con le sole tabelle necessarie:
    cd BE && python -m pytest tests/test_dictionary_moderation.py -q
"""
import json

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import main  # noqa: F401 - registra i modelli SQLAlchemy
from core.database import Base
from models.dictionary import (DictionaryDraft, DictionaryEntry, DictionarySource, DictionaryTopic,
                               DictionaryVersion)
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from services.dictionary import can_edit, public_content, public_version_for_year
from services.dictionary_moderation import (ModerationError, approve_draft, drafts_from_dictionary, list_drafts,
                                            register_source, reject_draft, update_draft)

YEAR = '2025/2026'


@pytest.fixture()
def db():
    engine = create_engine('sqlite://')
    tables = [User.__table__, Subject.__table__, TeacherAssignment.__table__, DictionaryTopic.__table__,
              DictionaryEntry.__table__, DictionarySource.__table__, DictionaryVersion.__table__,
              DictionaryDraft.__table__]
    # Tabelle referenziate da chiavi esterne dei modelli (se presenti nel metadata).
    for name in ('subject_offerings', 'academic_teachers'):
        if name in Base.metadata.tables:
            tables.insert(1, Base.metadata.tables[name])
    Base.metadata.create_all(engine, tables=tables)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()


def _fill_required(model, values: dict) -> dict:
    """Riempie le colonne obbligatorie senza default che il test non usa."""
    from datetime import date, datetime, timezone
    import sqlalchemy as sa
    for column in model.__table__.columns:
        if column.name in values or column.primary_key or column.nullable or column.default is not None \
                or column.server_default is not None:
            continue
        if isinstance(column.type, sa.Boolean):
            values[column.name] = False
        elif isinstance(column.type, sa.Integer):
            values[column.name] = 0
        elif isinstance(column.type, sa.DateTime):
            values[column.name] = datetime.now(timezone.utc)
        elif isinstance(column.type, sa.Date):
            values[column.name] = date(2000, 1, 1)
        else:
            values[column.name] = f'test-{column.name}'
    return values


def _user(db, uid, role, verified=True, first='Nome'):
    values = {'id': uid, 'first_name': first, 'last_name': f'U{uid}', 'email': f'u{uid}@example.org',
              'role': role, 'is_active': True}
    if 'teacher_verification_status' in User.__table__.columns:
        values['teacher_verification_status'] = 'verified' if verified else 'pending'
    user = User(**_fill_required(User, {k: v for k, v in values.items() if k in User.__table__.columns}))
    db.add(user)
    db.flush()
    return user


def _subject(db, sid, name):
    values = {'id': sid, 'code': f'S{sid}', 'name': name, 'university': 'UNICT', 'university_code': 'UNICT',
              'department': 'Dipartimento di Matematica e Informatica', 'department_code': 'DMI',
              'course': 'Informatica', 'course_code': 'L-31', 'is_active': True}
    subject = Subject(**_fill_required(Subject, {k: v for k, v in values.items() if k in Subject.__table__.columns}))
    db.add(subject)
    db.flush()
    return subject


def _assign(db, user, subject, status='verified', current=True):
    db.add(TeacherAssignment(**_fill_required(TeacherAssignment, {
        'user_id': user.id, 'subject_id': subject.id, 'verification_status': status, 'is_current': current})))
    db.flush()


def _dictionary(*terms):
    return {'schema': 'studentlab.dictionary/1',
            'metadata': {'subject': 'Reti', 'academic_year': YEAR, 'source': 'lez14.pdf'},
            'topics': [{'id': 'routing', 'title': 'Routing'}],
            'entries': [{'id': t.lower().replace(' ', '-'), 'term': t, 'topic': 'routing',
                         'formal_definition': f'Definizione formale di {t} abbastanza lunga.',
                         '_review': {'where': 'pagina 12', 'excerpt': f'{t}: testo originale'}} for t in terms]}


def test_import_creates_only_drafts_not_public(db):
    admin = _user(db, 1, 'admin')
    reti = _subject(db, 10, 'Reti di calcolatori')
    source = register_source(db, admin, {'kind': 'pdf', 'label': 'lez14.pdf', 'sha256': 'a' * 64,
                                         'text_excerpt': 'Algoritmo di Dijkstra: …', 'metadata': {'pages': 30}}, reti)
    report = drafts_from_dictionary(db, _dictionary('Algoritmo di Dijkstra', 'OSPF'), admin, reti, None, source)
    assert report['created'] == 2
    assert db.query(DictionaryEntry).count() == 0          # niente di pubblico prima della moderazione
    draft = db.query(DictionaryDraft).filter_by(term='OSPF').one()
    assert draft.source_id == source.id and draft.source_ref == 'pagina 12'
    # Re-import identico: nessuna bozza duplicata.
    again = drafts_from_dictionary(db, _dictionary('Algoritmo di Dijkstra', 'OSPF'), admin, reti, None, source)
    assert again['created'] == 0 and again['unchanged'] == 2


def test_approve_publishes_with_author_and_reject_is_remembered(db):
    admin = _user(db, 1, 'admin')
    teacher = _user(db, 2, 'teacher', first='Francesco')
    reti = _subject(db, 10, 'Reti di calcolatori')
    _assign(db, teacher, reti)
    drafts_from_dictionary(db, _dictionary('OSPF', 'RIP'), teacher, reti, None)
    ospf = db.query(DictionaryDraft).filter_by(term='OSPF').one()
    result = approve_draft(db, ospf, admin)
    version = db.query(DictionaryVersion).get(result['version_id'])
    assert version.review_state == 'confirmed'
    assert version.author_name.startswith('Francesco')        # resta firmato da chi l'ha scritto
    assert public_version_for_year(db, result['entry_id'], YEAR) is not None
    topic = db.query(DictionaryTopic).filter_by(subject_id=reti.id, slug='routing').one()
    assert db.query(DictionaryEntry).get(result['entry_id']).topic_id == topic.id
    rip = db.query(DictionaryDraft).filter_by(term='RIP').one()
    reject_draft(db, rip, admin, 'duplicato')
    again = drafts_from_dictionary(db, _dictionary('RIP'), teacher, reti, None)
    assert again['rejected_before'] == 1                     # una bozza scartata non ritorna uguale


def test_teacher_permissions_need_verified_profile_and_assignment(db):
    reti = _subject(db, 10, 'Reti di calcolatori')
    so = _subject(db, 11, 'Sistemi operativi')
    good = _user(db, 2, 'teacher')
    unverified = _user(db, 3, 'teacher', verified=False)
    old = _user(db, 4, 'teacher')
    student = _user(db, 5, 'student')
    _assign(db, good, reti)
    _assign(db, unverified, reti)
    _assign(db, old, reti, current=False)
    _assign(db, student, reti)
    assert can_edit(db, good, reti.id)
    assert not can_edit(db, good, so.id)
    if hasattr(User, 'teacher_verification_status'):
        assert not can_edit(db, unverified, reti.id)
    assert not can_edit(db, old, reti.id)
    assert not can_edit(db, student, reti.id)
    drafts_from_dictionary(db, _dictionary('OSPF'), good, reti, None)
    assert list_drafts(db, good)['total'] == 1
    draft = db.query(DictionaryDraft).one()
    with pytest.raises(ModerationError):
        update_draft(db, draft, {'subject_id': so.id}, good)  # non può spostarlo in una materia non sua


def test_edit_draft_links_exam_and_merge_into_existing(db):
    admin = _user(db, 1, 'admin')
    reti = _subject(db, 10, 'Reti di calcolatori')
    drafts_from_dictionary(db, _dictionary('Algoritmo link-state'), admin, reti, None)
    first = approve_draft(db, db.query(DictionaryDraft).one(), admin)
    drafts_from_dictionary(db, _dictionary('Algoritmo di Dijkstra'), admin, reti, None)
    draft = db.query(DictionaryDraft).filter_by(status='pending').one()
    update_draft(db, draft, {'content': {'exam_questions': [
        {'text': 'Esegui Dijkstra da u.', 'kind': 'past', 'exam_date': '2025-07-12', 'calendar_event_id': 7}]}}, admin)
    result = approve_draft(db, draft, admin, merge_into=first['entry_id'])
    entry = db.query(DictionaryEntry).get(first['entry_id'])
    assert result['entry_id'] == entry.id
    assert 'Algoritmo di Dijkstra' in json.loads(entry.aliases_json)
    version = db.query(DictionaryVersion).get(result['version_id'])
    exam = json.loads(version.exam_questions_json)[0]
    assert exam['kind'] == 'past' and exam['calendar_event_id'] == 7


def test_public_content_hides_internal_sources():
    content = {'resources': [{'type': 'source', 'title': 'lez14.pdf, pagina 12'},
                             {'type': 'url', 'title': 'Simulatore', 'url': 'https://example.org'}]}
    assert [r['type'] for r in public_content(content)['resources']] == ['url']
