import json
import os
import re
import tempfile

from pathlib import Path
from typing import Any

from pydantic import ValidationError
from services.question_json_storage import read_question_json, write_question_json

from schemas.question import (
    QuestionCreate,
    QuestionUpdate,
)


DATA_ROOT = Path("data")
MAX_IMPORT_QUESTIONS = 1000


def _normalize_directory(
    value: str,
) -> str:
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Percorso non valido."
        )

    value = value.strip().lower()

    if not value:
        raise ValueError(
            "Percorso non valido."
        )

    if (
        "/" in value
        or "\\" in value
        or ".." in value
        or "\x00" in value
    ):
        raise ValueError(
            "Percorso non valido."
        )

    return value


def _normalize_subject(
    value: str,
) -> str:
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Materia non valida."
        )

    value = value.strip().lower()

    if not value:
        raise ValueError(
            "Materia non valida."
        )

    if (
        "/" in value
        or "\\" in value
        or ".." in value
        or "\x00" in value
    ):
        raise ValueError(
            "Materia non valida."
        )

    value = re.sub(
        r"[\s\-]+",
        "_",
        value,
    )

    value = re.sub(
        r"_+",
        "_",
        value,
    )

    value = value.strip(
        "_."
    )

    if not value:
        raise ValueError(
            "Materia non valida."
        )

    return value


def _question_file_path(
    department: str,
    course: str,
    subject: str,
) -> Path:
    department_slug = _normalize_directory(
        department
    )

    course_slug = _normalize_directory(
        course
    )

    subject_slug = _normalize_subject(
        subject
    )

    return (
        DATA_ROOT
        / department_slug
        / course_slug
        / "question"
        / f"{subject_slug}.json"
    )


def _read_questions(
    department: str,
    course: str,
    subject: str,
) -> list[dict[str, Any]]:
    path = _question_file_path(
        department,
        course,
        subject,
    )

    archived = read_question_json(path)
    if archived is not None:
        return archived

    if not path.exists():
        return []

    if not path.is_file():
        raise ValueError(
            "Archivio delle domande non disponibile."
        )

    try:
        with path.open(
            "r",
            encoding="utf-8",
        ) as file:
            data = json.load(
                file
            )

    except json.JSONDecodeError as exception:
        raise ValueError(
            "L'archivio delle domande non è valido."
        ) from exception

    except OSError as exception:
        raise ValueError(
            "Impossibile leggere le domande in questo momento."
        ) from exception

    if not isinstance(
        data,
        list,
    ):
        raise ValueError(
            "L'archivio delle domande non è valido."
        )

    return [
        question
        for question in data
        if isinstance(
            question,
            dict,
        )
    ]


def _write_questions(
    department: str,
    course: str,
    subject: str,
    questions: list[dict[str, Any]],
) -> None:
    path = _question_file_path(
        department,
        course,
        subject,
    )

    if write_question_json(path, questions):
        return

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    temporary_path: Path | None = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.stem}_",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:
            temporary_path = Path(
                temporary_file.name
            )

            json.dump(
                questions,
                temporary_file,
                ensure_ascii=False,
                indent=2,
            )

            temporary_file.flush()

            os.fsync(
                temporary_file.fileno()
            )

        os.replace(
            temporary_path,
            path,
        )

    except (
        OSError,
        TypeError,
        ValueError,
    ) as exception:
        if (
            temporary_path is not None
            and temporary_path.exists()
        ):
            try:
                temporary_path.unlink(
                    missing_ok=True
                )
            except OSError:
                pass

        raise ValueError(
            "Impossibile salvare le domande in questo momento."
        ) from exception


def _next_question_id(
    questions: list[dict[str, Any]],
) -> str:
    maximum = 0

    for question in questions:
        value = question.get(
            "id_question"
        )

        try:
            numeric_value = int(
                value
            )

        except (
            TypeError,
            ValueError,
        ):
            continue

        if numeric_value > 0:
            maximum = max(
                maximum,
                numeric_value,
            )

    return str(
        maximum + 1
    )


def _serialize_question(
    question_id: str,
    data: QuestionCreate,
    *,
    is_hidden: bool = False,
    is_active: bool = True,
) -> dict[str, Any]:
    serialized = data.model_dump()

    attachments = serialized.get(
        "attachments",
        [],
    )

    if not isinstance(
        attachments,
        list,
    ):
        attachments = []

    return {
        "id_question":
            str(
                question_id
            ),
        "estimed_time":
            str(
                serialized[
                    "estimed_time"
                ]
            ),
        "metadata":
            serialized[
                "metadata"
            ],
        "text":
            serialized[
                "text"
            ],
        "attachments":
            attachments,
        "option":
            serialized[
                "option"
            ],
        "id_correct":
            serialized[
                "id_correct"
            ],
        "formal_explanation":
            serialized[
                "formal_explanation"
            ],
        "informal_explanation":
            serialized[
                "informal_explanation"
            ],
        "question_response_explanation":
            serialized[
                "question_response_explanation"
            ],
        "is_hidden":
            bool(
                is_hidden
            ),
        "is_active":
            bool(
                is_active
            ),
    }


def _question_validation_data(
    question: dict[str, Any],
) -> dict[str, Any]:
    return {
        "estimed_time":
            question.get(
                "estimed_time"
            ),
        "metadata":
            question.get(
                "metadata"
            ),
        "text":
            question.get(
                "text"
            ),
        "attachments":
            question.get(
                "attachments",
                [],
            ),
        "option":
            question.get(
                "option"
            ),
        "id_correct":
            question.get(
                "id_correct"
            ),
        "formal_explanation":
            question.get(
                "formal_explanation"
            ),
        "informal_explanation":
            question.get(
                "informal_explanation"
            ),
        "question_response_explanation":
            question.get(
                "question_response_explanation"
            ),
    }



_ALLOWED_IMPORT_ATTACHMENT_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".pdf",
    ".txt",
    ".docx",
    ".pptx",
}


def _normalize_import_attachment_name(
    value: Any,
) -> str:
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Il nome dell'allegato non è valido."
        )

    name = value.strip()

    if (
        not name
        or name in {
            ".",
            "..",
        }
        or "/" in name
        or "\\" in name
        or "\x00" in name
        or "\r" in name
        or "\n" in name
    ):
        raise ValueError(
            "Il nome dell'allegato non è valido."
        )

    suffix = Path(
        name
    ).suffix.casefold()

    if (
        suffix
        not in _ALLOWED_IMPORT_ATTACHMENT_EXTENSIONS
    ):
        raise ValueError(
            "Il tipo di allegato indicato nel JSON non è supportato."
        )

    return name


def _import_attachment_names(
    raw_value: Any,
) -> list[str]:
    if raw_value is None:
        return []

    values: list[Any]

    if isinstance(
        raw_value,
        str,
    ):
        values = [
            raw_value
        ]
    elif isinstance(
        raw_value,
        list,
    ):
        values = raw_value
    else:
        raise ValueError(
            "Il campo 'attachments' deve contenere un nome file o una lista di nomi file."
        )

    result: list[str] = []
    seen: set[str] = set()

    for raw_item in values:
        if isinstance(
            raw_item,
            dict,
        ):
            raw_item = (
                raw_item.get(
                    "original_name"
                )
            )

        name = (
            _normalize_import_attachment_name(
                raw_item
            )
        )

        key = name.casefold()

        if key in seen:
            continue

        seen.add(
            key
        )

        result.append(
            name
        )

    return result


def _normalize_import_teacher(
    value: Any,
) -> list[str]:
    if value is None:
        return []

    if isinstance(
        value,
        str,
    ):
        normalized = value.strip()

        return (
            [
                normalized
            ]
            if normalized
            else []
        )

    if isinstance(
        value,
        list,
    ):
        result: list[str] = []

        for item in value:
            normalized = str(
                item
            ).strip()

            if (
                normalized
                and normalized
                not in result
            ):
                result.append(
                    normalized
                )

        return result

    raise ValueError(
        "Il campo docente della domanda non è valido."
    )


def _normalize_import_response_explanations(
    raw_value: Any,
    options: Any,
) -> dict[str, str]:
    option_ids: list[str] = []

    if isinstance(
        options,
        list,
    ):
        for option in options:
            if not isinstance(
                option,
                dict,
            ):
                continue

            option_id = str(
                option.get(
                    "id",
                    "",
                )
            ).strip()

            if (
                option_id
                and option_id
                not in option_ids
            ):
                option_ids.append(
                    option_id
                )

    if isinstance(
        raw_value,
        dict,
    ):
        return {
            str(
                key
            ).strip():
                str(
                    value
                ).strip()
            for key, value
            in raw_value.items()
            if str(
                key
            ).strip()
        }

    if isinstance(
        raw_value,
        str,
    ):
        explanation = raw_value.strip()

        if not explanation:
            return {}

        return {
            option_id:
                explanation
            for option_id
            in option_ids
        }

    return {}


def _normalize_import_question(
    raw_question: dict[str, Any],
    *,
    default_university: str | None,
) -> tuple[
    dict[str, Any],
    list[str],
]:
    normalized = dict(
        raw_question
    )

    metadata_raw = normalized.get(
        "metadata"
    )

    if not isinstance(
        metadata_raw,
        dict,
    ):
        raise ValueError(
            "I metadata della domanda non sono validi."
        )

    metadata = dict(
        metadata_raw
    )

    university = str(
        metadata.get(
            "university"
        )
        or default_university
        or ""
    ).strip()

    if not university:
        raise ValueError(
            "L'ateneo della materia non è disponibile."
        )

    metadata[
        "university"
    ] = university

    metadata[
        "teacher"
    ] = _normalize_import_teacher(
        metadata.get(
            "teacher"
        )
    )

    if not str(
        metadata.get(
            "year_of_validity",
            "",
        )
    ).strip():
        metadata[
            "year_of_validity"
        ] = "attuale"

    normalized[
        "metadata"
    ] = metadata

    attachments = (
        _import_attachment_names(
            normalized.get(
                "attachments"
            )
        )
    )

    normalized[
        "attachments"
    ] = []

    normalized[
        "question_response_explanation"
    ] = (
        _normalize_import_response_explanations(
            normalized.get(
                "question_response_explanation"
            ),
            normalized.get(
                "option"
            ),
        )
    )

    return (
        normalized,
        attachments,
    )

def _validation_error_message(
    exception: ValidationError,
) -> str:
    errors = exception.errors()

    if not errors:
        return (
            "I dati della domanda non sono validi."
        )

    first_error = errors[
        0
    ]

    location = first_error.get(
        "loc",
        (),
    )

    field_name = (
        str(
            location[
                -1
            ]
        )
        if location
        else "dato"
    )

    return (
        f"Il campo '{field_name}' della domanda non è valido."
    )


def _question_signature(
    question: dict[str, Any],
) -> tuple[str, str]:
    text = str(
        question.get(
            "text",
            "",
        )
    ).strip().casefold()

    metadata = question.get(
        "metadata",
        {},
    )

    argument = ""

    if isinstance(
        metadata,
        dict,
    ):
        argument = str(
            metadata.get(
                "argoment",
                "",
            )
        ).strip().casefold()

    return (
        argument,
        text,
    )


def get_questions_for_management(
    department: str,
    course: str,
    subject: str,
) -> list[dict[str, Any]]:
    return _read_questions(
        department,
        course,
        subject,
    )


def get_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    *,
    include_hidden: bool = True,
) -> dict[str, Any] | None:
    question_id = str(
        question_id
    ).strip()

    if not question_id:
        return None

    questions = _read_questions(
        department,
        course,
        subject,
    )

    for question in questions:
        if str(
            question.get(
                "id_question"
            )
        ) != question_id:
            continue

        if (
            not include_hidden
            and (
                bool(
                    question.get(
                        "is_hidden",
                        False,
                    )
                )
                or question.get(
                    "is_active",
                    True,
                )
                is False
            )
        ):
            return None

        return question

    return None


def create_question(
    department: str,
    course: str,
    subject: str,
    data: QuestionCreate,
) -> dict[str, Any]:
    questions = _read_questions(
        department,
        course,
        subject,
    )

    signature = (
        data.metadata.argoment
        .strip()
        .casefold(),
        data.text
        .strip()
        .casefold(),
    )

    existing_signatures = {
        _question_signature(
            question
        )
        for question in questions
    }

    if (
        signature
        in existing_signatures
    ):
        raise ValueError(
            "Una domanda identica è già presente nella materia."
        )

    question_id = _next_question_id(
        questions
    )

    question = _serialize_question(
        question_id,
        data,
    )

    questions.append(
        question
    )

    _write_questions(
        department,
        course,
        subject,
        questions,
    )

    return question


def update_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    data: QuestionUpdate,
    default_university: str | None = None,
) -> dict[str, Any]:
    question_id = str(
        question_id
    ).strip()

    if not question_id:
        raise ValueError(
            "Domanda non trovata."
        )

    questions = _read_questions(
        department,
        course,
        subject,
    )

    index: int | None = None

    for position, question in enumerate(
        questions
    ):
        if str(
            question.get(
                "id_question"
            )
        ) == question_id:
            index = position
            break

    if index is None:
        raise ValueError(
            "Domanda non trovata."
        )

    existing = questions[
        index
    ]

    merged = dict(
        existing
    )

    update_data = data.model_dump(
        exclude_unset=True,
        exclude_none=True,
    )

    metadata_update = update_data.pop(
        "metadata",
        None,
    )

    if metadata_update is not None:
        current_metadata = merged.get(
            "metadata",
            {},
        )

        if not isinstance(
            current_metadata,
            dict,
        ):
            current_metadata = {}

        current_metadata = dict(
            current_metadata
        )

        current_metadata.update(
            metadata_update
        )

        merged[
            "metadata"
        ] = current_metadata

    merged.update(
        update_data
    )

    # Compatibilità con domande esistenti che non avevano ancora l'ateneo.
    # L'origine è la materia validata dalla route, mai il profilo docente.
    metadata = merged.get("metadata")
    if isinstance(metadata, dict) and not str(metadata.get("university") or "").strip():
        if default_university:
            merged["metadata"] = {**metadata, "university": default_university}

    try:
        validated = QuestionCreate.model_validate(
            _question_validation_data(
                merged
            )
        )

    except ValidationError as exception:
        raise ValueError(
            _validation_error_message(
                exception
            )
        ) from exception

    new_signature = (
        validated.metadata.argoment
        .strip()
        .casefold(),
        validated.text
        .strip()
        .casefold(),
    )

    for position, question in enumerate(
        questions
    ):
        if position == index:
            continue

        if (
            _question_signature(
                question
            )
            == new_signature
        ):
            raise ValueError(
                "Una domanda identica è già presente nella materia."
            )

    questions[
        index
    ] = _serialize_question(
        str(
            existing.get(
                "id_question"
            )
        ),
        validated,
        is_hidden=bool(
            existing.get(
                "is_hidden",
                False,
            )
        ),
        is_active=bool(
            existing.get(
                "is_active",
                True,
            )
        ),
    )

    _write_questions(
        department,
        course,
        subject,
        questions,
    )

    return questions[
        index
    ]


def hide_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
) -> dict[str, Any]:
    question_id = str(
        question_id
    ).strip()

    questions = _read_questions(
        department,
        course,
        subject,
    )

    for question in questions:
        if str(
            question.get(
                "id_question"
            )
        ) != question_id:
            continue

        if not bool(
            question.get(
                "is_hidden",
                False,
            )
        ):
            question[
                "is_hidden"
            ] = True

            _write_questions(
                department,
                course,
                subject,
                questions,
            )

        return question

    raise ValueError(
        "Domanda non trovata."
    )


def restore_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
) -> dict[str, Any]:
    question_id = str(
        question_id
    ).strip()

    questions = _read_questions(
        department,
        course,
        subject,
    )

    for question in questions:
        if str(
            question.get(
                "id_question"
            )
        ) != question_id:
            continue

        if bool(
            question.get(
                "is_hidden",
                False,
            )
        ):
            question[
                "is_hidden"
            ] = False

            _write_questions(
                department,
                course,
                subject,
                questions,
            )

        return question

    raise ValueError(
        "Domanda non trovata."
    )


def set_question_active_status(
    department: str,
    course: str,
    subject: str,
    question_id: str,
    is_active: bool,
) -> dict[str, Any]:
    question_id = str(
        question_id
    ).strip()

    questions = _read_questions(
        department,
        course,
        subject,
    )

    for question in questions:
        if str(
            question.get(
                "id_question"
            )
        ) != question_id:
            continue

        target_status = bool(
            is_active
        )

        if (
            bool(
                question.get(
                    "is_active",
                    True,
                )
            )
            != target_status
        ):
            question[
                "is_active"
            ] = target_status

            _write_questions(
                department,
                course,
                subject,
                questions,
            )

        return question

    raise ValueError(
        "Domanda non trovata."
    )


def delete_question(
    department: str,
    course: str,
    subject: str,
    question_id: str,
) -> bool:
    question_id = str(
        question_id
    ).strip()

    questions = _read_questions(
        department,
        course,
        subject,
    )

    filtered = [
        question
        for question in questions
        if str(
            question.get(
                "id_question"
            )
        ) != question_id
    ]

    if (
        len(
            filtered
        )
        == len(
            questions
        )
    ):
        raise ValueError(
            "Domanda non trovata."
        )

    _write_questions(
        department,
        course,
        subject,
        filtered,
    )

    return True


def import_questions_from_json(
    department: str,
    course: str,
    subject: str,
    raw_questions: list[dict[str, Any]],
    *,
    skip_duplicates: bool = True,
    default_university: str | None = None,
) -> dict[str, Any]:
    if not isinstance(
        raw_questions,
        list,
    ):
        raise ValueError(
            "Il file deve contenere una lista di domande."
        )

    if not raw_questions:
        raise ValueError(
            "Il file non contiene domande da importare."
        )

    if (
        len(
            raw_questions
        )
        > MAX_IMPORT_QUESTIONS
    ):
        raise ValueError(
            f"Puoi importare al massimo {MAX_IMPORT_QUESTIONS} domande per volta."
        )

    existing_questions = _read_questions(
        department,
        course,
        subject,
    )

    existing_signatures = {
        _question_signature(
            question
        )
        for question in existing_questions
    }

    batch_signatures: set[
        tuple[str, str]
    ] = set()

    validated_questions: list[
        QuestionCreate
    ] = []

    validated_attachment_names: list[
        list[str]
    ] = []

    skipped = 0

    for index, raw_question in enumerate(
        raw_questions,
        start=1,
    ):
        if not isinstance(
            raw_question,
            dict,
        ):
            raise ValueError(
                f"La domanda {index} non è valida."
            )

        try:
            (
                normalized_question,
                attachment_names,
            ) = _normalize_import_question(
                raw_question,
                default_university=default_university,
            )

            validated = QuestionCreate.model_validate(
                _question_validation_data(
                    normalized_question
                )
            )

        except (
            ValidationError,
            ValueError,
        ) as exception:
            if isinstance(
                exception,
                ValidationError,
            ):
                message = (
                    _validation_error_message(
                        exception
                    )
                )
            else:
                message = str(
                    exception
                ).strip()

            raise ValueError(
                f"Domanda {index}: "
                f"{message}"
            ) from exception

        signature = (
            validated.metadata.argoment
            .strip()
            .casefold(),
            validated.text
            .strip()
            .casefold(),
        )

        duplicate = (
            signature
            in existing_signatures
            or signature
            in batch_signatures
        )

        if duplicate:
            if skip_duplicates:
                skipped += 1
                continue

            raise ValueError(
                f"La domanda {index} è già presente."
            )

        batch_signatures.add(
            signature
        )

        validated_questions.append(
            validated
        )

        validated_attachment_names.append(
            attachment_names
        )

    question_ids: list[str] = []

    attachment_plan: list[
        dict[str, Any]
    ] = []

    next_id = int(
        _next_question_id(
            existing_questions
        )
    )

    for position, validated in enumerate(
        validated_questions
    ):
        question_id = str(
            next_id
        )

        existing_questions.append(
            _serialize_question(
                question_id,
                validated,
            )
        )

        question_ids.append(
            question_id
        )

        names = (
            validated_attachment_names[
                position
            ]
        )

        if names:
            attachment_plan.append(
                {
                    "question_id":
                        question_id,
                    "files":
                        names,
                }
            )

        next_id += 1

    if validated_questions:
        _write_questions(
            department,
            course,
            subject,
            existing_questions,
        )

    return {
        "imported":
            len(
                validated_questions
            ),
        "skipped":
            skipped,
        "total":
            len(
                raw_questions
            ),
        "question_ids":
            question_ids,
    }
