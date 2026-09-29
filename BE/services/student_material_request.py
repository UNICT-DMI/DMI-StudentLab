from datetime import datetime, timezone

from sqlalchemy.orm import Session

from models.material_share import MaterialShare
from models.student_material_request import StudentMaterialRequest
from models.subject import Subject
from models.user import User
from schemas.student_material_request import StudentMaterialRequestCreate, StudentMaterialRequestResolve
from services.notification import create_notification


def utc_now():
    return datetime.now(timezone.utc)


def create_request(db: Session, requester: User, data: StudentMaterialRequestCreate):
    if data.recipient_user_id == requester.id:
        raise ValueError("Non puoi richiedere un materiale a te stesso.")

    recipient = db.query(User).filter(User.id == data.recipient_user_id, User.is_active.is_(True)).first()
    if recipient is None:
        raise ValueError("Studente destinatario non trovato.")
    if getattr(recipient, "role", None) != "student":
        raise ValueError("Il destinatario deve essere uno studente.")

    subject = None
    if data.subject_id is not None:
        subject = db.query(Subject).filter(Subject.id == data.subject_id, Subject.is_active.is_(True)).first()
        if subject is None:
            raise ValueError("Materia non trovata.")

    duplicate = (
        db.query(StudentMaterialRequest)
        .filter(
            StudentMaterialRequest.requester_user_id == requester.id,
            StudentMaterialRequest.recipient_user_id == recipient.id,
            StudentMaterialRequest.subject_id == data.subject_id,
            StudentMaterialRequest.status == "pending",
        )
        .first()
    )
    if duplicate is not None:
        raise ValueError("Hai già una richiesta in attesa verso questo studente per la stessa materia.")

    record = StudentMaterialRequest(
        requester_user_id=requester.id,
        recipient_user_id=recipient.id,
        subject_id=data.subject_id,
        topic=data.topic.strip() if data.topic else None,
        message=data.message.strip(),
        status="pending",
    )
    db.add(record)
    db.flush()

    subject_label = subject.name if subject is not None else "un materiale"
    create_notification(
        db,
        user_id=recipient.id,
        notification_type="student_material_request",
        title="Nuova richiesta di materiale",
        message=f"{requester.first_name} {requester.last_name} ti ha richiesto materiale per {subject_label}.",
        actor_user_id=requester.id,
        resource_type="student_material_request",
        resource_id=record.id,
        action_type="student_material_request",
        action_resource_id=record.id,
        action_status="pending",
        commit=False,
    )
    db.commit()
    db.refresh(record)
    return record


def cancel_request(db: Session, requester: User, request_id: int):
    record = (
        db.query(StudentMaterialRequest)
        .filter(
            StudentMaterialRequest.id == request_id,
            StudentMaterialRequest.requester_user_id == requester.id,
        )
        .first()
    )
    if record is None:
        raise ValueError("Richiesta non trovata.")
    if record.status != "pending":
        raise ValueError("Puoi annullare solo una richiesta ancora in attesa.")

    record.status = "cancelled"
    record.resolved_at = utc_now()
    record.updated_at = utc_now()
    create_notification(
        db,
        user_id=record.recipient_user_id,
        notification_type="student_material_request_cancelled",
        title="Richiesta materiale annullata",
        message="Lo studente ha annullato una richiesta di materiale.",
        actor_user_id=requester.id,
        resource_type="student_material_request",
        resource_id=record.id,
        action_type=None,
        action_resource_id=None,
        action_status="none",
        commit=False,
    )
    db.commit()
    db.refresh(record)
    return record


def resolve_request(db: Session, recipient: User, request_id: int, data: StudentMaterialRequestResolve):
    record = (
        db.query(StudentMaterialRequest)
        .filter(
            StudentMaterialRequest.id == request_id,
            StudentMaterialRequest.recipient_user_id == recipient.id,
        )
        .first()
    )
    if record is None:
        raise ValueError("Richiesta non trovata.")
    if record.status != "pending":
        return record

    if data.action == "fulfilled":
        if data.fulfilled_share_id is None:
            raise ValueError("Condividi prima il materiale richiesto.")
        share = (
            db.query(MaterialShare)
            .filter(
                MaterialShare.id == data.fulfilled_share_id,
                MaterialShare.sender_user_id == recipient.id,
                MaterialShare.recipient_user_id == record.requester_user_id,
            )
            .first()
        )
        if share is None:
            raise ValueError("La condivisione indicata non corrisponde a questa richiesta.")
        record.status = "fulfilled"
        record.fulfilled_share_id = share.id
        notification_message = "Uno studente ha condiviso il materiale che avevi richiesto."
    else:
        record.status = "declined"
        notification_message = "Lo studente ha indicato di non poter soddisfare la tua richiesta di materiale."

    record.resolved_at = utc_now()
    record.updated_at = utc_now()
    create_notification(
        db,
        user_id=record.requester_user_id,
        notification_type="student_material_request_resolved",
        title="Richiesta materiale aggiornata",
        message=notification_message,
        actor_user_id=recipient.id,
        resource_type="student_material_request",
        resource_id=record.id,
        action_type=None,
        action_resource_id=None,
        action_status="none",
        commit=False,
    )
    db.commit()
    db.refresh(record)
    return record
