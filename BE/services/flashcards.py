"""Flashcard con ripetizione dilazionata (SM-2 semplificato).

Voti: 0 = per niente, 1 = a fatica, 2 = bene, 3 = facile.
Lo stesso algoritmo è in Flutter (flashcard_scheduler.dart) per chi usa
l'app senza account: i risultati restano sul telefono.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from models.flashcard_review import FlashcardReview

MIN_EASE = 1.3
LEARNING_MINUTES = {0: 1, 1: 10}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def schedule(ease: float, interval_days: int, reviews: int, grade: int) -> tuple[float, int, timedelta]:
    """Restituisce (nuova facilità, nuovo intervallo in giorni, attesa prima della prossima)."""
    grade = max(0, min(3, int(grade)))
    ease = float(ease or 2.5)
    if grade < 2:
        ease = max(MIN_EASE, ease - (0.2 if grade == 1 else 0.3))
        return ease, 0, timedelta(minutes=LEARNING_MINUTES[grade])
    ease = max(MIN_EASE, ease + (0.15 if grade == 3 else 0.0))
    if reviews == 0 or interval_days <= 0:
        interval = 3 if grade == 2 else 8
    else:
        interval = max(interval_days + 1, round(interval_days * ease * (1.3 if grade == 3 else 1.0)))
    interval = min(interval, 365)
    return ease, interval, timedelta(days=interval)


def preview(ease: float, interval_days: int, reviews: int) -> dict[int, str]:
    """Etichette dei pulsanti: "1 min", "10 min", "3 gg", "8 gg"."""
    labels = {}
    for grade in range(4):
        _, _, wait = schedule(ease, interval_days, reviews, grade)
        minutes = int(wait.total_seconds() // 60)
        labels[grade] = f'{minutes} min' if minutes < 60 * 24 else f'{wait.days} gg'
    return labels


def _key(department: str, course: str, subject: str) -> tuple[str, str, str]:
    """Stessa materia scritta in modi diversi = stesse schede."""
    return department.strip().lower(), course.strip().lower(), subject.strip().lower()


def _find(db: Session, user_id: int, key: tuple[str, str, str], card_id: str) -> FlashcardReview | None:
    return (db.query(FlashcardReview)
            .filter(FlashcardReview.user_id == user_id, FlashcardReview.department == key[0],
                    FlashcardReview.course == key[1], FlashcardReview.subject == key[2],
                    FlashcardReview.card_id == card_id)
            .first())


def review(db: Session, user_id: int, *, department: str, course: str, subject: str, card_id: str,
           grade: int, argument: str | None = None) -> FlashcardReview:
    from sqlalchemy.exc import IntegrityError
    key = _key(department, course, subject)
    for attempt in range(2):
        row = _find(db, user_id, key, card_id)
        now = utc_now()
        if row is None:
            row = FlashcardReview(user_id=user_id, department=key[0], course=key[1], subject=key[2],
                                  card_id=card_id, ease=2.5, interval_days=0, reviews=0, lapses=0, created_at=now)
            db.add(row)
        ease, interval, wait = schedule(row.ease, row.interval_days, row.reviews, grade)
        if grade < 2 and row.reviews > 0:
            row.lapses = (row.lapses or 0) + 1
        row.ease, row.interval_days = ease, interval
        row.reviews = (row.reviews or 0) + 1
        row.last_grade = max(0, min(3, int(grade)))
        row.argument = argument or row.argument
        row.last_reviewed_at = now
        row.due_at = now + wait
        row.updated_at = now
        try:
            db.commit()
        except IntegrityError:
            # due ripassi contemporanei della stessa scheda nuova: si riprova sulla riga appena creata
            db.rollback()
            if attempt:
                raise
            continue
        db.refresh(row)
        return row
    raise RuntimeError('unreachable')


def states(db: Session, user_id: int, department: str, course: str, subject: str) -> dict[str, FlashcardReview]:
    key = _key(department, course, subject)
    rows = (db.query(FlashcardReview)
            .filter(FlashcardReview.user_id == user_id, FlashcardReview.department == key[0],
                    FlashcardReview.course == key[1], FlashcardReview.subject == key[2])
            .all())
    return {row.card_id: row for row in rows}


def serialize_state(row: FlashcardReview | None) -> dict:
    if row is None:
        return {'reviews': 0, 'ease': 2.5, 'interval_days': 0, 'due_at': None, 'last_grade': None,
                'is_new': True, 'buttons': preview(2.5, 0, 0)}
    return {'reviews': row.reviews, 'ease': row.ease, 'interval_days': row.interval_days, 'due_at': row.due_at,
            'last_grade': row.last_grade, 'is_new': False,
            'buttons': preview(row.ease, row.interval_days, row.reviews)}


def due_order(cards: list[dict], state_by_id: dict[str, FlashcardReview], limit: int, new_limit: int = 10) -> list[dict]:
    """Prima le schede scadute (le più in ritardo), poi al massimo `new_limit` nuove."""
    now = utc_now()
    due, new = [], []
    for card in cards:
        row = state_by_id.get(card['id'])
        if row is None:
            new.append(card)
        else:
            due_at = row.due_at if row.due_at is None or row.due_at.tzinfo else row.due_at.replace(tzinfo=timezone.utc)
            if due_at is None or due_at <= now:
                due.append((due_at or now, card))
    due.sort(key=lambda pair: pair[0])
    return [c for _, c in due][:limit] + new[:max(0, min(new_limit, limit - len(due)))]


def count_due(state_by_id: dict[str, FlashcardReview]) -> int:
    now = utc_now()
    total = 0
    for row in state_by_id.values():
        due_at = row.due_at
        if due_at is not None and due_at.tzinfo is None:
            due_at = due_at.replace(tzinfo=timezone.utc)
        if due_at is None or due_at <= now:
            total += 1
    return total
