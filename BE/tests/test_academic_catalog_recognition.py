"""Unknown courses are reviewed; approximate matches are never assigned."""
from types import SimpleNamespace

from services import academic_catalog as catalog


KNOWN = {
    'university': 'Università degli Studi di Catania', 'university_code': 'UNICT',
    'department': 'Dipartimento di Matematica e Informatica', 'department_code': 'DMI',
    'course': 'Informatica magistrale (LM-18)', 'course_code': 'LM-18',
    'degree_type': 'LM-18',
}


def path(**changes):
    values = dict(university='Università di Catania', university_code='',
                  department='Dipartimento di Matematica e Informatica', department_code='',
                  course='Informatica magistrale (LM-18)', course_code='')
    values.update(changes)
    return SimpleNamespace(**values)


def test_manual_name_is_recognized_inside_matching_department(monkeypatch):
    monkeypatch.setattr(catalog, 'course_options', lambda db: [KNOWN])
    assert catalog.resolve(None, path()) == KNOWN


def test_similar_name_or_other_university_never_auto_approves(monkeypatch):
    monkeypatch.setattr(catalog, 'course_options', lambda db: [KNOWN])
    assert catalog.resolve(None, path(course='Informatica magistrale applicata')) is None
    assert catalog.resolve(None, path(university='Università di Palermo',
                                      university_code='', course_code='LM-18')) is None


def test_multiple_exact_catalog_codes_need_admin_review(monkeypatch):
    second = {**KNOWN, 'course_code': 'LM-99'}
    monkeypatch.setattr(catalog, 'course_options', lambda db: [KNOWN, second])
    assert catalog.resolve(None, path()) is None
