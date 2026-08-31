from __future__ import annotations

from dataclasses import (
    dataclass,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
)


@dataclass(
    frozen=True,
)
class FlowStepSpec:
    title: str
    file_candidates: tuple[str, ...]
    function_candidates: tuple[str, ...] = ()
    layer: str = ""
    relation: str = "NEXT"
    context: str = ""
    security_critical: bool = False


@dataclass(
    frozen=True,
)
class FlowSpec:
    id: str
    name: str
    description: str
    risk: str
    steps: tuple[FlowStepSpec, ...]


FLOW_REGISTRY: tuple[
    FlowSpec,
    ...,
] = (
    FlowSpec(
        id="login",
        name="Login",
        description=(
            "Autenticazione utente dalla UI Flutter "
            "fino alla verifica credenziali e alla "
            "creazione del token di accesso."
        ),
        risk="critical",
        steps=(
            FlowStepSpec(
                title="UI login",
                file_candidates=(
                    "fe/lib/social/auth/login_page.dart",
                    "fe/lib/social/auth/login.dart",
                    "fe/lib/auth/login_page.dart",
                ),
                function_candidates=(
                    "_login",
                    "login",
                    "_submit",
                    "_handleLogin",
                ),
                layer="Frontend",
                relation="TRIGGERS",
                context=(
                    "L'utente invia email e password."
                ),
            ),
            FlowStepSpec(
                title="POST /login",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_login",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Endpoint pubblico di autenticazione."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Verifica credenziali",
                file_candidates=(
                    "BE/services/auth.py",
                ),
                function_candidates=(
                    "authenticate_user",
                ),
                layer="Backend Service",
                relation="CALLS",
                context=(
                    "Normalizza l'email, legge l'utente "
                    "e verifica la password."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Creazione access token",
                file_candidates=(
                    "BE/services/auth.py",
                ),
                function_candidates=(
                    "create_access_token",
                ),
                layer="Backend Service",
                relation="RETURNS",
                context=(
                    "Genera il JWT usato dalla sessione."
                ),
                security_critical=True,
            ),
        ),
    ),
    FlowSpec(
        id="email-verification",
        name="Email Verification",
        description=(
            "Verifica del codice email dopo la "
            "registrazione e rilascio del token."
        ),
        risk="critical",
        steps=(
            FlowStepSpec(
                title="Pagina verifica email",
                file_candidates=(
                    "fe/lib/social/auth/email_verification_page.dart",
                ),
                function_candidates=(
                    "_verifyCode",
                    "_verify",
                    "_submitCode",
                    "_submit",
                ),
                layer="Frontend",
                relation="TRIGGERS",
                context=(
                    "L'utente inserisce il codice ricevuto."
                ),
            ),
            FlowStepSpec(
                title="POST /auth/email/verify",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_verify_email",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Riceve registration_id e codice."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Verifica codice",
                file_candidates=(
                    "BE/services/auth.py",
                ),
                function_candidates=(
                    "verify_user_email",
                ),
                layer="Backend Service",
                relation="UPDATES",
                context=(
                    "Valida codice, scadenza e tentativi "
                    "e marca l'email come verificata."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Creazione token",
                file_candidates=(
                    "BE/services/auth.py",
                ),
                function_candidates=(
                    "create_access_token",
                ),
                layer="Backend Service",
                relation="RETURNS",
                context=(
                    "Rilascia la sessione autenticata."
                ),
                security_critical=True,
            ),
        ),
    ),
    FlowSpec(
        id="teacher-verification",
        name="Teacher Verification",
        description=(
            "Moderazione manuale del ruolo docente "
            "da parte di creator/admin."
        ),
        risk="high",
        steps=(
            FlowStepSpec(
                title="Admin teacher moderation",
                file_candidates=(
                    "fe/lib/social/admin/admin_panel_page.dart",
                ),
                function_candidates=(
                    "_verifyTeacher",
                    "_openTeacherVerification",
                    "_loadPendingTeachers",
                ),
                layer="Frontend",
                relation="TRIGGERS",
                context=(
                    "Un amministratore approva o rifiuta "
                    "la verifica docente."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="PATCH teacher verification",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_admin_teacher_verification",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Endpoint protetto da get_admin_user."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Verify teacher",
                file_candidates=(
                    "BE/services/user.py",
                ),
                function_candidates=(
                    "verify_teacher",
                ),
                layer="Backend Service",
                relation="UPDATES",
                context=(
                    "Aggiorna lo stato di verifica docente."
                ),
                security_critical=True,
            ),
        ),
    ),
    FlowSpec(
        id="group-material-upload",
        name="Group Material Upload",
        description=(
            "Preparazione, verifica e completamento "
            "dell'upload di un materiale di gruppo."
        ),
        risk="high",
        steps=(
            FlowStepSpec(
                title="Richiesta upload",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_group_material_upload_request",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Verifica gruppo e appartenenza."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Prepare group material",
                file_candidates=(
                    "BE/services/material.py",
                ),
                function_candidates=(
                    "prepare_group_material_upload",
                ),
                layer="Backend Service",
                relation="RETURNS",
                context=(
                    "Valida metadata, hash e pathname."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Verify upload",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_group_material_verify_upload",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Controlla la richiesta di upload."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Complete upload",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_group_material_complete",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Verifica Blob e crea il record materiale."
                ),
                security_critical=True,
            ),
        ),
    ),
    FlowSpec(
        id="teacher-material-upload",
        name="Teacher Material Upload",
        description=(
            "Upload di materiali da parte di un docente "
            "verificato e assegnato alla materia."
        ),
        risk="high",
        steps=(
            FlowStepSpec(
                title="Teacher upload request",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_teacher_material_upload_request",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Richiede docente verificato."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Prepare teacher material",
                file_candidates=(
                    "BE/services/teacher_material.py",
                ),
                function_candidates=(
                    "prepare_teacher_material_upload",
                ),
                layer="Backend Service",
                relation="RETURNS",
                context=(
                    "Valida assegnazione, metadata e hash."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Verify teacher upload",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_teacher_material_verify_upload",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Conferma i dati prima del completamento."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Complete teacher material",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_teacher_material_complete",
                ),
                layer="Backend API",
                relation="UPDATES",
                context=(
                    "Verifica Blob e salva il materiale."
                ),
                security_critical=True,
            ),
        ),
    ),
    FlowSpec(
        id="group-join-request",
        name="Group Join Request",
        description=(
            "Ingresso diretto nei gruppi pubblici "
            "oppure richiesta di accesso ai gruppi privati."
        ),
        risk="medium",
        steps=(
            FlowStepSpec(
                title="Request join group",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_request_join_group",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Determina se l'ingresso è diretto "
                    "o richiede approvazione."
                ),
            ),
            FlowStepSpec(
                title="Create join request",
                file_candidates=(
                    "BE/services/group.py",
                ),
                function_candidates=(
                    "create_group_join_request",
                ),
                layer="Backend Service",
                relation="UPDATES",
                context=(
                    "Salva la richiesta per un gruppo privato."
                ),
            ),
            FlowStepSpec(
                title="Accept join request",
                file_candidates=(
                    "BE/main.py",
                ),
                function_candidates=(
                    "api_accept_group_request",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Owner/admin accetta la richiesta."
                ),
                security_critical=True,
            ),
        ),
    ),
    FlowSpec(
        id="notifications",
        name="Notifications",
        description=(
            "Lettura e aggiornamento delle notifiche "
            "dell'utente autenticato."
        ),
        risk="medium",
        steps=(
            FlowStepSpec(
                title="Notification API",
                file_candidates=(
                    "BE/routes/notification.py",
                ),
                function_candidates=(
                    "get_notifications",
                    "api_notifications",
                    "list_notifications",
                ),
                layer="Backend API",
                relation="CALLS",
                context=(
                    "Espone notifiche e unread count."
                ),
            ),
            FlowStepSpec(
                title="Notification model",
                file_candidates=(
                    "BE/models/notification.py",
                ),
                layer="Database Model",
                relation="READS",
                context=(
                    "Persistenza delle notifiche."
                ),
            ),
        ),
    ),
    FlowSpec(
        id="report-moderation",
        name="Report Moderation",
        description=(
            "Gestione delle segnalazioni di utenti, "
            "gruppi e contenuti da parte della moderazione."
        ),
        risk="high",
        steps=(
            FlowStepSpec(
                title="Admin reports UI",
                file_candidates=(
                    "fe/lib/social/admin/admin_panel_page.dart",
                ),
                function_candidates=(
                    "_loadReports",
                    "_openReports",
                ),
                layer="Frontend",
                relation="TRIGGERS",
                context=(
                    "Punto di ingresso della moderazione."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="User reports route",
                file_candidates=(
                    "BE/routes/user_report.py",
                ),
                layer="Backend API",
                relation="READS",
                context=(
                    "Gestione segnalazioni profilo."
                ),
                security_critical=True,
            ),
            FlowStepSpec(
                title="Group reports route",
                file_candidates=(
                    "BE/routes/group_report.py",
                    "BE/routes/group_content_report.py",
                    "BE/routes/group_news_report.py",
                ),
                layer="Backend API",
                relation="READS",
                context=(
                    "Gestione segnalazioni gruppi e UGC."
                ),
                security_critical=True,
            ),
        ),
    ),
)


def _find_file(
    index: ArchitectureIndex,
    candidates: tuple[str, ...],
) -> IndexedFile | None:
    by_path = index.by_path

    for candidate in candidates:
        file = by_path.get(
            candidate,
        )

        if file is not None:
            return file

    normalized_candidates = {
        candidate.lower()
        for candidate in candidates
    }

    for file in index.files:
        normalized = file.path.lower()

        if normalized in normalized_candidates:
            return file

        for candidate in normalized_candidates:
            if normalized.endswith(
                "/" + candidate,
            ):
                return file

    return None


def _find_function(
    file: IndexedFile,
    candidates: tuple[str, ...],
) -> IndexedFunction | None:
    if not candidates:
        return None

    normalized = {
        candidate.strip().lower()
        for candidate in candidates
        if candidate.strip()
    }

    for function in file.functions:
        if function.name.lower() in normalized:
            return function

    return None


def _flow_step(
    order: int,
    spec: FlowStepSpec,
    file: IndexedFile,
    function: IndexedFunction | None,
) -> dict:
    return {
        "order": order,
        "title": spec.title,
        "file": file.path,
        "function": (
            function.name
            if function is not None
            else None
        ),
        "layer": (
            file.layer
            or spec.layer
        ),
        "relation": spec.relation,
        "context": spec.context,
        "security_critical": (
            spec.security_critical
            or file.security_critical
            or (
                function is not None
                and bool(
                    function.security,
                )
            )
        ),
    }


def resolve_flow(
    index: ArchitectureIndex,
    spec: FlowSpec,
) -> dict:
    steps: list[dict] = []

    for step_spec in spec.steps:
        file = _find_file(
            index,
            step_spec.file_candidates,
        )

        if file is None:
            continue

        function = _find_function(
            file,
            step_spec.function_candidates,
        )

        steps.append(
            _flow_step(
                len(steps) + 1,
                step_spec,
                file,
                function,
            ),
        )

    return {
        "id": spec.id,
        "name": spec.name,
        "description": spec.description,
        "risk": spec.risk,
        "steps": steps,
    }


def resolve_flows(
    index: ArchitectureIndex,
) -> list[dict]:
    return [
        resolve_flow(
            index,
            spec,
        )
        for spec in FLOW_REGISTRY
    ]


def get_flow(
    index: ArchitectureIndex,
    flow_id: str,
) -> dict | None:
    normalized = (
        flow_id
        .strip()
        .lower()
    )

    for spec in FLOW_REGISTRY:
        if spec.id == normalized:
            return resolve_flow(
                index,
                spec,
            )

    return None


def apply_flow_metadata(
    index: ArchitectureIndex,
) -> ArchitectureIndex:
    for flow in resolve_flows(
        index,
    ):
        flow_name = flow["name"]

        for step in flow["steps"]:
            file = index.by_path.get(
                step["file"],
            )

            if file is None:
                continue

            if flow_name not in file.flows:
                file.flows.append(
                    flow_name,
                )

            function_name = step.get(
                "function",
            )

            if not function_name:
                continue

            for function in file.functions:
                if (
                    function.name
                    != function_name
                ):
                    continue

                if (
                    flow_name
                    not in function.flows
                ):
                    function.flows.append(
                        flow_name,
                    )

                break

    return index