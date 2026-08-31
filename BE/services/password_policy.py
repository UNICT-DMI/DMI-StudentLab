import re


def validate_password_policy(password: str) -> str:
    if len(password) < 8:
        raise ValueError("La password deve contenere almeno 8 caratteri.")
    if re.search(r"[a-z]", password) is None:
        raise ValueError("La password deve contenere almeno una lettera minuscola.")
    if re.search(r"[A-Z]", password) is None:
        raise ValueError("La password deve contenere almeno una lettera maiuscola.")
    if re.search(r"[0-9]", password) is None:
        raise ValueError("La password deve contenere almeno un numero.")
    if re.search(r"[^A-Za-z0-9]", password) is None:
        raise ValueError("La password deve contenere almeno un carattere speciale.")
    return password
