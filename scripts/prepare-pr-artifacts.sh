#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
FNNAS_DIR="${FNNAS_DIR:-${WORK_DIR}/fnnas}"
DTB_PATH="${1:-${ROOT_DIR}/build/dtb/rk3588-orangepi-5-ultra.dtb}"
UBOOT_SOURCE_DIR="${2:-${ROOT_DIR}/build/u-boot/orangepi-5-ultra}"
OUT_DIR="${ROOT_DIR}/build/pr-artifacts"
UBOOT_PR_DIR="${OUT_DIR}/ophub-u-boot/u-boot/rockchip/orangepi-5-ultra"
FNNAS_PR_DIR="${OUT_DIR}/ophub-fnnas"
MODEL_DB="make-fnnas/fnnas-files/common-files/etc/model_database.conf"

if [[ ! -s "${DTB_PATH}" ]]; then
  echo "DTB not found: ${DTB_PATH}" >&2
  exit 1
fi

if [[ ! -s "${UBOOT_SOURCE_DIR}/idbloader.img" || ! -s "${UBOOT_SOURCE_DIR}/u-boot.itb" ]]; then
  echo "Orange Pi 5 Ultra u-boot files not found in: ${UBOOT_SOURCE_DIR}" >&2
  exit 1
fi

if [[ ! -d "${FNNAS_DIR}/.git" ]]; then
  echo "FnNAS tree not found: ${FNNAS_DIR}" >&2
  exit 1
fi

rm -rf "${OUT_DIR}"
mkdir -p "${UBOOT_PR_DIR}" "${FNNAS_PR_DIR}"

cp "${UBOOT_SOURCE_DIR}/idbloader.img" "${UBOOT_PR_DIR}/idbloader.img"
cp "${UBOOT_SOURCE_DIR}/u-boot.itb" "${UBOOT_PR_DIR}/u-boot.itb"
cp "${DTB_PATH}" "${FNNAS_PR_DIR}/rk3588-orangepi-5-ultra.dtb"

git -C "${FNNAS_DIR}" diff -- "${MODEL_DB}" >"${FNNAS_PR_DIR}/model_database.patch"
grep "Orange-Pi-5-Ultra" "${FNNAS_DIR}/${MODEL_DB}" >"${FNNAS_PR_DIR}/model_database.row"

sha256sum \
  "${UBOOT_PR_DIR}/idbloader.img" \
  "${UBOOT_PR_DIR}/u-boot.itb" \
  "${FNNAS_PR_DIR}/rk3588-orangepi-5-ultra.dtb" \
  >"${OUT_DIR}/SHA256SUMS"

cat >"${OUT_DIR}/SOURCE-MANIFEST.md" <<EOF
# Orange Pi 5 Ultra FnNAS PR Artifacts

Generated from this workflow run for upstream contribution preparation.

## Sources

- Orange Pi kernel DTB source: https://github.com/orangepi-xunlong/linux-orangepi
- Orange Pi kernel ref: ${KERNEL_REF:-orange-pi-6.1-rk35xx}
- Orange Pi U-Boot source: https://github.com/orangepi-xunlong/u-boot-orangepi
- Orange Pi U-Boot ref: ${UBOOT_REF:-v2017.09-rk3588}
- Orange Pi U-Boot config: \`orangepi_5_ultra_defconfig\`
- Rockchip rkbin source: https://github.com/rockchip-linux/rkbin
- Rockchip rkbin ref: ${RKBIN_REF:-master}
- FnNAS source: https://github.com/ophub/fnnas
- FnNAS ref: ${FNNAS_REF:-main}

## PR 1: ophub/u-boot

Copy this directory into \`ophub/u-boot\`:

\`\`\`text
ophub-u-boot/u-boot/rockchip/orangepi-5-ultra/
\`\`\`

Files:

\`\`\`text
idbloader.img
u-boot.itb
\`\`\`

## PR 2: ophub/fnnas

Apply:

\`\`\`text
ophub-fnnas/model_database.patch
\`\`\`

The generated model row is also saved as:

\`\`\`text
ophub-fnnas/model_database.row
\`\`\`

The tested DTB is included for review/reference:

\`\`\`text
ophub-fnnas/rk3588-orangepi-5-ultra.dtb
\`\`\`
EOF

cat >"${OUT_DIR}/ophub-u-boot/PR-BODY.md" <<'EOF'
## Summary

Add Rockchip bootloader files for Orange Pi 5 Ultra.

## Build Source

- U-Boot source: `orangepi-xunlong/u-boot-orangepi`
- U-Boot branch: `v2017.09-rk3588`
- U-Boot config: `orangepi_5_ultra_defconfig`
- rkbin source: `rockchip-linux/rkbin`
- `idbloader.img` generated from RK3588 DDR blob in `RK3588MINIALL.ini` plus `spl/u-boot-spl.bin`
- `u-boot.itb` produced from Orange Pi RK3588 FIT payload

## Test

Tested booting FnNAS on Orange Pi 5 Ultra. SSH and FnNAS Web UI are reachable.
EOF

cat >"${OUT_DIR}/ophub-fnnas/PR-BODY.md" <<'EOF'
## Summary

Add Orange Pi 5 Ultra to the FnNAS Rockchip device database.

## Device

- Model: Orange Pi 5 Ultra
- SoC: RK3588
- DTB: `rk3588-orangepi-5-ultra.dtb`
- Board id: `orangepi-5-ultra`
- Boot config: `armbianEnv.txt`

## Test

Tested booting FnNAS on Orange Pi 5 Ultra. SSH and FnNAS Web UI are reachable.

## Related

This depends on adding `u-boot/rockchip/orangepi-5-ultra/` to `ophub/u-boot`.
EOF

find "${OUT_DIR}" -type f -print | sort
