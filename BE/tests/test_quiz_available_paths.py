"""Quiz catalogue exposes only existing, usable question banks."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from services import quiz_service


class QuizAvailablePathsTests(unittest.TestCase):
    def test_only_banks_with_available_questions_are_listed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            banks = root / 'dmi' / 'l-31' / 'question'
            banks.mkdir(parents=True)
            (banks / 'sistemi_operativi.json').write_text(
                json.dumps([{'id_question': 1, 'text': 'Una domanda?'}]), encoding='utf-8')
            (banks / 'vuota.json').write_text('[]', encoding='utf-8')
            (banks / 'nascosta.json').write_text(
                json.dumps([{'id_question': 2, 'is_hidden': True}]), encoding='utf-8')
            (root / 'dmi' / 'lm-18' / 'question').mkdir(parents=True)
            with patch.object(quiz_service, 'DATA_ROOT', root), \
                    patch.object(quiz_service, 'read_question_json', return_value=None):
                self.assertEqual(quiz_service.available_quiz_paths(), [
                    {'department': 'DMI', 'course': 'L-31', 'subject': 'sistemi operativi'}])
                self.assertEqual(quiz_service.subjects('DMI', 'L-31'), ['sistemi operativi'])
                self.assertEqual(quiz_service.subjects('DMI', 'LM-18'), [])

    def test_blob_override_controls_visibility_of_existing_bank(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            banks = root / 'dmi' / 'l-31' / 'question'
            banks.mkdir(parents=True)
            (banks / 'reti.json').write_text('[]', encoding='utf-8')
            with patch.object(quiz_service, 'DATA_ROOT', root), \
                    patch.object(quiz_service, 'read_question_json', return_value=[{'id_question': 3}]):
                self.assertEqual(quiz_service.subjects('DMI', 'L-31'), ['reti'])


if __name__ == '__main__':
    unittest.main()
