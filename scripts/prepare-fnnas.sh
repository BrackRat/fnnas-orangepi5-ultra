#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
FNNAS_REPO="${FNNAS_REPO:-https://github.com/ophub/fnnas.git}"
FNNAS_REF="${FNNAS_REF:-main}"
FNNAS_DIR="${FNNAS_DIR:-${WORK_DIR}/fnnas}"
FNNAS_UBOOT_REPO="${FNNAS_UBOOT_REPO:-}"
FNNAS_UBOOT_REF="${FNNAS_UBOOT_REF:-main}"
FNNAS_UBOOT_DIR="${FNNAS_UBOOT_DIR:-${WORK_DIR}/fnnas-u-boot}"
DTB_PATH="${1:-${ROOT_DIR}/build/dtb/rk3588-orangepi-5-ultra.dtb}"
UBOOT_SOURCE_DIR="${2:-${ROOT_DIR}/build/u-boot/orangepi-5-ultra}"
MODEL_DB="${FNNAS_DIR}/make-fnnas/fnnas-files/common-files/etc/model_database.conf"
ULTRA_DTB="rk3588-orangepi-5-ultra.dtb"
PLUS_DTB="rk3588-orangepi-5-plus.dtb"
ULTRA_UBOOT_TARGET="${FNNAS_DIR}/make-fnnas/u-boot/rockchip/orangepi-5-ultra"
FNNAS_UBOOT_BOARD_DIR="${FNNAS_UBOOT_DIR}/u-boot/rockchip/orangepi-5-ultra"

if [[ ! -f "${DTB_PATH}" ]]; then
  echo "DTB not found: ${DTB_PATH}" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"

if [[ ! -d "${FNNAS_DIR}/.git" ]]; then
  git clone "${FNNAS_REPO}" "${FNNAS_DIR}"
fi

git -C "${FNNAS_DIR}" fetch --depth=1 origin "${FNNAS_REF}" || true
git -C "${FNNAS_DIR}" checkout "${FNNAS_REF}" || git -C "${FNNAS_DIR}" checkout "origin/${FNNAS_REF}"

if [[ ! -f "${MODEL_DB}" ]]; then
  echo "model_database.conf not found: ${MODEL_DB}" >&2
  exit 1
fi

python3 "${ROOT_DIR}/scripts/patch_fnnas_orangepi5ultra.py" "${MODEL_DB}" | tee "${WORK_DIR}/model_database.patch.log"

if [[ -n "${FNNAS_UBOOT_REPO}" ]]; then
  if [[ ! -d "${FNNAS_UBOOT_DIR}/.git" ]]; then
    git clone "${FNNAS_UBOOT_REPO}" "${FNNAS_UBOOT_DIR}"
  fi

  git -C "${FNNAS_UBOOT_DIR}" fetch --depth=1 origin "${FNNAS_UBOOT_REF}" || true
  git -C "${FNNAS_UBOOT_DIR}" checkout "${FNNAS_UBOOT_REF}" || git -C "${FNNAS_UBOOT_DIR}" checkout "origin/${FNNAS_UBOOT_REF}"
  UBOOT_SOURCE_DIR="${FNNAS_UBOOT_BOARD_DIR}"
  echo "Using Orange Pi 5 Ultra u-boot files from ${FNNAS_UBOOT_REPO}@${FNNAS_UBOOT_REF}"
fi

if [[ ! -s "${UBOOT_SOURCE_DIR}/idbloader.img" || ! -s "${UBOOT_SOURCE_DIR}/u-boot.itb" ]]; then
  echo "Orange Pi 5 Ultra u-boot files not found in: ${UBOOT_SOURCE_DIR}" >&2
  exit 1
fi

mkdir -p "${ULTRA_UBOOT_TARGET}"
cp "${UBOOT_SOURCE_DIR}/idbloader.img" "${ULTRA_UBOOT_TARGET}/idbloader.img"
cp "${UBOOT_SOURCE_DIR}/u-boot.itb" "${ULTRA_UBOOT_TARGET}/u-boot.itb"
ls -lh "${ULTRA_UBOOT_TARGET}" | tee "${WORK_DIR}/uboot.patch.log"

mapfile -t plus_locations < <(find "${FNNAS_DIR}" -type f -name "${PLUS_DTB}" | sort)

if [[ "${#plus_locations[@]}" -gt 0 ]]; then
  for plus_location in "${plus_locations[@]}"; do
    target_dir="$(dirname "${plus_location}")"
    cp "${DTB_PATH}" "${target_dir}/${ULTRA_DTB}"
    echo "Copied DTB to ${target_dir}/${ULTRA_DTB}"
  done
else
  fallback_dir="${FNNAS_DIR}/make-fnnas/fnnas-files/common-files/boot/dtb"
  fallback_rockchip_dir="${fallback_dir}/rockchip"
  mkdir -p "${fallback_dir}" "${fallback_rockchip_dir}"
  cp "${DTB_PATH}" "${fallback_dir}/${ULTRA_DTB}"
  cp "${DTB_PATH}" "${fallback_rockchip_dir}/${ULTRA_DTB}"
  echo "5 Plus DTB location not found; copied DTB to fallbacks:"
  echo "  ${fallback_dir}/${ULTRA_DTB}"
  echo "  ${fallback_rockchip_dir}/${ULTRA_DTB}"
fi

grep -n "orangepi-5-plus\|orangepi-5-ultra\|orange-pi-5-plus\|orange-pi-5-ultra" "${MODEL_DB}"
