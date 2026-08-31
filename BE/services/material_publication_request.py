from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.exc import (
    IntegrityError,
)

from sqlalchemy.orm import (
    Session,
)

from models.material_publication_request import (
    MaterialPublicationRequest,
)

from models.public_material import (
    PublicMaterial,
)

from models.material_storage_event import (
    MaterialStorageEvent,
)

from models.subject import (
    Subject,
)

from models.user import (
    User,
)

from schemas.material_publication_request import (
    MaterialPublicationApproveRequest,
    MaterialPublicationCompleteRequest,
    MaterialPublicationRejectRequest,
    MaterialDuplicateReviewRequest,
)

from services.public_material import (
    ensure_public_material_not_duplicate,
    get_public_material_by_id,
    normalize_public_material_hash,
    replace_public_material_file,
)

from services.private_blob import (
    delete_private_blob_sync,
)


def _record_storage_event(
    db: Session,
    *,
    publication_request: MaterialPublicationRequest,
    action: str,
    actor_id: int | None,
    blob_path: str | None,
    reason: str | None = None,
):
    event = MaterialStorageEvent(
        source="publication_request",
        material_id=publication_request.id,
        action=action,
        blob_path=blob_path,
        original_name=publication_request.original_name,
        size=publication_request.size,
        actor_id=actor_id,
        reason=reason,
    )
    db.add(event)


def _delete_unused_publication_blob(
    db: Session,
    *,
    publication_request: MaterialPublicationRequest,
    actor_id: int | None,
    action: str,
    reason: str,
):
    stored_name = publication_request.stored_name
    try:
        deleted = delete_private_blob_sync(stored_name)
        _record_storage_event(
            db,
            publication_request=publication_request,
            action=action if deleted else "blob_already_missing",
            actor_id=actor_id,
            blob_path=stored_name,
            reason=reason,
        )
        db.commit()
        return deleted
    except Exception as exception:
        db.rollback()
        try:
            _record_storage_event(
                db,
                publication_request=publication_request,
                action="blob_delete_failed",
                actor_id=actor_id,
                blob_path=stored_name,
                reason=str(exception),
            )
            db.commit()
        except Exception:
            db.rollback()
        return False


MAX_PUBLIC_MATERIAL_SIZE = (
    250
    * 1024
    * 1024
)


ALLOWED_PUBLIC_MATERIAL_MIME_TYPES = {
    "application/pdf",
    "text/plain",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


ALLOWED_PUBLICATION_REQUEST_TYPES = {
    "new_material",
    "update_candidate",
}


ALLOWED_COMPARISON_STATUSES = {
    "not_required",
    "pending",
    "same_material",
    "candidate_update",
    "different_material",
}


ALLOWED_APPROVED_ACTIONS = {
    "publish_new",
    "update_existing",
    "keep_existing",
    "publish_separate",
}


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def validate_publication_material_size(
    size: int,
):
    if size <= 0:
        raise ValueError(
            "Dimensione del file non valida.",
        )

    if size > MAX_PUBLIC_MATERIAL_SIZE:
        raise ValueError(
            "Il file supera la dimensione massima consentita.",
        )


def validate_publication_material_mime_type(
    mime_type: str,
):
    normalized_mime_type = (
        mime_type
        .split(
            ";",
            1,
        )[0]
        .strip()
        .lower()
    )

    if (
        normalized_mime_type
        not in
        ALLOWED_PUBLIC_MATERIAL_MIME_TYPES
    ):
        raise ValueError(
            "Tipo di file non supportato.",
        )


def normalize_optional_text(
    value: str | None,
) -> str | None:
    if value is None:
        return None

    normalized = (
        value
        .strip()
    )

    return (
        normalized
        if normalized
        else None
    )


def normalize_required_text(
    value: str,
    *,
    error_message: str,
) -> str:
    normalized = (
        value
        .strip()
    )

    if not normalized:
        raise ValueError(
            error_message,
        )

    return normalized


def normalize_request_type(
    value: str | None,
) -> str:
    request_type = (
        value
        .strip()
        .lower()
        if value is not None
        else "new_material"
    )

    if (
        request_type not in
        ALLOWED_PUBLICATION_REQUEST_TYPES
    ):
        raise ValueError(
            "Tipo di richiesta non valido.",
        )

    return request_type


def normalize_comparison_status(
    value: str,
) -> str:
    status = (
        value
        .strip()
        .lower()
    )

    if (
        status not in
        ALLOWED_COMPARISON_STATUSES
    ):
        raise ValueError(
            "Stato del confronto non valido.",
        )

    return status


def normalize_approved_action(
    value: str | None,
    *,
    request_type: str,
) -> str:
    if value is None:
        if request_type == "new_material":
            return "publish_new"

        raise ValueError(
            "Seleziona come gestire "
            "il materiale proposto.",
        )

    action = (
        value
        .strip()
        .lower()
    )

    if (
        action not in
        ALLOWED_APPROVED_ACTIONS
    ):
        raise ValueError(
            "Azione di approvazione non valida.",
        )

    return action


def get_publication_request_by_id(
    db: Session,
    request_id: int,
):
    return (
        db.query(
            MaterialPublicationRequest,
        )
        .filter(
            MaterialPublicationRequest.id ==
            request_id,
        )
        .first()
    )


def get_user_publication_requests(
    db: Session,
    user_id: int,
):
    return (
        db.query(
            MaterialPublicationRequest,
        )
        .filter(
            MaterialPublicationRequest.user_id ==
            user_id,
        )
        .order_by(
            MaterialPublicationRequest.updated_at.desc(),
            MaterialPublicationRequest.created_at.desc(),
        )
        .all()
    )


def get_pending_publication_requests(
    db: Session,
):
    return (
        db.query(
            MaterialPublicationRequest,
        )
        .filter(
            MaterialPublicationRequest.status ==
            "pending",
        )
        .order_by(
            MaterialPublicationRequest.created_at.asc(),
        )
        .all()
    )


def get_publication_requests(
    db: Session,
    status: str | None = None,
):
    query = db.query(
        MaterialPublicationRequest,
    )

    if status is not None:
        normalized_status = (
            status
            .strip()
            .lower()
        )

        if normalized_status not in {
            "pending",
            "approved",
            "rejected",
        }:
            raise ValueError(
                "Stato della richiesta non valido.",
            )

        query = query.filter(
            MaterialPublicationRequest.status ==
            normalized_status,
        )

    return (
        query
        .order_by(
            MaterialPublicationRequest.updated_at.desc(),
            MaterialPublicationRequest.created_at.desc(),
        )
        .all()
    )


def get_subject_for_publication(
    db: Session,
    subject_id: int,
):
    return (
        db.query(
            Subject,
        )
        .filter(
            Subject.id ==
            subject_id,
            Subject.is_active.is_(
                True,
            ),
        )
        .first()
    )


def get_target_public_material(
    db: Session,
    *,
    target_material_id: int | None,
    subject_id: int,
):
    if target_material_id is None:
        return None

    material = (
        get_public_material_by_id(
            db,
            target_material_id,
        )
    )

    if material is None:
        raise ValueError(
            "Materiale StudentLab di riferimento "
            "non trovato.",
        )

    if (
        material.subject_id !=
        subject_id
    ):
        raise ValueError(
            "Il materiale di riferimento "
            "appartiene a un'altra materia.",
        )

    if (
        material.status ==
        "removed"
    ):
        raise ValueError(
            "Il materiale di riferimento "
            "è stato rimosso.",
        )

    return material


def find_exact_public_material_duplicate(
    db: Session,
    *,
    subject_id: int,
    file_hash: str,
):
    normalized_hash = (
        normalize_public_material_hash(
            file_hash,
        )
    )

    return (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.subject_id ==
            subject_id,
            PublicMaterial.file_hash ==
            normalized_hash,
            PublicMaterial.status !=
            "removed",
        )
        .order_by(
            PublicMaterial.updated_at.desc(),
            PublicMaterial.id.asc(),
        )
        .first()
    )


def find_possible_public_material_duplicate(
    db: Session,
    *,
    subject_id: int,
    original_name: str,
    size: int,
):
    normalized_name = (
        original_name
        .strip()
        .lower()
    )

    materials = (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.subject_id ==
            subject_id,
            PublicMaterial.status !=
            "removed",
        )
        .order_by(
            PublicMaterial.updated_at.desc(),
            PublicMaterial.created_at.desc(),
        )
        .all()
    )

    for material in materials:
        material_name = (
            material.original_name
            .strip()
            .lower()
        )

        if (
            material_name ==
            normalized_name
        ):
            return material

    for material in materials:
        if material.size == size:
            return material

    return None


def find_duplicate_candidate(
    db: Session,
    *,
    subject_id: int,
    original_name: str,
    size: int,
    file_hash: str,
):
    exact_duplicate = (
        find_exact_public_material_duplicate(
            db,
            subject_id=subject_id,
            file_hash=file_hash,
        )
    )

    if exact_duplicate is not None:
        return exact_duplicate

    return (
        find_possible_public_material_duplicate(
            db,
            subject_id=subject_id,
            original_name=original_name,
            size=size,
        )
    )


def create_material_publication_request(
    db: Session,
    *,
    current_user: User,
    data: MaterialPublicationCompleteRequest,
):
    if not current_user.is_active:
        raise PermissionError(
            "Account non attivo.",
        )

    subject = get_subject_for_publication(
        db,
        data.subject_id,
    )

    if subject is None:
        raise ValueError(
            "Materia non trovata.",
        )

    validate_publication_material_size(
        data.size,
    )

    validate_publication_material_mime_type(
        data.mime_type,
    )

    request_type = (
        normalize_request_type(
            getattr(
                data,
                "request_type",
                None,
            ),
        )
    )

    target_public_material_id = (
        getattr(
            data,
            "target_public_material_id",
            None,
        )
    )

    target_material = (
        get_target_public_material(
            db,
            target_material_id=(
                target_public_material_id
            ),
            subject_id=(
                subject.id
            ),
        )
    )

    if (
        request_type ==
        "update_candidate"
        and target_material is None
    ):
        raise ValueError(
            "Seleziona il materiale StudentLab "
            "che potrebbe essere aggiornato.",
        )

    if (
        request_type ==
        "new_material"
    ):
        target_public_material_id = (
            None
        )

    normalized_hash = (
        normalize_public_material_hash(
            data.file_hash,
        )
    )

    duplicate = find_duplicate_candidate(
        db,
        subject_id=subject.id,
        original_name=(
            data.original_name
        ),
        size=data.size,
        file_hash=(
            normalized_hash
        ),
    )

    duplicate_status = (
        "none"
    )

    comparison_status = (
        "not_required"
    )

    possible_duplicate_material_id = (
        None
    )

    if duplicate is not None:
        possible_duplicate_material_id = (
            duplicate.id
        )

        if (
            duplicate.file_hash ==
            normalized_hash
        ):
            duplicate_status = (
                "confirmed"
            )

            comparison_status = (
                "same_material"
            )

        else:
            duplicate_status = (
                "suspected"
            )

            comparison_status = (
                "pending"
            )

    if (
        request_type ==
        "update_candidate"
    ):
        possible_duplicate_material_id = (
            target_material.id
            if target_material is not None
            else possible_duplicate_material_id
        )

        if (
            target_material is not None
            and target_material.file_hash ==
            normalized_hash
        ):
            duplicate_status = (
                "confirmed"
            )
            comparison_status = (
                "same_material"
            )
        else:
            duplicate_status = (
                "suspected"
            )
            comparison_status = (
                "pending"
            )

    title = normalize_required_text(
        data.title,
        error_message=(
            "Titolo del materiale obbligatorio."
        ),
    )

    original_name = (
        normalize_required_text(
            data.original_name,
            error_message=(
                "Nome del file non valido."
            ),
        )
    )

    stored_name = (
        normalize_required_text(
            data.stored_name,
            error_message=(
                "Percorso storage non valido."
            ),
        )
    )

    file_path = (
        normalize_required_text(
            data.file_path,
            error_message=(
                "Percorso file non valido."
            ),
        )
    )

    publication_request = (
        MaterialPublicationRequest(
            user_id=(
                current_user.id
            ),
            subject_id=(
                subject.id
            ),
            university=(
                subject.university
            ),
            university_code=(
                subject.university_code
            ),
            department=(
                subject.department
            ),
            department_code=(
                subject.department_code
            ),
            course=(
                subject.course
            ),
            course_code=(
                subject.course_code
            ),
            request_type=(
                request_type
            ),
            target_public_material_id=(
                target_public_material_id
            ),
            title=(
                title
            ),
            description=(
                normalize_optional_text(
                    data.description
                )
            ),
            original_name=(
                original_name
            ),
            stored_name=(
                stored_name
            ),
            file_path=(
                file_path
            ),
            mime_type=(
                data.mime_type
                .split(
                    ";",
                    1,
                )[0]
                .strip()
                .lower()
            ),
            size=(
                data.size
            ),
            file_hash=(
                normalized_hash
            ),
            status="pending",
            duplicate_status=(
                duplicate_status
            ),
            comparison_status=(
                comparison_status
            ),
            possible_duplicate_material_id=(
                possible_duplicate_material_id
            ),
            reviewed_by=None,
            reviewed_at=None,
            rejection_reason=None,
            admin_note=None,
            approved_action=None,
            approved_public_material_id=None,
            proposed_title=None,
            proposed_description=None,
        )
    )

    try:
        db.add(
            publication_request,
        )

        db.commit()

        db.refresh(
            publication_request,
        )

        return publication_request

    except Exception:
        db.rollback()
        raise


def review_material_duplicate(
    db: Session,
    *,
    publication_request:
        MaterialPublicationRequest,
    current_admin: User,
    data: MaterialDuplicateReviewRequest,
):
    if (
        publication_request.status !=
        "pending"
    ):
        raise ValueError(
            "La richiesta è già stata elaborata.",
        )

    duplicate_status = (
        data.duplicate_status
        .strip()
        .lower()
    )

    if duplicate_status not in {
        "confirmed",
        "not_duplicate",
    }:
        raise ValueError(
            "Stato duplicato non valido.",
        )

    comparison_status = getattr(
        data,
        "comparison_status",
        None,
    )

    if duplicate_status == "confirmed":
        if (
            publication_request.possible_duplicate_material_id
            is None
            and publication_request.target_public_material_id
            is None
        ):
            raise ValueError(
                "Nessun possibile duplicato "
                "associato alla richiesta.",
            )

        publication_request.duplicate_status = (
            "confirmed"
        )

        publication_request.comparison_status = (
            "same_material"
        )

    else:
        publication_request.duplicate_status = (
            "not_duplicate"
        )

        if comparison_status is not None:
            normalized_comparison = (
                normalize_comparison_status(
                    comparison_status,
                )
            )

            if normalized_comparison not in {
                "candidate_update",
                "different_material",
            }:
                raise ValueError(
                    "Per un materiale non identico "
                    "seleziona se è un aggiornamento "
                    "o un materiale differente.",
                )

            publication_request.comparison_status = (
                normalized_comparison
            )

        elif (
            publication_request.request_type ==
            "update_candidate"
        ):
            publication_request.comparison_status = (
                "candidate_update"
            )

        else:
            publication_request.comparison_status = (
                "different_material"
            )

        if (
            publication_request.request_type ==
            "new_material"
            and publication_request.comparison_status ==
            "different_material"
        ):
            publication_request.possible_duplicate_material_id = (
                None
            )

    proposed_title = getattr(
        data,
        "proposed_title",
        None,
    )

    proposed_description = getattr(
        data,
        "proposed_description",
        None,
    )

    publication_request.proposed_title = (
        normalize_optional_text(
            proposed_title
        )
    )

    publication_request.proposed_description = (
        normalize_optional_text(
            proposed_description
        )
    )

    publication_request.reviewed_by = (
        current_admin.id
    )

    publication_request.reviewed_at = (
        utc_now()
    )

    publication_request.admin_note = (
        normalize_optional_text(
            data.admin_note
        )
    )

    try:
        db.commit()

        db.refresh(
            publication_request,
        )

        return publication_request

    except Exception:
        db.rollback()
        raise


def create_public_material_from_request(
    db: Session,
    *,
    publication_request:
        MaterialPublicationRequest,
    current_admin: User,
    action: str,
):
    ensure_public_material_not_duplicate(
        db,
        subject_id=(
            publication_request.subject_id
        ),
        file_hash=(
            publication_request.file_hash
        ),
    )

    approved_at = (
        utc_now()
    )

    title = (
        publication_request.proposed_title
        or publication_request.title
    )

    description = (
        publication_request.proposed_description
        if publication_request.proposed_description
        is not None
        else publication_request.description
    )

    public_material = (
        PublicMaterial(
            subject_id=(
                publication_request.subject_id
            ),
            uploaded_by=(
                publication_request.user_id
            ),
            publication_request_id=(
                publication_request.id
            ),
            university=(
                publication_request.university
            ),
            university_code=(
                publication_request.university_code
            ),
            department=(
                publication_request.department
            ),
            department_code=(
                publication_request.department_code
            ),
            course=(
                publication_request.course
            ),
            course_code=(
                publication_request.course_code
            ),
            title=(
                title
            ),
            description=(
                description
            ),
            original_name=(
                publication_request.original_name
            ),
            stored_name=(
                publication_request.stored_name
            ),
            file_path=(
                publication_request.file_path
            ),
            mime_type=(
                publication_request.mime_type
            ),
            size=(
                publication_request.size
            ),
            file_hash=(
                publication_request.file_hash
            ),
            version=1,
            status="published",
            is_visible=True,
            approved_by=(
                current_admin.id
            ),
            approved_at=(
                approved_at
            ),
            removed_by=None,
            removed_at=None,
            removal_reason=None,
        )
    )

    db.add(
        public_material,
    )

    db.flush()

    publication_request.status = (
        "approved"
    )

    publication_request.approved_action = (
        action
    )

    publication_request.approved_public_material_id = (
        public_material.id
    )

    publication_request.reviewed_by = (
        current_admin.id
    )

    publication_request.reviewed_at = (
        approved_at
    )

    publication_request.rejection_reason = (
        None
    )

    return public_material


def approve_material_publication_request(
    db: Session,
    *,
    publication_request:
        MaterialPublicationRequest,
    current_admin: User,
    data: MaterialPublicationApproveRequest,
):
    if (
        publication_request.status !=
        "pending"
    ):
        raise ValueError(
            "La richiesta è già stata elaborata.",
        )

    existing_public_material = (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.publication_request_id ==
            publication_request.id,
        )
        .first()
    )

    if existing_public_material is not None:
        raise ValueError(
            "La richiesta ha già generato "
            "un materiale pubblico.",
        )

    request_type = (
        normalize_request_type(
            publication_request.request_type
        )
    )

    approved_action = (
        normalize_approved_action(
            getattr(
                data,
                "approved_action",
                None,
            ),
            request_type=(
                request_type
            ),
        )
    )

    publication_request.admin_note = (
        normalize_optional_text(
            data.admin_note
        )
    )

    proposed_title = getattr(
        data,
        "proposed_title",
        None,
    )

    proposed_description = getattr(
        data,
        "proposed_description",
        None,
    )

    if proposed_title is not None:
        publication_request.proposed_title = (
            normalize_optional_text(
                proposed_title
            )
        )

    if proposed_description is not None:
        publication_request.proposed_description = (
            normalize_optional_text(
                proposed_description
            )
        )

    if (
        publication_request.duplicate_status ==
        "confirmed"
        and approved_action !=
        "keep_existing"
    ):
        raise ValueError(
            "Il materiale coincide con "
            "un materiale StudentLab esistente."
        )

    target_material_id = (
        publication_request.target_public_material_id
        or publication_request.possible_duplicate_material_id
    )

    target_material = (
        get_target_public_material(
            db,
            target_material_id=(
                target_material_id
            ),
            subject_id=(
                publication_request.subject_id
            ),
        )
        if target_material_id is not None
        else None
    )

    if (
        approved_action ==
        "publish_new"
    ):
        if (
            request_type !=
            "new_material"
        ):
            raise ValueError(
                "Una proposta di aggiornamento "
                "non può essere approvata "
                "come nuova pubblicazione generica."
            )

        try:
            public_material = (
                create_public_material_from_request(
                    db,
                    publication_request=(
                        publication_request
                    ),
                    current_admin=(
                        current_admin
                    ),
                    action="publish_new",
                )
            )

            db.commit()

            db.refresh(
                publication_request,
            )

            db.refresh(
                public_material,
            )

            return public_material

        except Exception:
            db.rollback()
            raise

    if (
        approved_action ==
        "publish_separate"
    ):
        if (
            publication_request.comparison_status
            not in {
                "different_material",
                "not_required",
            }
        ):
            raise ValueError(
                "Conferma prima che il contenuto "
                "sia un materiale differente."
            )

        try:
            public_material = (
                create_public_material_from_request(
                    db,
                    publication_request=(
                        publication_request
                    ),
                    current_admin=(
                        current_admin
                    ),
                    action="publish_separate",
                )
            )

            db.commit()

            db.refresh(
                publication_request,
            )

            db.refresh(
                public_material,
            )

            return public_material

        except Exception:
            db.rollback()
            raise

    if (
        approved_action ==
        "keep_existing"
    ):
        if target_material is None:
            raise ValueError(
                "Nessun materiale StudentLab "
                "da mantenere."
            )

        publication_request.status = (
            "approved"
        )

        publication_request.approved_action = (
            "keep_existing"
        )

        publication_request.approved_public_material_id = (
            target_material.id
        )

        publication_request.reviewed_by = (
            current_admin.id
        )

        publication_request.reviewed_at = (
            utc_now()
        )

        publication_request.rejection_reason = (
            None
        )

        if (
            publication_request.duplicate_status !=
            "confirmed"
        ):
            publication_request.comparison_status = (
                "candidate_update"
            )

        try:
            db.commit()

            db.refresh(
                publication_request,
            )

            db.refresh(
                target_material,
            )

            _delete_unused_publication_blob(
                db,
                publication_request=publication_request,
                actor_id=current_admin.id,
                action="duplicate_proposal_blob_deleted",
                reason="File proposto non necessario: mantenuto il materiale esistente.",
            )

            return target_material

        except Exception:
            db.rollback()
            raise

    if (
        approved_action ==
        "update_existing"
    ):
        if target_material is None:
            raise ValueError(
                "Nessun materiale StudentLab "
                "da aggiornare."
            )

        if (
            publication_request.comparison_status
            not in {
                "candidate_update",
                "pending",
            }
        ):
            raise ValueError(
                "Il materiale proposto non è "
                "stato classificato come "
                "possibile aggiornamento."
            )

        if (
            target_material.file_hash ==
            publication_request.file_hash
        ):
            raise ValueError(
                "Il file è identico alla versione "
                "già presente su StudentLab."
            )

        title = (
            publication_request.proposed_title
            or publication_request.title
        )

        description = (
            publication_request.proposed_description
            if publication_request.proposed_description
            is not None
            else publication_request.description
        )

        previous_stored_name = (
            target_material.stored_name
        )

        try:
            updated_material = (
                replace_public_material_file(
                    db,
                    material=(
                        target_material
                    ),
                    current_admin=(
                        current_admin
                    ),
                    original_name=(
                        publication_request.original_name
                    ),
                    stored_name=(
                        publication_request.stored_name
                    ),
                    file_path=(
                        publication_request.file_path
                    ),
                    mime_type=(
                        publication_request.mime_type
                    ),
                    size=(
                        publication_request.size
                    ),
                    file_hash=(
                        publication_request.file_hash
                    ),
                    uploaded_by=(
                        publication_request.user_id
                    ),
                    title=(
                        title
                    ),
                    description=(
                        description
                    ),
                )
            )

            publication_request.status = (
                "approved"
            )

            publication_request.approved_action = (
                "update_existing"
            )

            publication_request.approved_public_material_id = (
                updated_material.id
            )

            publication_request.comparison_status = (
                "candidate_update"
            )

            publication_request.reviewed_by = (
                current_admin.id
            )

            publication_request.reviewed_at = (
                utc_now()
            )

            publication_request.rejection_reason = (
                None
            )

            db.commit()

            db.refresh(
                publication_request,
            )

            db.refresh(
                updated_material,
            )

            if (
                previous_stored_name
                and previous_stored_name != updated_material.stored_name
            ):
                try:
                    deleted_old_blob = delete_private_blob_sync(
                        previous_stored_name,
                    )
                    event = MaterialStorageEvent(
                        source="public",
                        material_id=updated_material.id,
                        action=(
                            "replaced_blob_deleted"
                            if deleted_old_blob
                            else "replaced_blob_already_missing"
                        ),
                        blob_path=previous_stored_name,
                        original_name=updated_material.original_name,
                        size=None,
                        actor_id=current_admin.id,
                        reason="Versione precedente sostituita.",
                    )
                    db.add(event)
                    db.commit()
                except Exception:
                    db.rollback()

            return updated_material

        except Exception:
            db.rollback()
            raise

    raise ValueError(
        "Azione di approvazione non valida.",
    )


def reject_material_publication_request(
    db: Session,
    *,
    publication_request:
        MaterialPublicationRequest,
    current_admin: User,
    data: MaterialPublicationRejectRequest,
):
    if (
        publication_request.status !=
        "pending"
    ):
        raise ValueError(
            "La richiesta è già stata elaborata.",
        )

    rejection_reason = (
        normalize_required_text(
            data.rejection_reason,
            error_message=(
                "Inserisci il motivo "
                "del rifiuto."
            ),
        )
    )

    publication_request.status = (
        "rejected"
    )

    publication_request.reviewed_by = (
        current_admin.id
    )

    publication_request.reviewed_at = (
        utc_now()
    )

    publication_request.rejection_reason = (
        rejection_reason
    )

    publication_request.admin_note = (
        normalize_optional_text(
            data.admin_note
        )
    )

    publication_request.approved_action = (
        None
    )

    publication_request.approved_public_material_id = (
        None
    )

    try:
        db.commit()

        db.refresh(
            publication_request,
        )

        _delete_unused_publication_blob(
            db,
            publication_request=publication_request,
            actor_id=current_admin.id,
            action="rejected_blob_deleted",
            reason=rejection_reason,
        )

        db.refresh(
            publication_request,
        )

        return publication_request

    except Exception:
        db.rollback()
        raise