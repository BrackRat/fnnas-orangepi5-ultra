#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/orangepi-xunlong/linux-orangepi.git}"
KERNEL_REF="${KERNEL_REF:-orange-pi-6.1-rk35xx}"
KERNEL_DIR="${KERNEL_DIR:-${WORK_DIR}/linux-orangepi}"
OUT_DIR="${1:-${ROOT_DIR}/build/dtb}"
TARGET_DTB="rk3588-orangepi-5-ultra.dtb"
TARGET_REL="arch/arm64/boot/dts/rockchip/${TARGET_DTB}"

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

if [[ ! -d "${KERNEL_DIR}/.git" ]]; then
  git clone --depth=1 -b "${KERNEL_REF}" "${KERNEL_REPO}" "${KERNEL_DIR}"
fi

make -C "${KERNEL_DIR}" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- rockchip_linux_defconfig

set +e
make -C "${KERNEL_DIR}" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs 2>&1 | tee "${WORK_DIR}/dtbs.log"
make_status="${PIPESTATUS[0]}"
set -e

grep -n "orangepi-5-ultra\|orange-pi-5-ultra\|${TARGET_DTB}" "${WORK_DIR}/dtbs.log" || true

if [[ "${make_status}" -ne 0 ]]; then
  echo "DTB build failed. See ${WORK_DIR}/dtbs.log" >&2
  exit "${make_status}"
fi

if [[ ! -f "${KERNEL_DIR}/${TARGET_REL}" ]]; then
  echo "Expected DTB not found: ${KERNEL_DIR}/${TARGET_REL}" >&2
  exit 1
fi

cp "${KERNEL_DIR}/${TARGET_REL}" "${OUT_DIR}/${TARGET_DTB}"
ls -lh "${OUT_DIR}/${TARGET_DTB}"
