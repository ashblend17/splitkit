from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

import app.models  # noqa: F401  (register every table, so cross-module foreign keys resolve)
from app.core.config import get_settings
from app.core.db import engine
from app.core.errors import install_error_handler
from app.core.schemas import ErrorResponse
from app.modules.analytics.router import router as analytics_router
from app.modules.auth.router import router as auth_router
from app.modules.balances.router import router as balances_router
from app.modules.categories.router import router as categories_router
from app.modules.expenses.router import router as expenses_router
from app.modules.groups.router import router as groups_router
from app.modules.personal.router import router as personal_router
from app.modules.settlements.router import router as settlements_router
from app.modules.splits.router import router as splits_router
from app.modules.sync.router import router as sync_router
from app.modules.users.router import router as users_router

API_PREFIX = "/api/v1"

app = FastAPI(
    title="Splitkit API",
    version="0.1.0",
    openapi_url=f"{API_PREFIX}/openapi.json",
    docs_url=f"{API_PREFIX}/docs",
    redoc_url=None,
    # operationId = the route function's name, so generated clients read `createExpense`
    # rather than `createExpenseApiV1GroupsGroupIdExpensesPost`.
    generate_unique_id_function=lambda route: route.name,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)
install_error_handler(app)

# Every error uses the same body; documented so the generated client gets a typed model.
ERRORS = {status: {"model": ErrorResponse} for status in (401, 403, 404, 409)}
api = APIRouter(prefix=API_PREFIX, responses=ERRORS)


@api.get("/health", tags=["system"])
def health() -> dict[str, str]:
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "version": app.version}


for module_router in (
    auth_router,
    users_router,
    groups_router,
    categories_router,
    splits_router,
    expenses_router,
    settlements_router,
    balances_router,
    personal_router,
    analytics_router,
    sync_router,
):
    api.include_router(module_router)

app.include_router(api)
