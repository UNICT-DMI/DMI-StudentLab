import json
import random
import re
from copy import deepcopy
from pathlib import Path
from typing import Any


DATA_ROOT = Path("data")


def _normalize_directory(value: str) -> str:
    return value.strip().lower()


def _normalize_subject(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[\s\-]+", "_", value)
    value = re.sub(r"_+", "_", value)
    return value.strip("_")


def _question_directory(
    department: str,
    course: str,
) -> Path:
    department_slug = _normalize_directory(department)
    course_slug = _normalize_directory(course)

    return (
        DATA_ROOT
        / department_slug
        / course_slug
        / "question"
    )


def _question_file_path(
    department: str,
    course: str,
    subject: str,
) -> Path:
    subject_slug = _normalize_subject(subject)

    return (
        _question_directory(
            department=department,
            course=course,
        )
        / f"{subject_slug}.json"
    )


def load_questions(
    department: str,
    course: str,
    subject: str,
) -> list[dict[str, Any]]:
    path = _question_file_path(
        department=department,
        course=course,
        subject=subject,
    )

    if not path.is_file():
        return []

    try:
        with path.open("r", encoding="utf-8") as file:
            data = json.load(file)
    except (OSError, json.JSONDecodeError):
        return []

    if not isinstance(data, list):
        return []

    return [
        question
        for question in data
        if isinstance(question, dict)
    ]


def _is_question_available(
    question: dict[str, Any],
) -> bool:
    if question.get("is_hidden", False):
        return False

    if question.get("is_active", True) is False:
        return False

    return True


def _normalize_arguments(
    selected_arguments: list[str] | None,
) -> set[str]:
    if not selected_arguments:
        return set()

    return {
        argument.strip().casefold()
        for argument in selected_arguments
        if isinstance(argument, str) and argument.strip()
    }


def _filter_by_arguments(
    questions: list[dict[str, Any]],
    selected_arguments: list[str] | None = None,
) -> list[dict[str, Any]]:
    selected = _normalize_arguments(selected_arguments)

    if not selected:
        return list(questions)

    result = []

    for question in questions:
        metadata = question.get("metadata", {})

        if not isinstance(metadata, dict):
            continue

        argument = metadata.get("argoment")

        if not isinstance(argument, str):
            continue

        if argument.strip().casefold() in selected:
            result.append(question)

    return result


def get_available_questions(
    department: str,
    course: str,
    subject: str,
    selected_arguments: list[str] | None = None,
) -> list[dict[str, Any]]:
    all_questions = load_questions(
        department=department,
        course=course,
        subject=subject,
    )

    available_questions = [
        question
        for question in all_questions
        if _is_question_available(question)
    ]

    return _filter_by_arguments(
        questions=available_questions,
        selected_arguments=selected_arguments,
    )


def shuffle_filter(
    department: str,
    course: str,
    subject: str,
    selected_arguments: list[str] | None = None,
    number_of_questions: int | None = None,
) -> list[dict[str, Any]]:
    filtered_questions = get_available_questions(
        department=department,
        course=course,
        subject=subject,
        selected_arguments=selected_arguments,
    )

    result = deepcopy(filtered_questions)

    random.shuffle(result)

    if number_of_questions is not None:
        number_of_questions = max(
            0,
            min(
                number_of_questions,
                len(result),
            ),
        )

        result = result[:number_of_questions]

    for question in result:
        options = question.get("option")

        if isinstance(options, list):
            random.shuffle(options)

    return result


def find_question(
    id_question: str,
    department: str,
    course: str,
    subject: str,
    include_hidden: bool = False,
) -> dict[str, Any] | None:
    all_questions = load_questions(
        department=department,
        course=course,
        subject=subject,
    )

    for question in all_questions:
        if str(question.get("id_question")) != str(id_question):
            continue

        if (
            not include_hidden
            and not _is_question_available(question)
        ):
            return None

        return question

    return None


def validate_answer(
    id_question: str,
    id_choice: str,
    department: str,
    course: str,
    subject: str,
) -> dict[str, Any] | None:
    question = find_question(
        id_question=id_question,
        department=department,
        course=course,
        subject=subject,
    )

    if question is None:
        return None

    correct_option_id = question.get("id_correct")

    if correct_option_id is None:
        return None

    selected_option_id = str(id_choice).strip()
    correct_option_id = str(correct_option_id).strip()

    options = question.get("option", [])

    valid_option_ids = {
        str(option.get("id")).strip()
        for option in options
        if isinstance(option, dict)
        and option.get("id") is not None
    }

    if selected_option_id not in valid_option_ids:
        return None

    response_explanations = question.get(
        "question_response_explanation",
        {},
    )

    if not isinstance(response_explanations, dict):
        response_explanations = {}

    metadata = question.get("metadata", {})

    if not isinstance(metadata, dict):
        metadata = {}

    return {
        "question_id": str(question.get("id_question")),
        "argument": metadata.get("argoment"),
        "selected_option_id": selected_option_id,
        "correct_option_id": correct_option_id,
        "is_correct": selected_option_id == correct_option_id,
        "formal_explanation": question.get(
            "formal_explanation"
        ),
        "informal_explanation": question.get(
            "informal_explanation"
        ),
        "selected_answer_explanation": (
            response_explanations.get(
                selected_option_id
            )
        ),
        "correct_answer_explanation": (
            response_explanations.get(
                correct_option_id
            )
        ),
        "answer_explanations": response_explanations,
    }


def arguments(
    department: str,
    course: str,
    subject: str,
) -> list[str]:
    all_questions = load_questions(
        department=department,
        course=course,
        subject=subject,
    )

    result: set[str] = set()

    for question in all_questions:
        if not _is_question_available(question):
            continue

        metadata = question.get("metadata", {})

        if not isinstance(metadata, dict):
            continue

        argument = metadata.get("argoment")

        if isinstance(argument, str) and argument.strip():
            result.add(argument.strip())

    return sorted(
        result,
        key=str.casefold,
    )


def question_count(
    department: str,
    course: str,
    subject: str,
    selected_arguments: list[str] | None = None,
) -> int:
    return len(
        get_available_questions(
            department=department,
            course=course,
            subject=subject,
            selected_arguments=selected_arguments,
        )
    )


def estimated_time(
    department: str,
    course: str,
    subject: str,
    selected_arguments: list[str] | None = None,
    number_of_questions: int | None = None,
) -> int | None:
    questions = get_available_questions(
        department=department,
        course=course,
        subject=subject,
        selected_arguments=selected_arguments,
    )

    if number_of_questions is not None:
        number_of_questions = max(
            0,
            min(
                number_of_questions,
                len(questions),
            ),
        )

        questions = questions[:number_of_questions]

    total_seconds = 0
    has_estimated_time = False

    for question in questions:
        value = question.get("estimed_time")

        if value is None:
            continue

        try:
            seconds = int(value)
        except (TypeError, ValueError):
            continue

        if seconds < 0:
            continue

        total_seconds += seconds
        has_estimated_time = True

    if not has_estimated_time:
        return None

    return total_seconds


def quiz_availability(
    department: str,
    course: str,
    subject: str,
    selected_arguments: list[str] | None = None,
) -> dict[str, Any]:
    available_questions = get_available_questions(
        department=department,
        course=course,
        subject=subject,
        selected_arguments=selected_arguments,
    )

    total_estimated_time = estimated_time(
        department=department,
        course=course,
        subject=subject,
        selected_arguments=selected_arguments,
    )

    return {
        "available_questions": len(available_questions),
        "max_questions": len(available_questions),
        "estimated_total_time": total_estimated_time,
    }


def subjects(
    department: str,
    course: str,
) -> list[str]:
    path = _question_directory(
        department=department,
        course=course,
    )

    if not path.is_dir():
        return []

    result: list[str] = []

    for file_path in path.glob("*.json"):
        if not file_path.is_file():
            continue

        try:
            with file_path.open(
                "r",
                encoding="utf-8",
            ) as file:
                data = json.load(file)
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(data, list):
            continue

        subject = (
            file_path
            .stem
            .replace("_", " ")
            .strip()
        )

        if subject:
            result.append(subject)

    return sorted(
        set(result),
        key=str.casefold,
    )