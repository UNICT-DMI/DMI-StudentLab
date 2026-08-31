from sqlalchemy.orm import Session

from models.app_config import AppConfig
from schemas.app_config import AppConfigUpdate


def get_app_config(
    db: Session,
) -> AppConfig:
    config = (
        db.query(AppConfig)
        .filter(
            AppConfig.id == 1
        )
        .first()
    )

    if config is not None:
        return config

    config = AppConfig(
        id=1,
        latest_version="1.0.0",
        minimum_version="1.0.0",
        force_update=False,
        maintenance=False,
        message="",
        android_url="",
        ios_url="",
        windows_url="",
        linux_url="",
        macos_url="",
    )

    try:
        db.add(config)
        db.commit()
        db.refresh(config)

        return config

    except Exception:
        db.rollback()
        raise


def update_app_config(
    db: Session,
    request: AppConfigUpdate,
) -> AppConfig:
    config = get_app_config(
        db,
    )

    values = request.model_dump(
        exclude_unset=True,
    )

    for key, value in values.items():
        setattr(
            config,
            key,
            value,
        )

    try:
        db.commit()
        db.refresh(config)

        return config

    except Exception:
        db.rollback()
        raise