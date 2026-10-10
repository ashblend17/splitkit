"""A small client for Tricount's private API (api.tricount.bunq.com).

There is no public API: this follows what the open-source clients learned from the Android app
(github.com/federicobond/go-tricount). It may change or be blocked at any time.

- No login. The server registers once as an anonymous device (an installation id and an RSA
  public key) and gets a session token. A share link's token (tXXXX) gives read and write
  access to that tricount; joining it (registry-synchronization) makes it writable.
- Writes are only accepted from clients that identify as the Android app (User-Agent).
- Creating an entry with our own uuid is idempotent: a repeat returns the first entry.
"""

import uuid
from dataclasses import dataclass
from typing import Any

import httpx
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.modules.tricount_sync import wire
from app.modules.tricount_sync.models import TricountDevice

CLIENT_REQUEST_ID = "049bfcdf-6ae4-4cee-af7b-45da31ea85d0"
"""A constant the app sends. The API wants the header but not a fresh value each time."""

_transport: httpx.BaseTransport | None = None


def use_transport(transport: httpx.BaseTransport | None) -> None:
    """Tests route every call to a fake Tricount (tests/tricount_fake.py)."""
    global _transport
    _transport = transport


class TricountError(Exception):
    def __init__(self, status: int, message: str, retry_after: int | None = None):
        super().__init__(f"Tricount answered {status}: {message}")
        self.status, self.message, self.retry_after = status, message, retry_after

    @property
    def gone(self) -> bool:
        return self.status == 404


@dataclass
class Credentials:
    app_id: str
    public_key_pem: str
    token: str | None = None
    user_id: int | None = None


def new_credentials() -> Credentials:
    """A fresh installation id and RSA public key. The private half is never needed."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.PKCS1
    )
    return Credentials(app_id=str(uuid.uuid4()), public_key_pem=pem.decode())


def device(session: Session) -> TricountDevice:
    """This server's Tricount device, registered on first use."""
    row = session.get(TricountDevice, 1)
    if row is None:
        creds = new_credentials()
        row = TricountDevice(id=1, app_id=creds.app_id, public_key_pem=creds.public_key_pem)
        session.add(row)
        session.flush()
    return row


def _error(response: httpx.Response) -> TricountError:
    message = response.text[:300]
    try:
        errors = response.json().get("Error") or []
        if errors and errors[0].get("error_description"):
            message = errors[0]["error_description"]
    except ValueError:
        pass
    retry = response.headers.get("Retry-After")
    return TricountError(
        response.status_code, message, int(retry) if retry and retry.isdigit() else None
    )


class Client:
    """One device talking to Tricount. Not thread-safe; make one per sync pass."""

    def __init__(self, creds: Credentials, on_session=None, timeout: float = 30):
        settings = get_settings()
        self.creds = creds
        self._on_session = on_session
        self._http = httpx.Client(
            base_url=settings.tricount_api_url,
            timeout=timeout,
            transport=_transport,
            headers={
                "User-Agent": settings.tricount_user_agent,
                "app-id": creds.app_id,
                "X-Bunq-Client-Request-Id": CLIENT_REQUEST_ID,
            },
        )

    @classmethod
    def for_device(cls, session: Session) -> "Client":
        row = device(session)

        def remember(token: str, user_id: int) -> None:
            row.token, row.tricount_user_id = token, user_id

        creds = Credentials(row.app_id, row.public_key_pem, row.token, row.tricount_user_id)
        return cls(creds, on_session=remember)

    def close(self) -> None:
        self._http.close()

    def __enter__(self) -> "Client":
        return self

    def __exit__(self, *_) -> None:
        self.close()

    # ---- transport ----

    def _register(self) -> None:
        response = self._http.post(
            "/v1/session-registry-installation",
            json={
                "app_installation_uuid": self.creds.app_id,
                "client_public_key": self.creds.public_key_pem,
                "device_description": "Android",
            },
        )
        if response.status_code >= 400:
            raise _error(response)
        body = response.json()
        self.creds.token = wire.first(body, "Token")["token"]
        self.creds.user_id = int(wire.first(body, "UserPerson")["id"])
        if self._on_session:
            self._on_session(self.creds.token, self.creds.user_id)

    def _call(self, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
        """An authenticated call under /v1/user/{id}; registers on first use and once more
        if the session has expired."""
        if not self.creds.token:
            self._register()
        for attempt in (1, 2):
            response = self._http.request(
                method,
                f"/v1/user/{self.creds.user_id}{path}",
                headers={"X-Bunq-Client-Authentication": self.creds.token or ""},
                **kwargs,
            )
            if response.status_code == 401 and attempt == 1:
                self._register()
                continue
            if response.status_code >= 400:
                raise _error(response)
            return response.json() if response.content else {}
        raise AssertionError("unreachable")

    # ---- tricounts ----

    def peek(self, public_token: str) -> wire.Registry:
        """A tricount by its share token, without joining it (read-only)."""
        body = self._call("GET", "/registry", params={"public_identifier_token": public_token})
        for raw in wire.items(body, "Registry"):
            if raw.get("public_identifier_token") == public_token:
                return wire.registry(raw)
        raise TricountError(404, "No tricount has that link")

    def join(self, public_token: str) -> wire.Registry:
        """Follow a tricount by its share token, which makes it writable, and read it."""
        body = self._call(
            "POST",
            "/registry-synchronization",
            json={
                "all_registry_active": [{"public_identifier_token": public_token}],
                "all_registry_archived": [],
                "all_registry_deleted": [],
            },
        )
        for sync in wire.items(body, "RegistrySynchronization"):
            for raw in sync.get("all_registry_active") or []:
                if raw.get("public_identifier_token") == public_token:
                    return self.registry(int(raw["id"]))
        raise TricountError(404, "No tricount has that link")

    def registry(self, registry_id: int) -> wire.Registry:
        found = wire.registry(wire.first(self._call("GET", f"/registry/{registry_id}"), "Registry"))
        if found.id != registry_id:
            raise wire.WireError(f"Asked for tricount {registry_id}, got {found.id}")
        return found

    def create_registry(self, title: str, currency: str) -> int:
        body = self._call(
            "POST", "/registry", json={"title": title, "currency": currency, "description": ""}
        )
        return int(wire.first(body, "Id")["id"])

    def update_registry(self, registry_id: int, body: dict[str, Any]) -> None:
        self._call("PUT", f"/registry/{registry_id}", json=body)

    # ---- entries ----

    def create_entry(self, registry_id: int, body: dict[str, Any]) -> int:
        reply = self._call("POST", f"/registry/{registry_id}/registry-entry", json=body)
        return int(wire.first(reply, "Id")["id"])

    def update_entry(self, registry_id: int, entry_id: int, body: dict[str, Any]) -> None:
        # A full replacement. The open-source clients send a fresh uuid on updates.
        self._call(
            "PUT",
            f"/registry/{registry_id}/registry-entry/{entry_id}",
            json={**body, "uuid": str(uuid.uuid4())},
        )

    def delete_entry(self, registry_id: int, entry_id: int) -> None:
        self._call("DELETE", f"/registry/{registry_id}/registry-entry/{entry_id}")
