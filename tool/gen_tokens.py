#!/usr/bin/env python3
"""Generate app/lib/core/theme/tokens.g.dart from design/tokens.json.

Usage: python3 tool/gen_tokens.py   (app/test/theme/tokens_test.dart fails if the output is stale)
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "design" / "tokens.json"
OUT = ROOT / "app" / "lib" / "core" / "theme" / "tokens.g.dart"


def color(hex_: str) -> str:
    return f"Color(0xFF{hex_.lstrip('#').upper()})"


def num(v) -> str:
    return str(float(v))


def main() -> None:
    t = json.loads(SRC.read_text(encoding="utf-8"))
    lines = [
        "// GENERATED from design/tokens.json by tool/gen_tokens.py. Do not edit.",
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
    ]
    names = list(t["color"])
    if list(t["colorDark"]) != names:
        raise SystemExit("colorDark must have the same tokens, in the same order, as color")
    lines += [
        '/// One set of colour tokens: tokens.json "color" ([skLightColors]) or "colorDark"',
        "/// ([skDarkColors]).",
        "class SkColorSet {",
        "  const SkColorSet({",
        *[f"    required this.{k}," for k in names],
        "  });",
        *[f"  final Color {k};" for k in names],
        "}",
        "",
    ]
    for const, key in (("skLightColors", "color"), ("skDarkColors", "colorDark")):
        lines += [f"const {const} = SkColorSet("]
        lines += [f"  {k}: {color(v)}," for k, v in t[key].items()]
        lines += [");", ""]
    lines += [
        "/// The colours in use. Widgets read them here; the app root picks the set (theme.dart",
        "/// SkTheme.apply) and rebuilds everything when light and dark change.",
        "abstract final class SkColors {",
        "  static SkColorSet current = skLightColors;",
        "",
        "  static bool get isDark => identical(current, skDarkColors);",
        "",
    ]
    lines += [f"  static Color get {k} => current.{k};" for k in names]
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
    for const, key, doc in (
        ("skColorTokens", "color", "Every light colour token by name, for tests and the gallery."),
        ("skDarkColorTokens", "colorDark", "Every dark colour token by name."),
    ):
        lines += [f"/// {doc}", f"const {const} = <String, Color>{{"]
        lines += [f"  '{k}': {color(v)}," for k, v in t[key].items()]
        lines += ["};", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
