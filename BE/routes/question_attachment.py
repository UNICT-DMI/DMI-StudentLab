from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)

from sqlalchemy import func
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user

from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User

from schemas.question_attachment import (
    QuestionAttachmentCompleteRequest,
    QuestionAttachmentCompleteResponse,
    QuestionAttachmentUploadRequest,
    QuestionAttachmentUploadResponse,
    QuestionAttachmentVerifyRequest,
    QuestionAttachmentVerifyResponse,
)

from services.question_attachment import (
    complete_question_attachment,
    prepare_question_attachment_upload,
    verify_question_attachment_upload,
)

from services.question_service import (
    get_question,
)


router = APIRouter(
    prefix="/question-attachments",
    tags=[
        "question-attachments",
    ],
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
            Subject.is_active.is_(
                True
            ),
        )
        .first()
    )


def _require_attachment_manager(
    db: Session,
    current_user: User,
    department: str,
    course: str,
    subject: str,
) -> Subject:
    subject_record = (
        _get_subject(
            db,
            department,
            course,
            subject,
        )
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
                "Non puoi gestire gli allegati delle domande."
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
                "Non sei autorizzato a gestire questa materia."
            ),
        )

    return subject_record


def _require_existing_question(
    department: str,
    course: str,
    subject: str,
    question_id: str | None,
) -> None:
    if question_id is None:
        return

    question = get_question(
        department=department,
        course=course,
        subject=subject,
        question_id=question_id,
        include_hidden=True,
    )

    if question is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Domanda non trovata.",
        )


def _raise_attachment_error(
    exception: Exception,
):
    if isinstance(
        exception,
        RuntimeError,
    ):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Il servizio di caricamento non è disponibile."
            ),
        ) from exception

    message = str(
        exception
    ).strip()

    lowered = (
        message.casefold()
    )

    if (
        "scaduta"
        in lowered
    ):
        status_code = (
            status.HTTP_401_UNAUTHORIZED
        )

    elif (
        "dimensione massima"
        in lowered
    ):
        status_code = (
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE
        )

    else:
        status_code = (
            status.HTTP_400_BAD_REQUEST
        )

    raise HTTPException(
        status_code=status_code,
        detail=message,
    ) from exception


@router.post(
    "/upload-request",
    response_model=QuestionAttachmentUploadResponse,
)
def api_question_attachment_upload_request(
    request: QuestionAttachmentUploadRequest,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    _require_attachment_manager(
        db,
        current_user,
        request.department,
        request.course,
        request.subject,
    )

    _require_existing_question(
        request.department,
        request.course,
        request.subject,
        request.question_id,
    )

    try:
        return (
            prepare_question_attachment_upload(
                user_id=current_user.id,
                data=request,
            )
        )

    except (
        ValueError,
        RuntimeError,
    ) as exception:
        _raise_attachment_error(
            exception
        )


@router.post(
    "/verify-upload",
    response_model=QuestionAttachmentVerifyResponse,
)
def api_question_attachment_verify_upload(
    request: QuestionAttachmentVerifyRequest,
    current_user: User = Depends(
        get_current_user
    ),
):
    try:
        return (
            verify_question_attachment_upload(
                user_id=current_user.id,
                data=request,
            )
        )

    except (
        ValueError,
        RuntimeError,
    ) as exception:
        _raise_attachment_error(
            exception
        )


@router.post(
    "/complete",
    response_model=QuestionAttachmentCompleteResponse,
)
def api_question_attachment_complete(
    request: QuestionAttachmentCompleteRequest,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    _require_attachment_manager(
        db,
        current_user,
        request.department,
        request.course,
        request.subject,
    )

    try:
        return (
            complete_question_attachment(
                user_id=current_user.id,
                data=request,
            )
        )

    except (
        ValueError,
        RuntimeError,
    ) as exception:
        _raise_attachment_error(
            exception
        )