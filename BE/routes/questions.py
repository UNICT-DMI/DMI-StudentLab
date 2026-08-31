import json

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    UploadFile,
    status,
)

from sqlalchemy import func
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user

from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User

from schemas.question import (
    QuestionCreate,
    QuestionResponse,
    QuestionUpdate,
)

from services.question_service import (
    create_question,
    delete_question,
    get_question,
    get_questions_for_management,
    hide_question,
    import_questions_from_json,
    restore_question,
    set_question_active_status,
    update_question,
)


router = APIRouter(
    prefix="/questions",
    tags=[
        "questions",
    ],
)


MAX_JSON_IMPORT_SIZE = (
    10
    * 1024
    * 1024
)


def _normalize_required_path_value(
    value: str,
    field_name: str,
) -> str:
    normalized = value.strip()

    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Il campo {field_name} è obbligatorio."
            ),
        )

    return normalized


def _normalize_question_context(
    department: str,
    course: str,
    subject: str,
) -> tuple[
    str,
    str,
    str,
]:
    return (
        _normalize_required_path_value(
            department,
            "dipartimento",
        ),
        _normalize_required_path_value(
            course,
            "corso",
        ),
        _normalize_required_path_value(
            subject,
            "materia",
        ),
    )


def _get_subject(
    db: Session,
    department: str,
    course: str,
    subject: str,
) -> Subject | None:
    return (
        db.query(
            Subject
        )
        .filter(
            func.lower(
                Subject.department_code
            ) == department.strip().lower(),
            func.lower(
                Subject.course_code
            ) == course.strip().lower(),
            func.lower(
                Subject.name
            ) == subject.strip().lower(),
            Subject.is_active.is_(True),
        )
        .first()
    )


def _require_question_manager(
    db: Session,
    current_user: User,
    department: str,
    course: str,
    subject: str,
) -> Subject:
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    subject_record = _get_subject(
        db,
        department,
        course,
        subject,
    )

    if subject_record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Materia non trovata.",
        )

    if current_user.role in {
        "admin",
        "creator",
    }:
        return subject_record

    if current_user.role != "teacher":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Non puoi gestire le domande dei quiz."
            ),
        )

    if (
        current_user.teacher_verification_status
        != "verified"
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Il profilo docente non è verificato."
            ),
        )

    assignment = (
        db.query(
            TeacherAssignment
        )
        .filter(
            TeacherAssignment.user_id
            == current_user.id,
            TeacherAssignment.subject_id
            == subject_record.id,
            TeacherAssignment.verification_status
            == "verified",
            TeacherAssignment.is_current.is_(
                True
            ),
        )
        .first()
    )

    if assignment is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Non sei autorizzato a gestire i quiz di questa materia."
            ),
        )

    return subject_record


def _service_error(
    exception: ValueError,
):
    message = str(
        exception
    ).strip()

    if not message:
        message = (
            "Non è stato possibile completare l'operazione."
        )

    lowered_message = (
        message.casefold()
    )

    if (
        "non trovata"
        in lowered_message
        or "non trovato"
        in lowered_message
    ):
        status_code = (
            status.HTTP_404_NOT_FOUND
        )

    elif (
        "già presente"
        in lowered_message
        or "identica"
        in lowered_message
    ):
        status_code = (
            status.HTTP_409_CONFLICT
        )

    else:
        status_code = (
            status.HTTP_400_BAD_REQUEST
        )

    raise HTTPException(
        status_code=status_code,
        detail=message,
    ) from exception


@router.get(
    "/{department}/{course}/{subject}",
)
def api_manage_questions(
    department: str,
    course: str,
    subject: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        questions = (
            get_questions_for_management(
                department,
                course,
                subject,
            )
        )

    except ValueError as exception:
        _service_error(
            exception
        )

    return {
        "department":
            department,
        "course":
            course,
        "subject":
            subject,
        "questions":
            questions,
    }


@router.get(
    "/{department}/{course}/{subject}/{question_id}",
)
def api_manage_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        question = get_question(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
            include_hidden=True,
        )

    except ValueError as exception:
        _service_error(
            exception
        )

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Domanda non trovata.",
        )

    return question


@router.post(
    "/{department}/{course}/{subject}",
    response_model=QuestionResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_question(
    department: str,
    course: str,
    subject: str,
    request: QuestionCreate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        return create_question(
            department=department,
            course=course,
            subject=subject,
            data=request,
        )

    except ValueError as exception:
        _service_error(
            exception
        )


@router.patch(
    "/{department}/{course}/{subject}/{question_id}",
    response_model=QuestionResponse,
)
def api_update_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    request: QuestionUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        return update_question(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
            data=request,
        )

    except ValueError as exception:
        _service_error(
            exception
        )


@router.post(
    "/{department}/{course}/{subject}/{question_id}/hide",
    response_model=QuestionResponse,
)
def api_hide_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        return hide_question(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
        )

    except ValueError as exception:
        _service_error(
            exception
        )


@router.post(
    "/{department}/{course}/{subject}/{question_id}/restore",
    response_model=QuestionResponse,
)
def api_restore_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        return restore_question(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
        )

    except ValueError as exception:
        _service_error(
            exception
        )


@router.post(
    "/{department}/{course}/{subject}/{question_id}/activate",
    response_model=QuestionResponse,
)
def api_activate_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        return set_question_active_status(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
            is_active=True,
        )

    except ValueError as exception:
        _service_error(
            exception
        )


@router.post(
    "/{department}/{course}/{subject}/{question_id}/deactivate",
    response_model=QuestionResponse,
)
def api_deactivate_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        return set_question_active_status(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
            is_active=False,
        )

    except ValueError as exception:
        _service_error(
            exception
        )


@router.delete(
    "/{department}/{course}/{subject}/{question_id}",
)
def api_delete_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    question_id = (
        _normalize_required_path_value(
            question_id,
            "domanda",
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    try:
        delete_question(
            department=department,
            course=course,
            subject=subject,
            question_id=question_id,
        )

    except ValueError as exception:
        _service_error(
            exception
        )

    return {
        "success":
            True,
        "message":
            "Domanda eliminata.",
    }


@router.post(
    "/{department}/{course}/{subject}/import",
)
async def api_import_questions(
    department: str,
    course: str,
    subject: str,
    file: UploadFile = File(
        ...
    ),
    skip_duplicates: bool = Query(
        default=True
    ),
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department, course, subject = (
        _normalize_question_context(
            department,
            course,
            subject,
        )
    )

    _require_question_manager(
        db,
        current_user,
        department,
        course,
        subject,
    )

    filename = (
        file.filename
        or ""
    ).strip()

    if not filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Seleziona un file JSON da importare."
            ),
        )

    if not filename.casefold().endswith(
        ".json"
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Il file deve essere in formato JSON."
            ),
        )

    try:
        content = await file.read(
            MAX_JSON_IMPORT_SIZE
            + 1
        )

    finally:
        await file.close()

    if (
        len(
            content
        )
        > MAX_JSON_IMPORT_SIZE
    ):
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                "Il file JSON supera la dimensione massima consentita di 10 MB."
            ),
        )

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Il file JSON è vuoto."
            ),
        )

    try:
        decoded = content.decode(
            "utf-8-sig"
        )

    except UnicodeDecodeError as exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Il file JSON deve utilizzare la codifica UTF-8."
            ),
        ) from exception

    try:
        raw_questions = json.loads(
            decoded
        )

    except json.JSONDecodeError as exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Il contenuto del file JSON non è valido."
            ),
        ) from exception

    if not isinstance(
        raw_questions,
        list,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Il file JSON deve contenere una lista di domande."
            ),
        )

    if not raw_questions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Il file JSON non contiene domande da importare."
            ),
        )

    try:
        return import_questions_from_json(
            department=department,
            course=course,
            subject=subject,
            raw_questions=raw_questions,
            skip_duplicates=skip_duplicates,
        )

    except ValueError as exception:
        _service_error(
            exception
        )