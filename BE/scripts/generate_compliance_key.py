import argparse
import base64
import os
import stat
import sys

from cryptography.hazmat.primitives import (
    serialization,
)

from cryptography.hazmat.primitives.asymmetric.x25519 import (
    X25519PrivateKey,
)


def raw_bytes(key):
    if isinstance(
        key,
        X25519PrivateKey,
    ):
        return key.private_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PrivateFormat.Raw,
            encryption_algorithm=serialization.NoEncryption(),
        )

    return key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )


def write_private_key(path, value):
    if os.path.exists(path):
        print(
            f"Il file {path} esiste già: non viene sovrascritto.",
            file=sys.stderr,
        )

        return False

    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL,
        stat.S_IRUSR | stat.S_IWUSR,
    )

    with os.fdopen(
        descriptor,
        "w",
    ) as handle:
        handle.write(value + "\n")

    return True


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Genera la coppia di chiavi X25519 per la disclosure di "
            "conformità dei messaggi privati."
        ),
    )

    parser.add_argument(
        "--key-id",
        required=True,
        help="Identificativo della chiave, es. compliance-2026-08.",
    )

    parser.add_argument(
        "--private-key-out",
        default="compliance_private_key.txt",
        help=(
            "File in cui scrivere la chiave privata: va spostato subito "
            "fuori dal server e dal repository."
        ),
    )

    arguments = parser.parse_args()

    private_key = X25519PrivateKey.generate()

    private_value = base64.b64encode(
        raw_bytes(
            private_key,
        ),
    ).decode("ascii")

    public_value = base64.b64encode(
        raw_bytes(
            private_key.public_key(),
        ),
    ).decode("ascii")

    if not write_private_key(
        arguments.private_key_out,
        private_value,
    ):
        return 1

    print("Chiave di conformità generata.")
    print()
    print("Variabili da impostare sul backend:")
    print()
    print(f"StudentLab_COMPLIANCE_KEY_ID={arguments.key_id}")
    print("StudentLab_COMPLIANCE_KEY_ALGO=x25519")
    print(f"StudentLab_COMPLIANCE_PUBLIC_KEY={public_value}")
    print()
    print(
        f"Chiave privata scritta in {arguments.private_key_out} con "
        "permessi 600.",
    )
    print(
        "Spostala offline (idealmente divisa in quote fra più persone) e "
        "cancellala dal server: senza di essa nessun messaggio segnalato "
        "sarà leggibile su richiesta dell’autorità, con essa chi la "
        "detiene può decifrare tutti i messaggi privati.",
    )
    print(
        "Cambiare questa chiave non è retroattivo: i messaggi già inviati "
        "restano cifrati verso la chiave precedente.",
    )

    return 0


if __name__ == "__main__":
    sys.exit(
        main(),
    )
