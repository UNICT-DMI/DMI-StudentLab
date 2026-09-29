import json

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from models.group import GroupMember, StudyGroup
from models.material import GroupMaterial
from models.material_share import MaterialShare
from models.personal_material import PersonalSyncedMaterial
from models.public_material import PublicMaterial
from models.teacher_material import TeacherMaterial
from schemas.material_sync import MaterialSyncItem, MaterialSyncManifestResponse
from services.material_share import process_expired_shares
from services.personal_material import process_personal_retention
from services.teacher_material_assignment import get_accessible_teacher_material_ids
from services.public_material_access import can_read_public_material


def utc_now():
    return datetime.now(timezone.utc)


def _utc(value):
    if value is None:
        return None
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _changed(record,since):
    if since is None:
        return True
    values=[_utc(getattr(record,name,None)) for name in ("updated_at","removed_at","created_at","deleted_at") if getattr(record,name,None) is not None]
    return any(v>_utc(since) for v in values)


def _public(record, allowed):
    active=allowed and record.status=="published" and bool(record.is_visible) and getattr(record,"visibility_state","visible")=="visible" and not getattr(record,"drive_activation_pending",False)
    return MaterialSyncItem(key=f"public:{record.id}",source="public",material_id=record.id,subject_id=(record.subject_id if active else None),version=record.version or 1,status=("active" if active else "removed" if record.status=="removed" else "hidden"),is_active=active,is_visible=active,is_tombstone=not active,original_name=(record.original_name if active else None),university=(record.university if active else None),department=(record.department if active else None),course=(record.course if active else None),subject_name=(getattr(record.subject,"name",None) if active and getattr(record,"subject",None) else None),path_segments=(json.loads(record.catalog_path_json or '[]') if active else []),mime_type=(record.mime_type if active else None),size=(record.size if active else None),file_hash=(record.file_hash if active else None),cloud_policy="persistent",updated_at=_utc(record.updated_at),removed_at=_utc(getattr(record,"removed_at",None)))


def _subject_location(subject):
    return dict(university=subject.university, department=subject.department,
                course=subject.course, subject_name=subject.name) if subject else {}


def _teacher(record,visible):
    active=record.status=="active" and bool(record.is_active) and visible
    return MaterialSyncItem(key=f"teacher:{record.id}",source="teacher",material_id=record.id,subject_id=record.subject_id,version=record.version or 1,status=("active" if active else "removed"),is_active=active,is_visible=visible,is_tombstone=not active,original_name=(record.original_name if active else None),**_subject_location(getattr(record, "subject", None)),mime_type=(record.mime_type if active else None),size=(record.size if active else None),file_hash=(record.file_hash if active else None),cloud_policy=getattr(record,"distribution_mode","persistent"),cloud_expires_at=_utc(getattr(record,"cloud_expires_at",None)),updated_at=_utc(record.updated_at),removed_at=_utc(getattr(record,"removed_at",None)))


def _personal(record):
    active=record.status=="active"
    return MaterialSyncItem(key=f"personal_sync:{record.id}",source="personal_sync",material_id=record.id,subject_id=record.subject_id,version=record.version or 1,status=("active" if active else "removed"),is_active=active,is_visible=active,is_tombstone=not active,original_name=(record.original_name if active else None),university=record.university,department=record.department,course=record.course,subject_name=record.subject_name,mime_type=(record.mime_type if active else None),size=(record.size if active else None),file_hash=(record.file_hash if active else None),cloud_policy="my_devices",cloud_expires_at=_utc(record.retention_expires_at),retention_status=record.retention_status,updated_at=_utc(record.updated_at),removed_at=_utc(record.deleted_at))


def _share(record,user_id):
    visible=record.recipient_user_id==user_id and record.status in {"pending","accepted","delivered"}
    return MaterialSyncItem(key=f"shared_user:{record.id}",source="shared_user",material_id=record.id,subject_id=record.subject_id,version=1,status=("active" if visible else "removed"),is_active=visible,is_visible=visible,is_tombstone=not visible,original_name=(record.original_name if visible else None),**_subject_location(getattr(record, "subject", None)),mime_type=(record.mime_type if visible else None),size=(record.size if visible else None),file_hash=(record.file_hash if visible else None),cloud_policy="temporary",cloud_expires_at=_utc(record.cloud_expires_at),shared_by_user_id=record.sender_user_id,updated_at=_utc(record.updated_at))


def build_material_sync_manifest(db:Session,user_id:int|None,since:datetime|None=None):
    if user_id is not None:
        process_personal_retention(db)
        process_expired_shares(db)
    items=[]
    public=db.query(PublicMaterial).all()
    for row in public:
        if _changed(row,since):
            items.append(_public(row, can_read_public_material(db, row, user_id)))
    if user_id is not None:
        accessible_ids=set(get_accessible_teacher_material_ids(db,user_id))
        teacher_rows=db.query(TeacherMaterial).filter((TeacherMaterial.uploaded_by==user_id)|(TeacherMaterial.id.in_(accessible_ids) if accessible_ids else False)).all()
        for row in teacher_rows:
            if _changed(row,since):
                items.append(_teacher(row,True))
        memberships=db.query(GroupMember.group_id).filter(GroupMember.user_id==user_id).all()
        group_ids={r[0] for r in memberships}
        if group_ids:
            groups={g.id:g for g in db.query(StudyGroup).filter(StudyGroup.id.in_(group_ids)).all()}
            for row in db.query(GroupMaterial).filter(GroupMaterial.group_id.in_(group_ids)).all():
                if _changed(row,since):
                    visible=groups.get(row.group_id) is not None and groups[row.group_id].status=="active"
                    items.append(MaterialSyncItem(key=f"group:{row.id}",source="group",material_id=row.id,group_id=row.group_id,version=getattr(row,"version",1) or 1,status=("active" if visible and row.status=="active" and row.is_active else "removed"),is_active=visible and row.status=="active" and row.is_active,is_visible=visible,is_tombstone=not(visible and row.status=="active" and row.is_active),original_name=(row.original_name if visible else None),mime_type=(row.mime_type if visible else None),size=(row.size if visible else None),file_hash=(row.file_hash if visible else None),university=getattr(groups[row.group_id], "university", None),department=groups[row.group_id].department,course=groups[row.group_id].course,subject_name=(groups[row.group_id].subject.name if groups[row.group_id].subject else None),subject_id=groups[row.group_id].subject_id,cloud_policy="persistent",updated_at=_utc(row.updated_at),removed_at=_utc(getattr(row,"removed_at",None))))
        for row in db.query(PersonalSyncedMaterial).filter(PersonalSyncedMaterial.owner_user_id==user_id).all():
            if _changed(row,since):
                items.append(_personal(row))
        for row in db.query(MaterialShare).filter(MaterialShare.recipient_user_id==user_id).all():
            if _changed(row,since):
                items.append(_share(row,user_id))
    visible=[item.key for item in items if item.is_active and item.is_visible and not item.is_tombstone]
    return MaterialSyncManifestResponse(generated_at=utc_now(),incremental=since is not None,visible_keys=visible,items=items)
