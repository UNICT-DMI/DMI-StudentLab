from typing import Literal

from pydantic import (
    BaseModel,
    Field,
    field_validator,
    model_validator,
)


class ContactUserRequest(
    BaseModel,
):
    request_type: Literal[
        "general",
        "help",
        "private_lesson",
    ]

    subject_id: int | None = Field(
        default=None,
        gt=0,
    )

    subject: str = Field(
        min_length=1,
        max_length=160,
    )

    message: str = Field(
        min_length=1,
        max_length=5000,
    )

    @field_validator(
        "subject",
    )
    @classmethod
    def normalize_subject(
        cls,
        value: str,
    ) -> str:
        normalized = " ".join(
            value.strip().split()
        )

        if not normalized:
            raise ValueError(
                "Inserisci l'oggetto della richiesta.",
            )

        if "\r" in value or "\n" in value:
            raise ValueError(
                "L'oggetto non è valido.",
            )

        return normalized

    @field_validator(
        "message",
    )
    @classmethod
    def normalize_message(
        cls,
        value: str,
    ) -> str:
        normalized = value.strip()

        if not normalized:
            raise ValueError(
                "Inserisci il messaggio.",
            )

        return normalized

    @model_validator(
        mode="after",
    )
    def validate_subject_requirement(
        self,
    ):
        if (
            self.request_type
            in {
                "help",
                "private_lesson",
            }
            and self.subject_id is None
        ):
            raise ValueError(
                "Seleziona una materia.",
            )

        return self


class ContactUserResponse(
    BaseModel,
):
    success: bool
    message: str