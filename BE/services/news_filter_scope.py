"""Known aliases for the academic paths used by public notices."""
import re
import unicodedata

from sqlalchemy import or_


COURSES = {
    'L-31': ('DMI', ('Informatica L-31', 'L-31 Informatica', 'Informatica',
                     'Scienze e Tecnologie Informatiche')),
    'LM-18': ('DMI', ('Informatica magistrale (LM-18)', 'Informatica magistrale')),
    'L-35': ('DMI', ('Matematica L-35', 'L-35 Matematica', 'Matematica')),
    'LM-40': ('DMI', ('Matematica magistrale (LM-40)', 'Matematica magistrale')),
    'L-13': ('DSBGA', ('Scienze Biologiche L-13', 'Scienze Biologiche')),
}
DEPARTMENTS = {
    'DMI': ('Dipartimento di Matematica e Informatica',),
    'DSBGA': ('Dipartimento di Scienze Biologiche, Geologiche e Ambientali',),
}
UNIVERSITIES = {'UNICT': ('Università di Catania', 'Università degli Studi di Catania')}

COURSE_TERMS = {
    'LM-40': (r'\blm[\s-]*40\b', r'\bmatematica\s+magistrale\b',
              r'\b(?:laurea\s+magistrale|cdlm)\s+(?:in\s+)?matematica\b'),
    'LM-18': (r'\blm[\s-]*18\b', r'\binformatica\s+magistrale\b',
              r'\b(?:laurea\s+magistrale|cdlm)\s+(?:in\s+)?informatica\b'),
    'L-31': (r'\bl[\s-]*31\b', r'\bscienze\s+e\s+tecnologie\s+informatiche\b',
             r'\b(?:informatica\s+triennale|laurea\s+triennale\s+in\s+informatica)\b'),
    'L-35': (r'\bl[\s-]*35\b', r'\b(?:matematica\s+triennale|laurea\s+triennale\s+in\s+matematica)\b'),
    'L-13': (r'\bl[\s-]*13\b', r'\bscienze\s+biologiche\b'),
}


def unambiguous_course_mention(title: str, content: str) -> str | None:
    """A single explicit programme reference; a bare 'matematica' is ambiguous."""
    text = _key(f'{title} {content}')
    detected = {course for course, patterns in COURSE_TERMS.items()
                if any(re.search(pattern, text) for pattern in patterns)}
    return next(iter(detected)) if len(detected) == 1 else None


def _key(value: str) -> str:
    folded = unicodedata.normalize('NFKD', value.casefold())
    return re.sub(r'[^a-z0-9]+', ' ', ''.join(c for c in folded if not unicodedata.combining(c))).strip()


def teacher_name_key(value: str | None) -> str:
    """Normalize academic titles while retaining the complete teacher name."""
    normalized = unicodedata.normalize('NFKD', value or '').casefold()
    normalized = ''.join(c for c in normalized if not unicodedata.combining(c))
    normalized = re.sub(r'^(?:(?:prof(?:\.ssa|essoressa|essore|ssa)?|dott(?:\.ssa|oressa|ore|ssa)?)\.?\s+)+', '', normalized)
    return re.sub(r'[^a-z0-9]+', ' ', normalized).strip()


def code(value: str, dimension: str) -> str | None:
    options = {'course': COURSES, 'department': DEPARTMENTS, 'university': UNIVERSITIES}[dimension]
    normalized = _key(value)
    for name, entries in options.items():
        aliases = entries[1] if dimension == 'course' else entries
        if normalized in {_key(item) for item in (name, *aliases)}:
            return name
    return None


def matches(name_column, code_column, value: str, dimension: str):
    known = code(value, dimension)
    if known is None:
        # Unknown manually entered courses must never silently match L-31.
        return name_column.ilike(value.strip())
    options = {'course': COURSES, 'department': DEPARTMENTS, 'university': UNIVERSITIES}[dimension]
    aliases = options[known][1] if dimension == 'course' else options[known]
    return or_(code_column.ilike(known), *(name_column.ilike(alias) for alias in (known, *aliases)))
