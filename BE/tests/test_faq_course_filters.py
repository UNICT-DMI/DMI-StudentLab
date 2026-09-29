"""Verifica che i nomi storici dello stesso corso usino un unico filtro."""
import unittest
from unittest.mock import patch

from sqlalchemy import Column, Integer, MetaData, String, Table, create_engine, select

from routes.faq import _apply_context, faq_course_label


class FaqCourseFilterTests(unittest.TestCase):
    def test_label_collapses_only_known_aliases(self):
        self.assertEqual(faq_course_label('Scienze e Tecnologie Informatiche'), 'Informatica L-31')
        self.assertEqual(faq_course_label('Informatica L-31'), 'Informatica L-31')
        self.assertEqual(faq_course_label('Informatica magistrale'), 'Informatica magistrale (LM-18)')
        self.assertEqual(faq_course_label('Corso nuovo'), 'Corso nuovo')

    def test_query_selects_both_l31_names_without_lm18(self):
        engine = create_engine('sqlite://')
        table = Table('faq_questions', MetaData(),
                      Column('id', Integer, primary_key=True),
                      Column('university', String), Column('department', String),
                      Column('course', String), Column('subject_id', Integer))
        table.create(engine)
        with engine.begin() as conn:
            for id_, course in enumerate(('Informatica L-31',
                                          'Scienze e Tecnologie Informatiche',
                                          'Informatica magistrale (LM-18)'), 1):
                conn.execute(table.insert().values(
                    id=id_, university='Università di Catania',
                    department='Dipartimento di Matematica e Informatica',
                    course=course))
        with patch('routes.faq.FaqQuestion', table.c), engine.connect() as conn:
            query = _apply_context(select(table.c.id), 'UNICT', 'DMI', 'L-31', None)
            self.assertEqual(conn.execute(query).scalars().all(), [1, 2])
            query = _apply_context(select(table.c.id), None, None, 'LM-18', None)
            self.assertEqual(conn.execute(query).scalars().all(), [3])


if __name__ == '__main__':
    unittest.main()
