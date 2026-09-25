#!/usr/bin/env python3
"""Generate app/lib/core/theme/tokens.g.dart from splitkit-design/tokens.json.

Usage: python3 tool/gen_tokens.py   (app/test/theme/tokens_test.dart fails if the output is stale)
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "splitkit-design" / "tokens.json"
OUT = ROOT / "app" / "lib" / "core" / "theme" / "tokens.g.dart"


def color(hex_: str) -> str:
    return f"Color(0xFF{hex_.lstrip('#').upper()})"


def num(v) -> str:
    return str(float(v))


def main() -> None:
    t = json.loads(SRC.read_text(encoding="utf-8"))
    lines = [
        "// GENERATED from splitkit-design/tokens.json by tool/gen_tokens.py. Do not edit.",
        "// ignore_for_file: constant_identifier_names",
        "",
        "import 'dart:ui';",
        "",
        "enum SkFamily { display, body }",
        "",
        "class SkTypeToken {",
        "  const SkTypeToken({required this.size, required this.weight, required this.family});",
        "  final double size;",
        "  final int weight;",
        "  final SkFamily family;",
        "}",
        "",
        "abstract final class SkColors {",
    ]
    lines += [f"  static const {k} = {color(v)};" for k, v in t["color"].items()]
    lines += ["}", "", "abstract final class SkType {"]
    for k, v in t["type"].items():
        lines.append(
            f"  static const {k} = SkTypeToken(size: {num(v['size'])}, weight: {v['weight']}, "
            f"family: SkFamily.{v['family']});"
        )
    lines += ["}", "", "abstract final class SkSpace {"]
    lines += [f"  static const s{v} = {num(v)};" for v in t["space"]]
    lines += [f"  static const scale = <double>[{', '.join(num(v) for v in t['space'])}];", "}", ""]
    lines += ["abstract final class SkRadius {"]
    lines += [f"  static const {k} = {num(v)};" for k, v in t["radius"].items()]
    lines += ["}", "", "abstract final class SkBreakpoints {"]
    lines += [f"  static const {k} = {num(v)};" for k, v in t["breakpoints"].items()]
    lines += ["}", "", f"const skMinTouchTarget = {num(t['minTouchTarget'])};", ""]
    lines += ["/// Every colour token by name, for tests and the gallery.", "const skColorTokens = <String, Color>{"]
    lines += [f"  '{k}': SkColors.{k}," for k in t["color"]]
    lines += ["};", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
