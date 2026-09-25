"""One error shape for every API failure: {"error": {"code": ..., "message": ..., ...extra}}.

`message` is human copy the client can show as-is; `code` is for branching in client logic.
"""

from typing import Any

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm.exc import StaleDataError


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, **extra: Any):
        super().__init__(message)
        self.status, self.code, self.message, self.extra = status, code, message, extra


def not_found(what: str) -> ApiError:
    return ApiError(404, "not_found", f"{what} not found")


def install_error_handler(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _handle(_: Request, exc: ApiError) -> JSONResponse:
        body = {"code": exc.code, "message": exc.message, **exc.extra}
        return JSONResponse({"error": body}, status_code=exc.status)

    @app.exception_handler(StaleDataError)
    async def _stale(request: Request, _: StaleDataError) -> JSONResponse:
        # Another request changed the same row first (version counter mismatch at flush).
        from app.core.versioning import version_conflict

        return await _handle(request, version_conflict())
