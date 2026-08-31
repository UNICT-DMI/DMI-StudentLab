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
    UniqueConstraint,
)

from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(
        timezone.utc,
    )


class GroupMaterial(Base):
    __tablename__ = "group_materials"

    __table_args__ = (
        UniqueConstraint(
            "group_id",
            "file_hash",
            name="uq_group_material_group_file_hash",
        ),
        CheckConstraint(
            "size > 0",
            name="chk_group_material_size",
        ),
        CheckConstraint(
            "version >= 1",
            name="chk_group_material_version",
        ),
        CheckConstraint(
            "status IN ('active', 'hidden', 'removed')",
            name="chk_group_material_status",
        ),
        CheckConstraint(
            "("
            "status != 'removed'"
            ") OR ("
            "is_active = false"
            ")",
            name="chk_group_material_removed_active",
        ),
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    group_id = Column(
        Integer,
        ForeignKey(
            "study_groups.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    uploaded_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
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
        nullable=True,
        index=True,
    )

    version = Column(
        Integer,
        nullable=False,
        default=1,
        server_default="1",
        index=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="active",
        server_default="active",
        index=True,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        index=True,
    )

    updated_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
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

    group = relationship(
        "StudyGroup",
        back_populates="materials",
        foreign_keys=[
            group_id,
        ],
    )

    uploader = relationship(
        "User",
        foreign_keys=[
            uploaded_by,
        ],
    )

    updater = relationship(
        "User",
        foreign_keys=[
            updated_by,
        ],
    )

    remover = relationship(
        "User",
        foreign_keys=[
            removed_by,
        ],
    )