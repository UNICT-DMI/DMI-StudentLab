from sqlalchemy import (
    Boolean,
    Column,
    Integer,
    String,
)

from core.database import Base


class AppConfig(Base):
    __tablename__ = "app_config"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    latest_version = Column(
        String,
        nullable=False,
        default="1.0.0",
    )

    minimum_version = Column(
        String,
        nullable=False,
        default="1.0.0",
    )

    force_update = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    maintenance = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    message = Column(
        String,
        nullable=False,
        default="",
    )

    android_url = Column(
        String,
        nullable=False,
        default="",
    )

    ios_url = Column(
        String,
        nullable=False,
        default="",
    )

    windows_url = Column(
        String,
        nullable=False,
        default="",
    )

    linux_url = Column(
        String,
        nullable=False,
        default="",
    )

    macos_url = Column(
        String,
        nullable=False,
        default="",
    )