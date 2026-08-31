from sqlalchemy.orm import Session

from models.subject import Subject

from schemas.subject import SubjectCreate


# =============================================================================
# CREA MATERIA
# =============================================================================

def create_subject(
    db: Session,
    data: SubjectCreate,
):
    subject = Subject(
        name=data.name,
        department=data.department,
        course=data.course,
    )

    db.add(subject)

    db.commit()

    db.refresh(subject)

    return subject


# =============================================================================
# TUTTE LE MATERIE
# =============================================================================

def get_subjects(
    db: Session,
):
    return (
        db.query(Subject)
        .order_by(
            Subject.name.asc(),
        )
        .all()
    )


# =============================================================================
# MATERIA PER ID
# =============================================================================

def get_subject_by_id(
    db: Session,
    subject_id: int,
):
    return (
        db.query(Subject)
        .filter(
            Subject.id == subject_id
        )
        .first()
    )


# =============================================================================
# VERIFICA MATERIA ESISTENTE
# =============================================================================

def get_existing_subject(
    db: Session,
    name: str,
    department: str,
    course: str,
):
    return (
        db.query(Subject)
        .filter(
            Subject.name == name,
            Subject.department == department,
            Subject.course == course,
        )
        .first()
    )

def get_subjects_by_course(
    db: Session,
    department: str,
    course: str,
):
    return (
        db.query(Subject)
        .filter(
            Subject.department == department,
            Subject.course == course,
        )
        .order_by(
            Subject.name.asc(),
        )
        .all()
    )