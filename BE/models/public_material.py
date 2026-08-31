from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)

from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(
        timezone.utc,
    )


class PublicMaterial(Base):
    __tablename__ = (
        "public_materials"
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    subject_id = Column(
        Integer,
        ForeignKey(
            "subjects.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    uploaded_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    publication_request_id = Column(
        Integer,
        ForeignKey(
            "material_publication_requests.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        unique=True,
        index=True,
    )

    university = Column(
        String(200),
        nullable=False,
    )

    university_code = Column(
        String(100),
        nullable=False,
        index=True,
    )

    department = Column(
        String(200),
        nullable=False,
    )

    department_code = Column(
        String(100),
        nullable=False,
        index=True,
    )

    course = Column(
        String(200),
        nullable=False,
    )

    course_code = Column(
        String(100),
        nullable=False,
        index=True,
    )

    title = Column(
        String(250),
        nullable=False,
    )

    description = Column(
        Text,
        nullable=True,
    )

    original_name = Column(
        String(255),
        nullable=False,
    )

    stored_name = Column(
        String(500),
        nullable=False,
        unique=True,
    )

    file_path = Column(
        String(1000),
        nullable=False,
    )

    mime_type = Column(
        String(150),
        nullable=False,
    )

    size = Column(
        BigInteger,
        nullable=False,
    )

    file_hash = Column(
        String(64),
        nullable=False,
        index=True,
    )

    version = Column(
        Integer,
        nullable=False,
        default=1,
        index=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="published",
        index=True,
    )

    is_visible = Column(
        Boolean,
        nullable=False,
        default=True,
        index=True,
    )

    approved_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    approved_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    removed_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    removed_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    removal_reason = Column(
        Text,
        nullable=True,
    )

    created_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        index=True,
    )

    updated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
        index=True,
    )

    subject = relationship(
        "Subject",
    )

    uploader = relationship(
        "User",
        foreign_keys=[
            uploaded_by,
        ],
    )

    approver = relationship(
        "User",
        foreign_keys=[
            approved_by,
        ],
    )

    remover = relationship(
        "User",
        foreign_keys=[
            removed_by,
        ],
    )

    publication_request = relationship(
        "MaterialPublicationRequest",
        foreign_keys=[
            publication_request_id,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ("
            "'published', "
            "'hidden', "
            "'removed'"
            ")",
            name=(
                "chk_public_material_status"
            ),
        ),
        CheckConstraint(
            "size > 0",
            name=(
                "chk_public_material_size"
            ),
        ),
        CheckConstraint(
            "version >= 1",
            name=(
                "chk_public_material_version"
            ),
        ),
        CheckConstraint(
            "("
            "status != 'removed'"
            ") OR ("
            "is_visible = false"
            ")",
            name=(
                "chk_public_material_removed_visibility"
            ),
        ),
    )