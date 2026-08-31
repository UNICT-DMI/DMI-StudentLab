from pydantic import (
    BaseModel,
    ConfigDict,
)


class AppConfigResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    latest_version: str
    minimum_version: str

    force_update: bool
    maintenance: bool

    message: str

    android_url: str
    ios_url: str
    windows_url: str
    linux_url: str
    macos_url: str


class AppConfigUpdate(BaseModel):
    latest_version: str | None = None
    minimum_version: str | None = None

    force_update: bool | None = None
    maintenance: bool | None = None

    message: str | None = None

    android_url: str | None = None
    ios_url: str | None = None
    windows_url: str | None = None
    linux_url: str | None = None
    macos_url: str | None = None