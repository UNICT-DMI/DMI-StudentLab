import json
import sys

from pathlib import Path

from sqlalchemy.orm import Session


BASE_DIR = Path(
    __file__,
).resolve().parent.parent

sys.path.insert(
    0,
    str(
        BASE_DIR,
    ),
)


from core.database import SessionLocal


from models.user import (
    User,
)

from models.subject import (
    AcademicTeacher,
    Subject,
    SubjectOffering,
    UserSubject,
)

from models.teacher_assignment import (
    TeacherAssignment,
)

from models.user_report import (
    UserReport,
)

from models.profile_error_report import (
    ProfileErrorReport,
)

from models.account_deletion_request import (
    AccountDeletionRequest,
)

from models.group import (
    StudyGroup,
    GroupMember,
    GroupJoinRequest,
)

from models.material import (
    GroupMaterial,
)

from models.group_ownership_transfer import (
    GroupOwnershipTransfer,
)

from models.notification import (
    Notification,
)

from models.group_report import (
    GroupReport,
)

from models.group_content_report import (
    GroupContentReport,
)

from models.user_policy_acceptance import (
    UserPolicyAcceptance,
)

from models.material_publication_request import (
    MaterialPublicationRequest,
)

from models.public_material import (
    PublicMaterial,

)


CATALOG_ROOT = (
    BASE_DIR
    / "data"
)


def normalize_text(
    value,
):
    if value is None:
        return None

    value = str(
        value,
    ).strip()

    if not value:
        return None

    return value


def iter_catalog_paths():
    if not CATALOG_ROOT.exists():
        raise FileNotFoundError(
            f"Directory cataloghi non trovata: {CATALOG_ROOT}"
        )

    paths = []

    for path in CATALOG_ROOT.rglob(
        "*.json",
    ):
        relative_parts = [
            part.lower()
            for part in path.relative_to(
                CATALOG_ROOT,
            ).parts
        ]

        if "question" in relative_parts:
            continue

        paths.append(
            path,
        )

    paths.sort()

    return paths


def load_catalog(
    path: Path,
):
    with open(
        path,
        "r",
        encoding="utf-8",
    ) as file:
        catalog = json.load(
            file,
        )

    if not isinstance(
        catalog,
        dict,
    ):
        return None

    universities = catalog.get(
        "universities",
    )

    if not isinstance(
        universities,
        list,
    ):
        return None

    return catalog


def get_or_create_teacher(
    db: Session,
    name: str,
):
    normalized_name = (
        normalize_text(
            name,
        )
    )

    if normalized_name is None:
        return None

    teacher = (
        db.query(
            AcademicTeacher,
        )
        .filter(
            AcademicTeacher.name
            ==
            normalized_name,
        )
        .first()
    )

    if teacher is not None:
        if not teacher.is_active:
            teacher.is_active = True

        return teacher

    teacher = AcademicTeacher(
        name=normalized_name,
        is_active=True,
    )

    db.add(
        teacher,
    )

    db.flush()

    return teacher


def get_or_create_subject(
    db: Session,
    university,
    department,
    course,
    subject_data,
):
    code = normalize_text(
        subject_data.get(
            "code",
        ),
    )

    name = normalize_text(
        subject_data.get(
            "name",
        ),
    )

    if name is None:
        raise ValueError(
            "Materia senza nome.",
        )

    university_name = (
        normalize_text(
            university.get(
                "name",
            ),
        )
    )

    university_code = (
        normalize_text(
            university.get(
                "code",
            ),
        )
    )

    department_name = (
        normalize_text(
            department.get(
                "name",
            ),
        )
    )

    department_code = (
        normalize_text(
            department.get(
                "code",
            ),
        )
    )

    course_name = (
        normalize_text(
            course.get(
                "name",
            ),
        )
    )

    course_code = (
        normalize_text(
            course.get(
                "code",
            ),
        )
    )

    degree_type = (
        normalize_text(
            course.get(
                "degree_type",
            ),
        )
    )

    study_year = (
        subject_data.get(
            "study_year",
        )
    )

    if university_name is None:
        raise ValueError(
            "Università senza nome.",
        )

    if university_code is None:
        raise ValueError(
            "Università senza codice.",
        )

    if department_name is None:
        raise ValueError(
            "Dipartimento senza nome.",
        )

    if course_name is None:
        raise ValueError(
            "Corso senza nome.",
        )

    subject = None

    if (
        code is not None
        and department_code is not None
        and course_code is not None
    ):
        subject = (
            db.query(
                Subject,
            )
            .filter(
                Subject.university_code
                ==
                university_code,
                Subject.department_code
                ==
                department_code,
                Subject.course_code
                ==
                course_code,
                Subject.code
                ==
                code,
            )
            .first()
        )

    if (
        subject is None
        and code is not None
        and course_code is not None
    ):
        subject = (
            db.query(
                Subject,
            )
            .filter(
                Subject.university_code
                ==
                university_code,
                Subject.course_code
                ==
                course_code,
                Subject.code
                ==
                code,
            )
            .first()
        )

    if (
        subject is None
        and code is not None
    ):
        subject = (
            db.query(
                Subject,
            )
            .filter(
                Subject.university_code
                ==
                university_code,
                Subject.code
                ==
                code,
            )
            .first()
        )

    if subject is None:
        fallback_query = (
            db.query(
                Subject,
            )
            .filter(
                Subject.university_code
                ==
                university_code,
                Subject.name
                ==
                name,
            )
        )

        if course_code is not None:
            fallback_query = (
                fallback_query
                .filter(
                    Subject.course_code
                    ==
                    course_code,
                )
            )
        else:
            fallback_query = (
                fallback_query
                .filter(
                    Subject.course
                    ==
                    course_name,
                )
            )

        subject = (
            fallback_query
            .first()
        )

    if subject is None:
        subject = Subject(
            code=code,
            name=name,
            university=university_name,
            university_code=university_code,
            department=department_name,
            department_code=department_code,
            course=course_name,
            course_code=course_code,
            degree_type=degree_type,
            study_year=study_year,
            is_active=True,
        )

        db.add(
            subject,
        )

        db.flush()

        return subject

    subject.code = (
        code
    )

    subject.name = (
        name
    )

    subject.university = (
        university_name
    )

    subject.university_code = (
        university_code
    )

    subject.department = (
        department_name
    )

    subject.department_code = (
        department_code
    )

    subject.course = (
        course_name
    )

    subject.course_code = (
        course_code
    )

    subject.degree_type = (
        degree_type
    )

    subject.study_year = (
        study_year
    )

    subject.is_active = True

    return subject


def get_or_create_offering(
    db: Session,
    subject: Subject,
    offering_data,
):
    module = normalize_text(
        offering_data.get(
            "module",
        ),
    )

    channel = normalize_text(
        offering_data.get(
            "channel",
        ),
    )

    academic_year = normalize_text(
        offering_data.get(
            "academic_year",
        ),
    )

    source_url = normalize_text(
        offering_data.get(
            "source_url",
        ),
    )

    query = (
        db.query(
            SubjectOffering,
        )
        .filter(
            SubjectOffering.subject_id
            ==
            subject.id,
        )
    )

    if module is None:
        query = query.filter(
            SubjectOffering.module
            .is_(
                None,
            ),
        )
    else:
        query = query.filter(
            SubjectOffering.module
            ==
            module,
        )

    if channel is None:
        query = query.filter(
            SubjectOffering.channel
            .is_(
                None,
            ),
        )
    else:
        query = query.filter(
            SubjectOffering.channel
            ==
            channel,
        )

    if academic_year is None:
        query = query.filter(
            SubjectOffering.academic_year
            .is_(
                None,
            ),
        )
    else:
        query = query.filter(
            SubjectOffering.academic_year
            ==
            academic_year,
        )

    offering = (
        query.first()
    )

    if offering is None:
        offering = SubjectOffering(
            subject_id=subject.id,
            module=module,
            channel=channel,
            academic_year=academic_year,
            source_url=source_url,
            is_active=True,
        )

        db.add(
            offering,
        )

        db.flush()
    else:
        offering.module = (
            module
        )

        offering.channel = (
            channel
        )

        offering.academic_year = (
            academic_year
        )

        offering.source_url = (
            source_url
        )

        offering.is_active = True

    return offering


def sync_offering_teachers(
    db: Session,
    offering: SubjectOffering,
    teacher_names,
):
    normalized_names = []

    for teacher_name in (
        teacher_names
        or []
    ):
        normalized_name = (
            normalize_text(
                teacher_name,
            )
        )

        if normalized_name is None:
            continue

        if (
            normalized_name
            not in normalized_names
        ):
            normalized_names.append(
                normalized_name,
            )

    desired_teachers = []

    for teacher_name in normalized_names:
        teacher = (
            get_or_create_teacher(
                db,
                teacher_name,
            )
        )

        if teacher is None:
            continue

        desired_teachers.append(
            teacher,
        )

    current_ids = {
        teacher.id
        for teacher in offering.teachers
    }

    desired_ids = {
        teacher.id
        for teacher in desired_teachers
    }

    added_count = len(
        desired_ids
        -
        current_ids,
    )

    removed_count = len(
        current_ids
        -
        desired_ids,
    )

    offering.teachers = (
        desired_teachers
    )

    return {
        "added":
            added_count,

        "removed":
            removed_count,
    }


def import_catalog_data(
    db: Session,
    catalog,
):
    universities = catalog.get(
        "universities",
        [],
    )

    subject_count = 0

    offering_count = 0

    teacher_links_added = 0

    teacher_links_removed = 0

    for university in universities:
        if not isinstance(
            university,
            dict,
        ):
            continue

        university_name = (
            normalize_text(
                university.get(
                    "name",
                ),
            )
        )

        university_code = (
            normalize_text(
                university.get(
                    "code",
                ),
            )
        )

        if university_name is None:
            continue

        if university_code is None:
            continue

        university[
            "name"
        ] = university_name

        university[
            "code"
        ] = university_code

        departments = (
            university.get(
                "departments",
                [],
            )
        )

        if not isinstance(
            departments,
            list,
        ):
            continue

        for department in departments:
            if not isinstance(
                department,
                dict,
            ):
                continue

            department_name = (
                normalize_text(
                    department.get(
                        "name",
                    ),
                )
            )

            department_code = (
                normalize_text(
                    department.get(
                        "code",
                    ),
                )
            )

            if department_name is None:
                continue

            department[
                "name"
            ] = department_name

            department[
                "code"
            ] = department_code

            courses = (
                department.get(
                    "courses",
                    [],
                )
            )

            if not isinstance(
                courses,
                list,
            ):
                continue

            for course in courses:
                if not isinstance(
                    course,
                    dict,
                ):
                    continue

                course_name = (
                    normalize_text(
                        course.get(
                            "name",
                        ),
                    )
                )

                course_code = (
                    normalize_text(
                        course.get(
                            "code",
                        ),
                    )
                )

                degree_type = (
                    normalize_text(
                        course.get(
                            "degree_type",
                        ),
                    )
                )

                if course_name is None:
                    continue

                course[
                    "name"
                ] = course_name

                course[
                    "code"
                ] = course_code

                course[
                    "degree_type"
                ] = degree_type

                subjects = (
                    course.get(
                        "subjects",
                        [],
                    )
                )

                if not isinstance(
                    subjects,
                    list,
                ):
                    continue

                for subject_data in subjects:
                    if not isinstance(
                        subject_data,
                        dict,
                    ):
                        continue

                    subject = (
                        get_or_create_subject(
                            db,
                            university,
                            department,
                            course,
                            subject_data,
                        )
                    )

                    subject_count += 1

                    offerings = (
                        subject_data.get(
                            "offerings",
                            [],
                        )
                    )

                    if not isinstance(
                        offerings,
                        list,
                    ):
                        continue

                    for offering_data in offerings:
                        if not isinstance(
                            offering_data,
                            dict,
                        ):
                            continue

                        offering = (
                            get_or_create_offering(
                                db,
                                subject,
                                offering_data,
                            )
                        )

                        offering_count += 1

                        result = (
                            sync_offering_teachers(
                                db,
                                offering,
                                offering_data.get(
                                    "teachers",
                                    [],
                                ),
                            )
                        )

                        teacher_links_added += (
                            result[
                                "added"
                            ]
                        )

                        teacher_links_removed += (
                            result[
                                "removed"
                            ]
                        )

    return {
        "subjects":
            subject_count,

        "offerings":
            offering_count,

        "teacher_links_added":
            teacher_links_added,

        "teacher_links_removed":
            teacher_links_removed,
    }


def import_catalogs(
    db: Session,
):
    catalog_paths = (
        iter_catalog_paths()
    )

    total_subjects = 0

    total_offerings = 0

    total_teacher_links_added = 0

    total_teacher_links_removed = 0

    imported_files = []

    skipped_files = []

    for catalog_path in catalog_paths:
        catalog = (
            load_catalog(
                catalog_path,
            )
        )

        if catalog is None:
            skipped_files.append(
                str(
                    catalog_path.relative_to(
                        BASE_DIR,
                    ),
                )
            )

            continue

        result = (
            import_catalog_data(
                db,
                catalog,
            )
        )

        total_subjects += (
            result[
                "subjects"
            ]
        )

        total_offerings += (
            result[
                "offerings"
            ]
        )

        total_teacher_links_added += (
            result[
                "teacher_links_added"
            ]
        )

        total_teacher_links_removed += (
            result[
                "teacher_links_removed"
            ]
        )

        imported_files.append(
            str(
                catalog_path.relative_to(
                    BASE_DIR,
                ),
            )
        )

    db.commit()

    return {
        "catalog_files":
            len(
                imported_files,
            ),

        "subjects":
            total_subjects,

        "offerings":
            total_offerings,

        "teacher_links_added":
            total_teacher_links_added,

        "teacher_links_removed":
            total_teacher_links_removed,

        "imported_files":
            imported_files,

        "skipped_files":
            skipped_files,
    }


def main():
    db = SessionLocal()

    try:
        result = import_catalogs(
            db,
        )

        print(
            json.dumps(
                result,
                ensure_ascii=False,
                indent=2,
            )
        )
    except Exception:
        db.rollback()

        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()