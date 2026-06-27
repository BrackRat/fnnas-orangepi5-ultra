#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


HELPER = r'''
prepare_orangepi5ultra_bootloader() {
    local source_dir="${uboot_path}/rockchip/orangepi-5-plus"
    local target_dir="${uboot_path}/rockchip/orangepi-5-ultra"

    [[ -d "${target_dir}" ]] && return 0
    if [[ -d "${source_dir}" ]]; then
        mkdir -p "$(dirname "${target_dir}")"
        cp -af --no-preserve=ownership "${source_dir}" "${target_dir}"
        echo -e "${INFO} fnnas: copied Orange Pi 5 Plus bootloader files for Orange Pi 5 Ultra."
    else
        echo -e "${WARNING} fnnas: missing Orange Pi 5 Plus bootloader fallback at [ ${source_dir} ]."
    fi
}
'''


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_renas_orangepi5ultra.py RENAS_PATH", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")

    if "prepare_orangepi5ultra_bootloader()" in text:
        print(f"Orange Pi 5 Ultra renas patch already exists in {path}")
        return 0

    marker = "download_depends() {\n"
    if marker not in text:
        print("Cannot find download_depends function in renas", file=sys.stderr)
        return 1
    text = text.replace(marker, HELPER + "\n" + marker, 1)

    call_marker = "# Query latest kernel version\n"
    call = "# Prepare temporary Orange Pi 5 Ultra bootloader fallback\nprepare_orangepi5ultra_bootloader\n"
    if call_marker not in text:
        print("Cannot find query-kernel marker in renas", file=sys.stderr)
        return 1
    text = text.replace(call_marker, call + call_marker, 1)

    path.write_text(text, encoding="utf-8")
    print(f"Patched {path} with Orange Pi 5 Ultra bootloader fallback")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
