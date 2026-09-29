from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint

from core.database import Base


class MaterialCatalogDraft(Base):
    __tablename__ = 'material_catalog_drafts'
    __table_args__ = (UniqueConstraint('admin_id', 'material_id', name='uq_catalog_draft_admin_material'),)

    id = Column(Integer, primary_key=True)
    admin_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    material_id = Column(Integer, ForeignKey('public_materials.id', ondelete='CASCADE'), nullable=False, index=True)
    base_version = Column(Integer, nullable=False)
    subject_id = Column(Integer, ForeignKey('subjects.id'), nullable=False)
    path_json = Column(Text, nullable=False, default='[]')
    visibility_state = Column(String(20), nullable=False)
    audience_type = Column(String(20), nullable=False)
    audience_id = Column(Integer, nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class MaterialCatalogFolder(Base):
    __tablename__ = 'material_catalog_folders'

    id = Column(Integer, primary_key=True)
    subject_id = Column(Integer, ForeignKey('subjects.id'), nullable=False, index=True)
    path_json = Column(Text, nullable=False)
    visibility_state = Column(String(20), nullable=False, default='visible')
    # Null once published; private to one admin while still in draft.
    draft_admin_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=True, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))


class MaterialCatalogImportDraft(Base):
    __tablename__ = 'material_catalog_import_drafts'
    __table_args__ = (UniqueConstraint('admin_id', 'drive_file_id', name='uq_catalog_import_admin_drive'),)

    id = Column(Integer, primary_key=True)
    admin_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    drive_file_id = Column(String(128), nullable=False)
    subject_id = Column(Integer, ForeignKey('subjects.id'), nullable=False)
    path_json = Column(Text, nullable=False, default='[]')
    audience_type = Column(String(20), nullable=False, default='public')
    audience_id = Column(Integer, nullable=True)
    original_name = Column(String(255), nullable=False)
    mime_type = Column(String(150), nullable=False)
    size = Column(Integer, nullable=False)
    allow_duplicate = Column(Boolean, nullable=False, default=False)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
