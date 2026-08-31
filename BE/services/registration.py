from datetime import (
    date,
    datetime,
)

from zoneinfo import ZoneInfo


ROME_TIMEZONE = ZoneInfo(
    "Europe/Rome",
)


def get_registration_date() -> date:
    return datetime.now(
        ROME_TIMEZONE,
    ).date()


def calculate_age(
    date_of_birth: date,
    current_date: date | None = None,
) -> int:
    today = (
        current_date
        if current_date is not None
        else get_registration_date()
    )

    return (
        today.year
        - date_of_birth.year
        - (
            (
                today.month,
                today.day,
            )
            <
            (
                date_of_birth.month,
                date_of_birth.day,
            )
        )
    )


def validate_registration_age(
    date_of_birth: date,
    minimum_age: int,
) -> int:
    today = (
        get_registration_date()
    )

    if date_of_birth > today:
        raise ValueError(
            "La data di nascita "
            "non può essere futura."
        )

    age = calculate_age(
        date_of_birth,
        today,
    )

    if age < minimum_age:
        raise ValueError(
            "Devi avere almeno "
            f"{minimum_age} anni "
            "per creare un account "
            "StudentLab."
        )

    return age


def validate_policy_acceptance(
    *,
    policy_version: str,
    current_policy_version: str,
    privacy_acknowledged: bool,
    terms_accepted: bool,
) -> None:
    normalized_version = (
        policy_version
        .strip()
    )

    if (
        normalized_version
        != current_policy_version
    ):
        raise ValueError(
            "La versione della Policy "
            "non è aggiornata."
        )

    if not privacy_acknowledged:
        raise ValueError(
            "È necessario dichiarare "
            "di aver preso visione "
            "dell'Informativa Privacy."
        )

    if not terms_accepted:
        raise ValueError(
            "È necessario accettare "
            "la Policy di utilizzo "
            "di StudentLab."
        )