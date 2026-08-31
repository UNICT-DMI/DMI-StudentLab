from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from models.quiz_attempt import (
    QuizAttempt,
    QuizAttemptAnswer,
)


def _normalize_filter(
    value: str | None,
) -> str | None:
    if value is None:
        return None

    normalized = value.strip()

    return (
        normalized
        if normalized
        else None
    )


def _base_attempt_query(
    db: Session,
    user_id: int,
):
    return (
        db.query(
            QuizAttempt
        )
        .filter(
            QuizAttempt.user_id == user_id,
            QuizAttempt.status == "completed",
            QuizAttempt.is_hidden_from_history.is_(False),
            QuizAttempt.is_deleted.is_(False),
        )
    )


def _base_answer_query(
    db: Session,
    user_id: int,
):
    return (
        db.query(
            QuizAttemptAnswer
        )
        .join(
            QuizAttempt,
            QuizAttempt.id == QuizAttemptAnswer.attempt_id,
        )
        .options(
            joinedload(
                QuizAttemptAnswer.attempt
            )
        )
        .filter(
            QuizAttempt.user_id == user_id,
            QuizAttempt.status == "completed",
            QuizAttempt.is_hidden_from_history.is_(False),
            QuizAttempt.is_deleted.is_(False),
        )
    )


def _apply_attempt_filters(
    query,
    *,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
):
    department = _normalize_filter(
        department
    )
    course = _normalize_filter(
        course
    )
    subject = _normalize_filter(
        subject
    )

    if department is not None:
        query = query.filter(
            func.lower(
                QuizAttempt.department
            ) == department.lower()
        )

    if course is not None:
        query = query.filter(
            func.lower(
                QuizAttempt.course
            ) == course.lower()
        )

    if subject is not None:
        query = query.filter(
            func.lower(
                QuizAttempt.subject
            ) == subject.lower()
        )

    return query


def _percentage(
    correct: int,
    total: int,
) -> float:
    if total <= 0:
        return 0.0

    return round(
        (
            correct
            / total
        )
        * 100,
        2,
    )


def get_student_overall_statistics(
    db: Session,
    user_id: int,
) -> dict[str, Any]:
    attempts = (
        _base_attempt_query(
            db,
            user_id,
        )
        .all()
    )

    total_attempts = len(
        attempts
    )

    total_questions = sum(
        attempt.question_count
        for attempt in attempts
    )

    correct_count = sum(
        attempt.correct_count
        for attempt in attempts
    )

    wrong_count = sum(
        attempt.wrong_count
        for attempt in attempts
    )

    unanswered_count = sum(
        attempt.unanswered_count
        for attempt in attempts
    )

    total_elapsed_seconds = sum(
        attempt.elapsed_seconds
        or 0
        for attempt in attempts
    )

    return {
        "total_attempts":
            total_attempts,
        "total_questions":
            total_questions,
        "correct_count":
            correct_count,
        "wrong_count":
            wrong_count,
        "unanswered_count":
            unanswered_count,
        "accuracy_percentage":
            _percentage(
                correct_count,
                total_questions,
            ),
        "total_elapsed_seconds":
            total_elapsed_seconds,
    }


def get_student_subject_statistics(
    db: Session,
    user_id: int,
) -> list[dict[str, Any]]:
    attempts = (
        _base_attempt_query(
            db,
            user_id,
        )
        .all()
    )

    subjects: dict[
        tuple[
            str,
            str,
            str,
        ],
        dict[str, Any],
    ] = {}

    for attempt in attempts:
        key = (
            attempt.department,
            attempt.course,
            attempt.subject,
        )

        if key not in subjects:
            subjects[
                key
            ] = {
                "department":
                    attempt.department,
                "course":
                    attempt.course,
                "subject":
                    attempt.subject,
                "total_attempts":
                    0,
                "total_questions":
                    0,
                "correct_count":
                    0,
                "wrong_count":
                    0,
                "unanswered_count":
                    0,
                "total_elapsed_seconds":
                    0,
            }

        stats = subjects[
            key
        ]

        stats[
            "total_attempts"
        ] += 1

        stats[
            "total_questions"
        ] += (
            attempt.question_count
        )

        stats[
            "correct_count"
        ] += (
            attempt.correct_count
        )

        stats[
            "wrong_count"
        ] += (
            attempt.wrong_count
        )

        stats[
            "unanswered_count"
        ] += (
            attempt.unanswered_count
        )

        stats[
            "total_elapsed_seconds"
        ] += (
            attempt.elapsed_seconds
            or 0
        )

    result: list[
        dict[str, Any]
    ] = []

    for stats in subjects.values():
        stats[
            "accuracy_percentage"
        ] = _percentage(
            stats[
                "correct_count"
            ],
            stats[
                "total_questions"
            ],
        )

        result.append(
            stats
        )

    return sorted(
        result,
        key=lambda item: (
            item[
                "department"
            ].casefold(),
            item[
                "course"
            ].casefold(),
            item[
                "subject"
            ].casefold(),
        ),
    )


def get_student_argument_statistics(
    db: Session,
    user_id: int,
    *,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
) -> list[dict[str, Any]]:
    query = _base_answer_query(
        db,
        user_id,
    )

    query = _apply_attempt_filters(
        query,
        department=department,
        course=course,
        subject=subject,
    )

    rows = query.all()

    arguments: dict[
        tuple[
            str,
            str,
            str,
            str,
        ],
        dict[str, Any],
    ] = {}

    for answer in rows:
        attempt = answer.attempt

        argument = (
            answer.argument.strip()
            if isinstance(
                answer.argument,
                str,
            )
            and answer.argument.strip()
            else "Senza argomento"
        )

        key = (
            attempt.department,
            attempt.course,
            attempt.subject,
            argument,
        )

        if key not in arguments:
            arguments[
                key
            ] = {
                "department":
                    attempt.department,
                "course":
                    attempt.course,
                "subject":
                    attempt.subject,
                "argument":
                    argument,
                "total_questions":
                    0,
                "correct_count":
                    0,
                "wrong_count":
                    0,
                "unanswered_count":
                    0,
                "total_response_time_seconds":
                    0,
            }

        stats = arguments[
            key
        ]

        stats[
            "total_questions"
        ] += 1

        stats[
            "total_response_time_seconds"
        ] += (
            answer.response_time_seconds
            or 0
        )

        if not answer.is_answered:
            stats[
                "unanswered_count"
            ] += 1

        elif answer.is_correct:
            stats[
                "correct_count"
            ] += 1

        else:
            stats[
                "wrong_count"
            ] += 1

    result: list[
        dict[str, Any]
    ] = []

    for stats in arguments.values():
        stats[
            "accuracy_percentage"
        ] = _percentage(
            stats[
                "correct_count"
            ],
            stats[
                "total_questions"
            ],
        )

        result.append(
            stats
        )

    return sorted(
        result,
        key=lambda item: (
            item[
                "accuracy_percentage"
            ],
            -item[
                "total_questions"
            ],
            item[
                "argument"
            ].casefold(),
        ),
    )


def get_student_question_statistics(
    db: Session,
    user_id: int,
    *,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    argument: str | None = None,
) -> list[dict[str, Any]]:
    query = _base_answer_query(
        db,
        user_id,
    )

    query = _apply_attempt_filters(
        query,
        department=department,
        course=course,
        subject=subject,
    )

    argument = _normalize_filter(
        argument
    )

    if argument is not None:
        query = query.filter(
            func.lower(
                QuizAttemptAnswer.argument
            ) == argument.lower()
        )

    rows = (
        query
        .order_by(
            QuizAttemptAnswer.id.asc()
        )
        .all()
    )

    questions: dict[
        tuple[
            str,
            str,
            str,
            str,
        ],
        dict[str, Any],
    ] = {}

    for answer in rows:
        attempt = answer.attempt

        key = (
            attempt.department,
            attempt.course,
            attempt.subject,
            answer.question_id,
        )

        if key not in questions:
            questions[
                key
            ] = {
                "department":
                    attempt.department,
                "course":
                    attempt.course,
                "subject":
                    attempt.subject,
                "argument":
                    answer.argument,
                "question_id":
                    answer.question_id,
                "question_text":
                    answer.question_text,
                "options":
                    answer.options_snapshot
                    or [],
                "correct_option_id":
                    answer.correct_option_id,
                "correct_option_text":
                    answer.correct_option_text,
                "formal_explanation":
                    answer.formal_explanation,
                "informal_explanation":
                    answer.informal_explanation,
                "correct_answer_explanation":
                    answer.correct_answer_explanation,
                "times_seen":
                    0,
                "correct_count":
                    0,
                "wrong_count":
                    0,
                "unanswered_count":
                    0,
                "total_response_time_seconds":
                    0,
                "last_is_correct":
                    None,
                "last_selected_option_id":
                    None,
                "last_selected_option_text":
                    None,
                "last_selected_answer_explanation":
                    None,
            }

        stats = questions[
            key
        ]

        stats[
            "times_seen"
        ] += 1

        stats[
            "total_response_time_seconds"
        ] += (
            answer.response_time_seconds
            or 0
        )

        if not answer.is_answered:
            stats[
                "unanswered_count"
            ] += 1

        elif answer.is_correct:
            stats[
                "correct_count"
            ] += 1

        else:
            stats[
                "wrong_count"
            ] += 1

        stats[
            "last_is_correct"
        ] = answer.is_correct

        stats[
            "last_selected_option_id"
        ] = (
            answer.selected_option_id
        )

        stats[
            "last_selected_option_text"
        ] = (
            answer.selected_option_text
        )

        stats[
            "last_selected_answer_explanation"
        ] = (
            answer.selected_answer_explanation
        )

    result: list[
        dict[str, Any]
    ] = []

    for stats in questions.values():
        stats[
            "accuracy_percentage"
        ] = _percentage(
            stats[
                "correct_count"
            ],
            stats[
                "times_seen"
            ],
        )

        if (
            stats[
                "times_seen"
            ]
            > 0
        ):
            stats[
                "average_response_time_seconds"
            ] = round(
                stats[
                    "total_response_time_seconds"
                ]
                / stats[
                    "times_seen"
                ],
                2,
            )
        else:
            stats[
                "average_response_time_seconds"
            ] = 0.0

        result.append(
            stats
        )

    return sorted(
        result,
        key=lambda item: (
            item[
                "accuracy_percentage"
            ],
            -item[
                "times_seen"
            ],
            str(
                item[
                    "question_id"
                ]
            ),
        ),
    )


def get_student_weak_arguments(
    db: Session,
    user_id: int,
    *,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    maximum_accuracy: float = 70.0,
    minimum_answers: int = 1,
) -> list[dict[str, Any]]:
    maximum_accuracy = max(
        0.0,
        min(
            maximum_accuracy,
            100.0,
        ),
    )

    minimum_answers = max(
        1,
        minimum_answers,
    )

    statistics = (
        get_student_argument_statistics(
            db,
            user_id,
            department=department,
            course=course,
            subject=subject,
        )
    )

    result: list[
        dict[str, Any]
    ] = []

    for stats in statistics:
        answered = (
            stats[
                "correct_count"
            ]
            + stats[
                "wrong_count"
            ]
        )

        if answered < minimum_answers:
            continue

        if (
            stats[
                "accuracy_percentage"
            ]
            >= maximum_accuracy
        ):
            continue

        result.append(
            stats
        )

    return sorted(
        result,
        key=lambda item: (
            item[
                "accuracy_percentage"
            ],
            -item[
                "wrong_count"
            ],
            item[
                "argument"
            ].casefold(),
        ),
    )


def get_student_review_questions(
    db: Session,
    user_id: int,
    *,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    argument: str | None = None,
    include_correct: bool = False,
) -> list[dict[str, Any]]:
    statistics = (
        get_student_question_statistics(
            db,
            user_id,
            department=department,
            course=course,
            subject=subject,
            argument=argument,
        )
    )

    result: list[
        dict[str, Any]
    ] = []

    for stats in statistics:
        needs_review = (
            stats[
                "wrong_count"
            ] > 0
            or stats[
                "unanswered_count"
            ] > 0
        )

        if (
            not include_correct
            and not needs_review
        ):
            continue

        result.append(
            {
                **stats,
                "needs_review":
                    needs_review,
            }
        )

    return sorted(
        result,
        key=lambda item: (
            not item[
                "needs_review"
            ],
            item[
                "accuracy_percentage"
            ],
            -item[
                "wrong_count"
            ],
            str(
                item[
                    "question_id"
                ]
            ),
        ),
    )


def get_student_learning_profile(
    db: Session,
    user_id: int,
    *,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
) -> dict[str, Any]:
    overall = (
        get_student_overall_statistics(
            db,
            user_id,
        )
    )

    subjects = (
        get_student_subject_statistics(
            db,
            user_id,
        )
    )

    arguments = (
        get_student_argument_statistics(
            db,
            user_id,
            department=department,
            course=course,
            subject=subject,
        )
    )

    weak_arguments = (
        get_student_weak_arguments(
            db,
            user_id,
            department=department,
            course=course,
            subject=subject,
        )
    )

    review_questions = (
        get_student_review_questions(
            db,
            user_id,
            department=department,
            course=course,
            subject=subject,
        )
    )

    return {
        "overall":
            overall,
        "subjects":
            subjects,
        "arguments":
            arguments,
        "weak_arguments":
            weak_arguments,
        "review_questions":
            review_questions,
    }