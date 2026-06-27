#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


PLUS_BOARD = "orange-pi-5-plus"
ULTRA_BOARD = "orange-pi-5-ultra"
PLUS_MODEL = "Orange-Pi-5-Plus"
ULTRA_MODEL = "Orange-Pi-5-Ultra"
PLUS_DTB = "rockchip/rk3588-orangepi-5-plus.dtb"
ULTRA_DTB = "rockchip/rk3588-orangepi-5-ultra.dtb"


def split_fields(line: str) -> tuple[str | None, list[str]]:
    for delimiter in ("|", ",", ":", "\t"):
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


def next_numeric_id(lines: list[str]) -> str | None:
    ids: list[int] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        _delimiter, fields = split_fields(stripped)
        if fields and fields[0].strip().isdigit():
            ids.append(int(fields[0].strip()))
    if not ids:
        return None
    return str(max(ids) + 1)


def build_ultra_line(lines: list[str], template: str) -> str:
    line = template
    line = line.replace(PLUS_DTB, ULTRA_DTB)
    line = line.replace("rk3588-orangepi-5-plus.dtb", "rk3588-orangepi-5-ultra.dtb")
    line = line.replace(PLUS_MODEL, ULTRA_MODEL)
    line = line.replace(PLUS_BOARD, ULTRA_BOARD)

    delimiter, fields = split_fields(line)
    new_id = next_numeric_id(lines)
    if new_id and fields and fields[0].strip().isdigit():
        fields[0] = re.sub(r"\d+", new_id, fields[0], count=1)
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
        if PLUS_BOARD in line:
            template_index = index
            break

    if template_index is None:
        print(f"Cannot find template board {PLUS_BOARD} in {path}", file=sys.stderr)
        return 1

    ultra_line = build_ultra_line(lines, lines[template_index])
    required = (ULTRA_BOARD, ULTRA_MODEL, ULTRA_DTB)
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
