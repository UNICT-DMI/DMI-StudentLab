from typing import Any

from pydantic import (
    BaseModel,
    Field,
    field_validator,
    model_validator,
)


class QuestionMetadata(BaseModel):
    university: str
    argoment: str
    teacher: list[str] = Field(default_factory=list)
    year_of_validity: str = "attuale"

    @field_validator(
        "university",
        "argoment",
        "year_of_validity",
    )
    @classmethod
    def validate_required_text(
        cls,
        value: str,
    ) -> str:
        value = value.strip()

        if not value:
            raise ValueError(
                "Il valore non può essere vuoto."
            )

        return value

    @field_validator(
        "teacher",
    )
    @classmethod
    def validate_teachers(
        cls,
        value: list[str],
    ) -> list[str]:
        result = []

        for teacher in value:
            teacher = teacher.strip()

            if not teacher:
                continue

            if teacher not in result:
                result.append(
                    teacher
                )

        return result


class QuestionMetadataUpdate(BaseModel):
    university: str | None = None
    argoment: str | None = None
    teacher: list[str] | None = None
    year_of_validity: str | None = None


class QuestionOption(BaseModel):
    id: str
    text: str

    @field_validator(
        "id",
        "text",
    )
    @classmethod
    def validate_text(
        cls,
        value: str,
    ) -> str:
        value = value.strip()

        if not value:
            raise ValueError(
                "Il valore non può essere vuoto."
            )

        return value


class QuestionAttachment(BaseModel):
    id: str | None = None
    type: str
    original_name: str
    mime_type: str
    stored_name: str

    @field_validator(
        "type",
    )
    @classmethod
    def validate_type(
        cls,
        value: str,
    ) -> str:
        value = value.strip().lower()

        if value not in {
            "image",
            "document",
        }:
            raise ValueError(
                "Tipo di allegato non valido."
            )

        return value

    @field_validator(
        "original_name",
        "mime_type",
        "stored_name",
    )
    @classmethod
    def validate_text(
        cls,
        value: str,
    ) -> str:
        value = value.strip()

        if not value:
            raise ValueError(
                "Il valore non può essere vuoto."
            )

        return value


class QuestionCreate(BaseModel):
    estimed_time: int = Field(
        ge=1,
    )

    metadata: QuestionMetadata

    text: str

    attachments: list[
        QuestionAttachment
    ] = Field(
        default_factory=list,
    )

    option: list[QuestionOption] = Field(
        min_length=2,
    )

    id_correct: str

    formal_explanation: str

    informal_explanation: str

    question_response_explanation: dict[
        str,
        str,
    ]

    @field_validator(
        "text",
        "id_correct",
        "formal_explanation",
        "informal_explanation",
    )
    @classmethod
    def validate_required_text(
        cls,
        value: str,
    ) -> str:
        value = value.strip()

        if not value:
            raise ValueError(
                "Il valore non può essere vuoto."
            )

        return value

    @model_validator(
        mode="after",
    )
    def validate_question(
        self,
    ):
        option_ids = [
            option.id
            for option in self.option
        ]

        if len(option_ids) != len(
            set(option_ids)
        ):
            raise ValueError(
                "Gli ID delle opzioni devono essere univoci."
            )

        if self.id_correct not in option_ids:
            raise ValueError(
                "La risposta corretta deve corrispondere a una delle opzioni."
            )

        explanation_ids = set(
            self.question_response_explanation.keys()
        )

        option_id_set = set(
            option_ids
        )

        if explanation_ids != option_id_set:
            raise ValueError(
                "Deve essere presente una spiegazione per ogni opzione e soltanto per le opzioni esistenti."
            )

        for option_id, explanation in (
            self.question_response_explanation.items()
        ):
            explanation = explanation.strip()

            if not explanation:
                raise ValueError(
                    f"La spiegazione dell'opzione '{option_id}' non può essere vuota."
                )

            self.question_response_explanation[
                option_id
            ] = explanation

        return self


class QuestionUpdate(BaseModel):
    estimed_time: int | None = Field(
        default=None,
        ge=1,
    )

    metadata: QuestionMetadataUpdate | None = None

    text: str | None = None

    attachments: list[
        QuestionAttachment
    ] | None = None

    option: list[
        QuestionOption
    ] | None = None

    id_correct: str | None = None

    formal_explanation: str | None = None

    informal_explanation: str | None = None

    question_response_explanation: (
        dict[str, str] | None
    ) = None


class QuestionVisibilityUpdate(BaseModel):
    is_hidden: bool


class QuestionResponse(QuestionCreate):
    id_question: str
    is_hidden: bool = False
    is_active: bool = True


class QuestionImportResult(BaseModel):
    imported: int
    skipped: int
    total: int
    question_ids: list[str]


class QuestionManagementResponse(BaseModel):
    department: str
    course: str
    subject: str
    questions: list[
        dict[str, Any]
    ]