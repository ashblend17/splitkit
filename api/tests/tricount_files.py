"""Sample Tricount exports for the importer tests (tests/fixtures/tricount).

goa_trip.csv is the Goa Trip from the mockups in Tricount's own layout (comma, dot decimals,
ISO dates, "Impacted to <name>"). goa_trip_semicolon.csv is the same data as a European
spreadsheet writes it (BOM, semicolons, "1.234,50", dd/mm/yyyy, other header names).
The XLSX is built here from the CSV, with real number and date cells and the tricount's name
above the header, as Excel exports have it.
"""

import csv
import io
from datetime import datetime
from pathlib import Path

from openpyxl import Workbook

FIXTURES = Path(__file__).parent / "fixtures" / "tricount"


def read(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def goa_xlsx(title: str | None = "Goa Trip") -> bytes:
    rows = list(csv.reader(io.StringIO(read("goa_trip.csv").decode())))
    book = Workbook()
    sheet = book.active
    if title:
        sheet.append([title])
        sheet.append([])
    sheet.append(rows[0])
    for r in rows[1:]:
        cells: list[object] = []
        for i, v in enumerate(r):
            if i == 5:
                cells.append(datetime.fromisoformat(v))
            elif i in (1, 4) or i >= 9:
                cells.append(float(v) if v else None)
            else:
                cells.append(v or None)
        sheet.append(cells)
    out = io.BytesIO()
    book.save(out)
    return out.getvalue()
