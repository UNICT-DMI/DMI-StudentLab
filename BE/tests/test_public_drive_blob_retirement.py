"""A staging Blob is removed only after a verified, exclusive Drive copy."""
import asyncio
from types import SimpleNamespace
from unittest.mock import MagicMock

from services import public_drive_blob_retirement as retirement


def _material():
    return SimpleNamespace(id=5, stored_name='material-publication/5/test.pdf',
        original_name='test.pdf', drive_file_id='drive-5',
        drive_activation_pending=False, drive_copied_at=object(),
        file_hash='a' * 64, size=123)


class _Session:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return None


def _setup(monkeypatch, metadata=None):
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None
    db.query.return_value.filter.return_value.all.return_value = []
    deleted = []
    events = []

    async def session():
        return _Session()

    async def token(_):
        return 'test-token'

    async def verify(*_):
        return metadata or {'size': '123', 'appProperties': {
            'studentlab_public_id': '5', 'sha256': 'a' * 64}}

    async def delete(path):
        deleted.append(path)
        return True

    monkeypatch.setattr(retirement, '_session', session)
    monkeypatch.setattr(retirement, '_access_token', token)
    monkeypatch.setattr(retirement, 'verify_under_root', verify)
    monkeypatch.setattr(retirement, 'delete_private_blob', delete)
    monkeypatch.setattr(retirement, 'record_storage_event',
                        lambda *_args, **kwargs: events.append(kwargs))
    return db, deleted, events


def test_verified_exclusive_copy_retires_staging_blob(monkeypatch):
    db, deleted, events = _setup(monkeypatch)
    result = asyncio.run(retirement.retire_public_staging_blob(db, _material()))
    assert result == 'deleted'
    assert deleted == ['material-publication/5/test.pdf']
    assert events[0]['action'] == 'drive_staging_blob_deleted'


def test_mismatched_drive_copy_keeps_blob(monkeypatch):
    db, deleted, _ = _setup(monkeypatch, metadata={
        'size': '122', 'appProperties': {'studentlab_public_id': '5',
                                       'sha256': 'a' * 64}})
    assert asyncio.run(retirement.retire_public_staging_blob(db, _material())) == 'skipped'
    assert deleted == []


def test_shared_source_keeps_blob(monkeypatch):
    db, deleted, _ = _setup(monkeypatch)
    db.query.return_value.filter.return_value.first.return_value = (123,)
    assert asyncio.run(retirement.retire_public_staging_blob(db, _material())) == 'skipped'
    assert deleted == []


def test_unconfirmed_drive_copy_keeps_blob(monkeypatch):
    db, deleted, _ = _setup(monkeypatch)
    material = _material()
    material.drive_copied_at = None
    assert asyncio.run(retirement.retire_public_staging_blob(db, material)) == 'skipped'
    assert deleted == []
