#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
UBOOT_REPO="${UBOOT_REPO:-https://github.com/orangepi-xunlong/u-boot-orangepi.git}"
UBOOT_REF="${UBOOT_REF:-v2017.09-rk3588}"
RKBIN_REPO="${RKBIN_REPO:-https://github.com/rockchip-linux/rkbin.git}"
RKBIN_REF="${RKBIN_REF:-master}"
UBOOT_DIR="${WORK_DIR}/u-boot-orangepi"
RKBIN_DIR="${WORK_DIR}/rkbin"
OUT_DIR="${ROOT_DIR}/build/u-boot/orangepi-5-ultra"

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

if [[ ! -d "${UBOOT_DIR}/.git" ]]; then
  git clone --depth=1 -b "${UBOOT_REF}" "${UBOOT_REPO}" "${UBOOT_DIR}"
else
  git -C "${UBOOT_DIR}" fetch --depth=1 origin "${UBOOT_REF}"
  git -C "${UBOOT_DIR}" checkout "${UBOOT_REF}" || git -C "${UBOOT_DIR}" checkout "origin/${UBOOT_REF}"
fi

if [[ ! -d "${RKBIN_DIR}/.git" ]]; then
  git clone --depth=1 -b "${RKBIN_REF}" "${RKBIN_REPO}" "${RKBIN_DIR}"
else
  git -C "${RKBIN_DIR}" fetch --depth=1 origin "${RKBIN_REF}"
  git -C "${RKBIN_DIR}" checkout "${RKBIN_REF}" || git -C "${RKBIN_DIR}" checkout "origin/${RKBIN_REF}"
fi

if ! command -v python2 >/dev/null 2>&1; then
  mkdir -p "${WORK_DIR}/bin"
  ln -sf "$(command -v python3)" "${WORK_DIR}/bin/python2"
  export PATH="${WORK_DIR}/bin:${PATH}"
fi

cd "${UBOOT_DIR}"
export KCFLAGS="${KCFLAGS:--Wno-error}"
./make.sh orangepi_5_ultra CROSS_COMPILE=aarch64-linux-gnu- 2>&1 | tee "${WORK_DIR}/u-boot.log"

idbloader="$(find . -maxdepth 1 -type f -name 'idbloader.img' -print -quit)"
if [[ -z "${idbloader}" && -s "spl/u-boot-spl.bin" ]]; then
  ddr_blob="$(
    awk -F= '/^Path1=bin\/rk35\/rk3588_ddr/ { print $2; exit }' \
      "${RKBIN_DIR}/RKBOOT/RK3588MINIALL.ini"
  )"
  if [[ -z "${ddr_blob}" || ! -s "${RKBIN_DIR}/${ddr_blob}" ]]; then
    echo "Cannot find RK3588 DDR blob from RK3588MINIALL.ini" >&2
    exit 1
  fi
  tools/mkimage -n rk3588 -T rksd -d "${RKBIN_DIR}/${ddr_blob}:spl/u-boot-spl.bin" idbloader.img
  idbloader="./idbloader.img"
fi

if [[ -z "${idbloader}" || ! -s "${idbloader}" ]]; then
  echo "Orange Pi 5 Ultra idbloader.img was not generated" >&2
  find . -maxdepth 1 -type f \( -name '*loader*' -o -name '*idb*' -o -name 'u-boot.itb' \) -ls >&2
  exit 1
fi

if [[ ! -s u-boot.itb && -s uboot.img ]]; then
  cp uboot.img u-boot.itb
fi

if [[ ! -s u-boot.itb ]]; then
  echo "Orange Pi 5 Ultra u-boot.itb was not generated" >&2
  exit 1
fi

cp "${idbloader}" "${OUT_DIR}/idbloader.img"
cp u-boot.itb "${OUT_DIR}/u-boot.itb"
ls -lh "${OUT_DIR}"
