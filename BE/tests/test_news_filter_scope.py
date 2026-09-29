"""Equivalent university paths must not leak course-specific news."""
import os
import unittest

os.environ.setdefault('DATABASE_URL', 'sqlite://')
os.environ.setdefault('SECRET_KEY', 'test-secret')

from sqlalchemy import Column, MetaData, String, Table, create_engine, select

from services.news_filter_scope import code, matches


class NoticeFilterScopeTests(unittest.TestCase):
    def test_aliases_are_exact_and_course_specific(self):
        self.assertEqual(code('Scienze e tecnologie informatiche', 'course'), 'L-31')
        self.assertEqual(code('Informatica L-31', 'course'), 'L-31')
        self.assertEqual(code('Matematica magistrale (LM-40)', 'course'), 'LM-40')
        self.assertIsNone(code('Informatica del futuro', 'course'))
        self.assertEqual(code('Dipartimento di Matematica e Informatica', 'department'), 'DMI')

    def test_filter_does_not_mix_l31_lm40_and_l13(self):
        engine = create_engine('sqlite://')
        news = Table('news', MetaData(), Column('course', String), Column('course_code', String))
        news.create(engine)
        with engine.begin() as connection:
            connection.execute(news.insert(), [
                {'course': 'Scienze e Tecnologie Informatiche', 'course_code': None},
                {'course': 'Informatica L-31', 'course_code': None},
                {'course': 'Matematica LM-40', 'course_code': 'LM-40'},
                {'course': 'Scienze Biologiche', 'course_code': 'L-13'},
            ])
            for choice, expected in [('L-31', 2), ('LM-40', 1), ('L-13', 1), ('Corso sconosciuto', 0)]:
                rows = connection.execute(select(news).where(
                    matches(news.c.course, news.c.course_code, choice, 'course'))).all()
                self.assertEqual(len(rows), expected, choice)


if __name__ == '__main__':
    unittest.main()
