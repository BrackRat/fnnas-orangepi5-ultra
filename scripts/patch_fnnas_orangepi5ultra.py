#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


PLUS_BOARDS = ("orangepi-5-plus", "orange-pi-5-plus")
ULTRA_BOARD = "orange-pi-5-ultra"
PLUS_MODEL = "Orange-Pi-5-Plus"
ULTRA_MODEL = "Orange-Pi-5-Ultra"
PLUS_DTB_BASENAME = "rk3588-orangepi-5-plus.dtb"
ULTRA_DTB_BASENAME = "rk3588-orangepi-5-ultra.dtb"
PLUS_DTBS = (f"rockchip/{PLUS_DTB_BASENAME}", PLUS_DTB_BASENAME)
ULTRA_DTB_BY_PLUS_DTB = {
    f"rockchip/{PLUS_DTB_BASENAME}": f"rockchip/{ULTRA_DTB_BASENAME}",
    PLUS_DTB_BASENAME: ULTRA_DTB_BASENAME,
}

ID_RE = re.compile(r"^(\s*)([A-Za-z]*)(\d+)(\s*)$")


def split_fields(line: str) -> tuple[str | None, list[str]]:
    for delimiter in ("|", ":", "\t", ","):
        if delimiter in line:
            return delimiter, line.split(delimiter)

    fields = re.split(r"(\s+)", line)
    values = [field for field in fields if field and not field.isspace()]
    if len(values) > 1:
        return None, values

    return None, [line]


def join_fields(delimiter: str | None, fields: list[str], original: str) -> str:
    if delimiter is not None:
        return delimiter.join(fields)

    spacing = re.findall(r"\s+", original)
    if spacing:
        out = []
        for index, field in enumerate(fields):
            out.append(field)
            if index < len(fields) - 1:
                out.append(spacing[min(index, len(spacing) - 1)])
        return "".join(out)

    return " ".join(fields)


def next_identifier(lines: list[str], template_id: str) -> str | None:
    template_match = ID_RE.match(template_id)
    if not template_match:
        return None

    _leading, prefix, number, _trailing = template_match.groups()
    ids: list[int] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        _delimiter, fields = split_fields(stripped)
        if not fields:
            continue
        match = ID_RE.match(fields[0].strip())
        if match and match.group(2) == prefix:
            ids.append(int(match.group(3)))
    if not ids:
        return None
    return f"{prefix}{max(ids) + 1:0{len(number)}d}"


def replace_field_value(field: str, value: str) -> str:
    match = ID_RE.match(field)
    if match:
        return f"{match.group(1)}{value}{match.group(4)}"
    return value


def build_ultra_line(lines: list[str], template: str) -> str:
    line = template
    for plus_dtb, ultra_dtb in ULTRA_DTB_BY_PLUS_DTB.items():
        line = line.replace(plus_dtb, ultra_dtb)
    line = line.replace(PLUS_MODEL, ULTRA_MODEL)
    for plus_board in PLUS_BOARDS:
        line = line.replace(plus_board, ULTRA_BOARD)

    delimiter, fields = split_fields(line)
    if fields:
        new_id = next_identifier(lines, fields[0].strip())
    else:
        new_id = None
    if new_id and fields:
        fields[0] = replace_field_value(fields[0], new_id)
        line = join_fields(delimiter, fields, line)

    return line


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_fnnas_orangepi5ultra.py MODEL_DATABASE_CONF", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    newline = "\n" if text.endswith("\n") else ""

    if any(ULTRA_BOARD in line for line in lines):
        print(f"{ULTRA_BOARD} already exists in {path}")
        return 0

    template_index = None
    for index, line in enumerate(lines):
        if (
            PLUS_MODEL in line
            or any(plus_board in line for plus_board in PLUS_BOARDS)
            or any(plus_dtb in line for plus_dtb in PLUS_DTBS)
        ):
            template_index = index
            break

    if template_index is None:
        print(f"Cannot find Orange Pi 5 Plus template row in {path}", file=sys.stderr)
        return 1

    ultra_line = build_ultra_line(lines, lines[template_index])
    required = (ULTRA_BOARD, ULTRA_MODEL, ULTRA_DTB_BASENAME)
    missing = [value for value in required if value not in ultra_line]
    if missing:
        print(f"Generated row is missing expected values: {missing}", file=sys.stderr)
        print(ultra_line, file=sys.stderr)
        return 1

    lines.insert(template_index + 1, ultra_line)
    path.write_text("\n".join(lines) + newline, encoding="utf-8")
    print(ultra_line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
