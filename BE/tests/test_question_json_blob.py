"""Edited quiz JSON must remain readable without changing Vercel's bundled file."""
import json
import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault('DATABASE_URL', 'sqlite://')
os.environ.setdefault('SECRET_KEY', 'test-secret')
try:
    import dotenv  # noqa: F401
except ImportError:
    sys.modules['dotenv'] = types.SimpleNamespace(load_dotenv=lambda **kwargs: None)

from schemas.question import QuestionUpdate
from services import question_json_storage, question_service, quiz_service


class NotFound(Exception):
    pass


class Blob:
    saved = {}

    def __init__(self, token):
        assert token == 'test-token'

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def get(self, pathname, **kwargs):
        assert kwargs == {'access': 'private', 'use_cache': False}
        if pathname not in self.saved:
            raise NotFound()
        return types.SimpleNamespace(status_code=200, content=self.saved[pathname])

    def put(self, pathname, content, **kwargs):
        assert kwargs['access'] == 'private'
        assert kwargs['overwrite'] is True
        self.saved[pathname] = content


class JsonStorageTests(unittest.TestCase):
    def test_update_and_quiz_read_persistent_json(self):
        original = {
            'id_question': 94, 'estimed_time': 35,
            'metadata': {'argoment': 'Sistemi Operativi', 'teacher': []},
            'text': 'Domanda precedente',
            'option': [{'id': i, 'text': i.upper()} for i in 'abcd'],
            'id_correct': 'b', 'formal_explanation': 'Formalmente corretta.',
            'informal_explanation': 'Spiegazione semplice.',
            'question_response_explanation': {i: 'Spiegazione ' + i for i in 'abcd'},
        }
        blob_module = types.ModuleType('vercel.blob')
        blob_module.BlobClient = Blob
        blob_module.BlobNotFoundError = NotFound
        vercel_module = types.ModuleType('vercel')
        Blob.saved = {}
        previous = Path.cwd()
        with tempfile.TemporaryDirectory() as folder, patch.dict(
            sys.modules, {'vercel': vercel_module, 'vercel.blob': blob_module}
        ), patch.object(question_json_storage.settings, 'is_vercel', True), patch.object(
            question_json_storage.settings, 'blob_read_write_token', 'test-token'
        ):
            try:
                os.chdir(folder)
                bank = Path('data/dmi/l-31/question/sistemi_operativi_quiz.json')
                bank.parent.mkdir(parents=True)
                bank.write_text(json.dumps([original]))
                before = bank.read_bytes()
                updated = question_service.update_question(
                    'DMI', 'L-31', 'Sistemi Operativi Quiz', '94',
                    QuestionUpdate(text='Quale caratteristica compare nella terza generazione?'),
                    default_university='Università degli Studi di Catania')
                self.assertEqual(updated['id_question'], '94')
                self.assertEqual(before, bank.read_bytes())
                self.assertEqual(quiz_service.load_questions('DMI', 'L-31',
                    'Sistemi Operativi Quiz')[0]['text'], updated['text'])
                self.assertEqual(len(Blob.saved), 1)
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
