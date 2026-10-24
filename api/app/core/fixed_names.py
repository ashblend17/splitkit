"""Names the data depends on, which stay as they are whatever the app is called: seeds of ids and
values already stored, not the app's name."""

ID_SEED = "splitkit"
"""Seeds the ids worked out the same way here and on every device: category rules
(categories/rules.py, and the app's core/fixed_names.dart), default layouts (sync/log.py) and the
uuids entries are created with in Tricount (tricount_sync/mapping.py). Rows already stored, and
entries already in a tricount, keep matching only while it stays."""

KEPT_HERE = ID_SEED
"""How a Tricount conflict settled with this app's version is stored: in
tricount_conflicts.resolution (which migration 0008 checks) and in audit rows before 1.0.0. The
API calls that choice "local"."""
