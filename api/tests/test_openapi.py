from app.openapi import SPEC_PATH, render


def test_committed_spec_is_current():
    assert SPEC_PATH.read_text(encoding="utf-8") == render(), (
        "openapi.json is stale: run `uv run python -m app.openapi`"
    )


def test_dart_client_spec_adjustments():
    from app.openapi import dart_client_spec, spec

    source = spec()
    client = dart_client_spec(source)
    schemas = client["components"]["schemas"]
    # enum with a default becomes required with no default
    method = schemas["SettlementIn"]["properties"]["method"]
    assert "default" not in method and "method" in schemas["SettlementIn"]["required"]
    # required-but-nullable fields become optional
    assert "avatar_url" in source["components"]["schemas"]["UserOut"]["required"]
    assert "avatar_url" not in schemas["UserOut"]["required"]
    assert schemas["ValidationError"]["properties"]["loc"]["items"] == {"type": "string"}
    # the canonical spec is untouched
    assert "default" in source["components"]["schemas"]["SettlementIn"]["properties"]["method"]


def test_operation_ids_are_unique_and_readable():
    from app.openapi import spec

    ids = [op["operationId"] for path in spec()["paths"].values() for op in path.values()]
    assert len(ids) == len(set(ids))
    assert "create_expense" in ids and all("api_v1" not in i for i in ids)


def test_app_registers_every_table_on_its_own():
    """Regression: the running app must not rely on something else importing app.models."""
    import subprocess
    import sys

    code = (
        "import app.main\n"
        "from app.core.db import Base\n"
        "from sqlalchemy.orm import configure_mappers\n"
        "configure_mappers()\n"
        "assert 'import_batches' in Base.metadata.tables, sorted(Base.metadata.tables)\n"
        "Base.metadata.tables['expenses'].c.import_batch_id.references(Base.metadata.tables['import_batches'].c.id)\n"
    )
    result = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, cwd=".")
    assert result.returncode == 0, result.stderr


def test_schema_names_do_not_shadow_flutter_widgets():
    """The Dart client exports every schema as a class; these names would clash in the app."""
    from app.openapi import spec

    flutter = {
        "Row",
        "Column",
        "Text",
        "Container",
        "Stack",
        "Icon",
        "Card",
        "Image",
        "Table",
        "Scaffold",
        "Center",
        "Padding",
        "Align",
        "Flex",
        "Title",
        "Chip",
        "Badge",
        "Tab",
    }
    assert not flutter & set(spec()["components"]["schemas"])
