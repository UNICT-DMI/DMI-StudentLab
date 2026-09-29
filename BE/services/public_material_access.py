"""Check catalog audience at every read, including sync and downloads."""
from models.group import GroupMember, StudyGroup
from models.user import UserAcademicPath
from models.subject import UserSubject


def can_read_public_material(db, material, user_id: int | None) -> bool:
    if (material.status != 'published' or not material.is_visible or
            getattr(material, 'visibility_state', 'visible') != 'visible' or
            getattr(material, 'drive_activation_pending', False)):
        return False
    target = material.audience_type or 'public'
    if target == 'public':
        return True
    if user_id is None:
        return False
    if target == 'user':
        return material.audience_id == user_id
    if target == 'group':
        return material.audience_id is not None and db.query(GroupMember.id).join(
            StudyGroup, StudyGroup.id == GroupMember.group_id).filter(
            GroupMember.group_id == material.audience_id,
            GroupMember.user_id == user_id,
            StudyGroup.status == 'active').first() is not None
    if target in {'course', 'subject'}:
        in_course = db.query(UserAcademicPath.id).filter(
            UserAcademicPath.user_id == user_id,
            UserAcademicPath.university_code == material.university_code,
            UserAcademicPath.department_code == material.department_code,
            UserAcademicPath.course_code == material.course_code,
            UserAcademicPath.is_current.is_(True),
            UserAcademicPath.status == 'enrolled').first() is not None
        if not in_course or target == 'course':
            return in_course
        return db.query(UserSubject.id).filter(
            UserSubject.user_id == user_id,
            UserSubject.subject_id == material.subject_id).first() is not None
    return False
