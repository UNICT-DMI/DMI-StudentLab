
from models.subject import Subject, UserSubject


def column_names(model):
    return {column.name for column in model.__table__.columns}


def test_user_subject_has_grade_verification_fields():
    columns = column_names(UserSubject)
    assert {
        "grade",
        "grade_status",
        "grade_verified_by",
        "grade_verified_at",
    }.issubset(columns)


def test_subject_has_stable_catalog_identity_fields():
    columns = column_names(Subject)
    assert {
        "code",
        "university_code",
        "department_code",
        "course_code",
        "study_year",
        "is_active",
    }.issubset(columns)


def test_grade_is_nullable():
    assert UserSubject.__table__.columns["grade"].nullable is True


def test_grade_status_is_not_nullable():
    assert UserSubject.__table__.columns["grade_status"].nullable is False
