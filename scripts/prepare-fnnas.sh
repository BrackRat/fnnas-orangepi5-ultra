#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
FNNAS_REPO="${FNNAS_REPO:-https://github.com/ophub/fnnas.git}"
FNNAS_REF="${FNNAS_REF:-main}"
FNNAS_DIR="${FNNAS_DIR:-${WORK_DIR}/fnnas}"
DTB_PATH="${1:-${ROOT_DIR}/build/dtb/rk3588-orangepi-5-ultra.dtb}"
MODEL_DB="${FNNAS_DIR}/make-fnnas/fnnas-files/common-files/etc/model_database.conf"
ULTRA_DTB="rk3588-orangepi-5-ultra.dtb"
PLUS_DTB="rk3588-orangepi-5-plus.dtb"

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

grep -n "orange-pi-5-plus\|orange-pi-5-ultra" "${MODEL_DB}"
