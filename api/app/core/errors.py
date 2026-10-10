"""One error shape for every API failure: {"error": {"code": ..., "message": ..., ...extra}}.

`message` is human copy the client can show as-is; `code` is for branching in client logic.
"""

from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.orm.exc import StaleDataError

# How a field is named in messages, where its key doesn't read well on its own.
FIELD_NAMES = {
    "amount_minor": "Amount",
    "total_minor": "Amount",
    "payer_id": "Who paid",
    "from_user": "Who paid",
    "to_user": "Who was paid",
    "category_id": "Category",
    "user_id": "Person",
    "group_id": "Group",
}


def _field(loc: tuple) -> str:
    names = [p for p in loc if isinstance(p, str) and p not in ("body", "query", "path")]
    if not names:
        return "This"
    key = names[-1]
    return FIELD_NAMES.get(key, key.replace("_", " ").capitalize())


def _human(err: dict) -> str:
    """One readable sentence for a pydantic error, e.g. "Name can't be empty"."""
    field, kind, ctx = _field(tuple(err.get("loc", ()))), err.get("type", ""), err.get("ctx") or {}
    if kind == "missing":
        return f"{field} is required"
    if kind == "string_too_short":
        if ctx.get("min_length", 1) <= 1:
            return f"{field} can't be empty"
        return f"{field} must be at least {ctx['min_length']} characters"
    if kind == "string_too_long":
        return f"{field} can be at most {ctx.get('max_length')} characters"
    if kind == "greater_than":
        return "Enter an amount above zero" if field == "Amount" else f"{field} must be above 0"
    if kind == "less_than_equal" and field == "Amount":
        return "That amount is too large"
    if kind.startswith("decimal_"):
        return f"{field} has too many digits"
    if kind in ("int_parsing", "int_from_float", "int_type"):
        return f"{field} must be a whole number"
    if kind in ("decimal_parsing", "finite_number", "float_parsing"):
        return f"{field} must be a number"
    if kind.startswith("date") or kind.startswith("datetime"):
        return f"{field} isn't a valid date"
    if kind == "uuid_parsing" or kind == "uuid_type":
        return f"{field} isn't a valid id"
    if kind == "literal_error":
        return f"{field} must be one of {ctx.get('expected', 'the allowed values')}"
    if kind == "value_error" and "email" in str(err.get("msg", "")).lower():
        return "Enter a valid email address"
    msg = str(err.get("msg", "Check this value"))
    # Our own validators: "Value error, Give either an email or a name".
    return msg.removeprefix("Value error, ").removeprefix("Assertion failed, ")


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

    @app.exception_handler(RequestValidationError)
    async def _invalid(request: Request, exc: RequestValidationError) -> JSONResponse:
        # Same shape as every other error, instead of FastAPI's {"detail": [...]}.
        errors = exc.errors()
        fields = [
            {"loc": [p for p in e.get("loc", ()) if isinstance(p, str | int)], "message": _human(e)}
            for e in errors
        ]
        message = fields[0]["message"] if fields else "Check what you entered"
        return await _handle(request, ApiError(422, "invalid_input", message, fields=fields))

    @app.exception_handler(StaleDataError)
    async def _stale(request: Request, _: StaleDataError) -> JSONResponse:
        # Another request changed the same row first (version counter mismatch at flush).
        from app.core.versioning import version_conflict

        return await _handle(request, version_conflict())
