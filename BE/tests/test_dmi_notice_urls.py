"""The course listing, not a teacher name, determines an official notice's scope."""

import unittest

from unittest.mock import patch

from bs4 import BeautifulSoup

from services.dmi_notice_scraper import extract_listing, is_notice_url


class NoticeUrlTests(unittest.TestCase):
    def test_teacher_listing_accepts_global_article_with_matching_course(self):
        url = ('https://web.dmi.unict.it/avvisi-docente/'
               'programmazione-ii-az-esiti-scritto-28-settembre?cdl=l-31')
        self.assertTrue(is_notice_url(url, 'l31_docente'))
        self.assertFalse(is_notice_url(url, 'l35_docente'))
        self.assertFalse(is_notice_url(url, 'l31_corso'))

    def test_global_article_rejects_unknown_course_or_domain(self):
        base = 'https://web.dmi.unict.it/avvisi-docente/esame'
        for suffix in ('', '?cdl=l-35', '?cdl=l-31&cdl=l-35'):
            self.assertFalse(is_notice_url(base + suffix, 'l31_docente'))
        self.assertFalse(is_notice_url(
            'https://another.example/avvisi-docente/esame?cdl=l-31', 'l31_docente'))

    def test_original_course_urls_still_work(self):
        self.assertTrue(is_notice_url(
            'https://web.dmi.unict.it/it/corsi/l-31/avvisi/lezioni', 'l31_corso'))
        self.assertTrue(is_notice_url(
            'https://www.dsbga.unict.it/avvisi-docente/esame?cdl=l-13', 'l13_docente'))

    def test_l31_teacher_listing_keeps_global_articles(self):
        html = '''<div>28/09/2026 <a href="/avvisi-docente/esiti-laboratorio?cdl=l-31">
          Esiti prova di Laboratorio di Programmazione II</a>
          <a href="/corsi/l-31/docenti/massimo.orazio.spata">Prof. Massimo Orazio SPATA</a>
          28/09/2026 <a href="/avvisi-docente/appello-reti?cdl=l-31">Appello di Reti</a>
          <a href="/corsi/l-31/docenti/salvatore.riccobene">Prof. Salvatore Antonio RICCOBENE</a>
        </div>'''
        with patch('services.dmi_notice_scraper.get_soup', return_value=BeautifulSoup(html, 'html.parser')):
            rows = extract_listing('l31_docente',
                                   'https://web.dmi.unict.it/corsi/l-31/avvisi-docente')
        self.assertEqual([row['titolo'] for row in rows],
                         ['Esiti prova di Laboratorio di Programmazione II', 'Appello di Reti'])
        self.assertTrue(all(row['url'].endswith('cdl=l-31') for row in rows))


if __name__ == '__main__':
    unittest.main()
