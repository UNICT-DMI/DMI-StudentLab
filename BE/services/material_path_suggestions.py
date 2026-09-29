"""Suggest official catalog paths without inspecting or uploading personal files."""
import re
import unicodedata

ALIASES = {
    'unict': 'universita degli studi di catania',
    'uni ct': 'universita degli studi di catania',
    'dmi': 'dipartimento di matematica e informatica',
    'l31': 'informatica',
    'l 31': 'informatica',
}


def normalize(value: str | None) -> str:
    text = unicodedata.normalize('NFKD', value or '')
    text = ''.join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r'[^a-z0-9]+', ' ', text.lower()).strip()
    return ALIASES.get(text, text)


def _score(value: str | None, name: str | None, code: str | None = None) -> float:
    value = normalize(value)
    if not value:
        return 0.0
    names = [normalize(name), normalize(code)]
    if value in names:
        return 1.0
    if len(value) >= 4 and any(value in n.split() for n in names if n):
        return 0.78
    if len(value) >= 5 and any(n.startswith(value) for n in names if n):
        return 0.72
    return 0.0


def suggest_subject_paths(subjects, *, university, department, course, subject=None, limit=5):
    matches = []
    for item in subjects:
        if not subject and item.code != 'COURSE-MATERIALS':
            continue
        parts = (
            _score(university, item.university, item.university_code),
            _score(department, item.department, item.department_code),
            _score(course, item.course, item.course_code),
            _score(subject, item.name, item.code) if subject else 1.0,
        )
        # Never match a subject using only a filename or one broad acronym.
        if min(parts[:3]) < 0.7 or (subject and parts[3] < 0.7):
            continue
        confidence = round(sum(parts) / 4, 2)
        matches.append({
            'subject_id': item.id,
            'university': item.university,
            'department': item.department,
            'course': item.course,
            'subject': item.name,
            'confidence': confidence,
        })
    matches.sort(key=lambda x: (-x['confidence'], x['university'], x['department'], x['course'], x['subject'] or ''))
    return matches[:limit]
