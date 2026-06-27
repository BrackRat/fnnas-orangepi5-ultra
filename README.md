# FnNAS for Orange Pi 5 Ultra

This repository records a reproducible workflow for building a FnNAS ARM64 image
for Orange Pi 5 Ultra.  The build host should be Ubuntu 22.04 or 24.04 on x86_64.

The important moving pieces are:

- Orange Pi BSP kernel branch: `orange-pi-6.1-rk35xx`
- Device tree output: `rk3588-orangepi-5-ultra.dtb`
- FnNAS packaging project: `https://github.com/ophub/fnnas.git`
- FnNAS board id to add: `orange-pi-5-ultra`
- FnNAS kernel tag used for packaging: `6.18.y`

## Quick Start

```bash
sudo apt update
sudo apt install -y \
  git make gcc bison flex libssl-dev bc \
  gcc-aarch64-linux-gnu device-tree-compiler \
  u-boot-tools wget xz-utils zip unzip python3

bash scripts/build-dtb.sh
bash scripts/prepare-fnnas.sh build/dtb/rk3588-orangepi-5-ultra.dtb
```

Download the official ARM64 base image from the FnNAS download page:

- https://www.fnnas.com/download-arm

Look for the page-bottom ARM64 base image entry:

- `UEFI ARM 安装镜像`
- `fnnas_arm64 基础镜像`

Put the downloaded `.img` or `.img.xz` under `work/fnnas/fnnas-arm64/`, then run:

```bash
cd work/fnnas
sudo ./renas -b orange-pi-5-ultra -k 6.18.y
```

The packaged image is written to `work/fnnas/out/`.

## Step 1: Prepare Ubuntu

Use Ubuntu 22.04 or 24.04 x86_64.  A VM is fine.

```bash
sudo apt update
sudo apt install -y \
  git make gcc bison flex libssl-dev bc \
  gcc-aarch64-linux-gnu device-tree-compiler \
  u-boot-tools wget xz-utils zip unzip python3
```

## Step 2: Build Orange Pi 5 Ultra DTB

```bash
bash scripts/build-dtb.sh
```

The script clones:

```text
https://github.com/orangepi-xunlong/linux-orangepi.git
```

with branch:

```text
orange-pi-6.1-rk35xx
```

It then runs:

```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- rockchip_linux_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs
```

Expected output:

```text
build/dtb/rk3588-orangepi-5-ultra.dtb
```

## Step 3: Prepare FnNAS Packaging Tree

```bash
bash scripts/prepare-fnnas.sh build/dtb/rk3588-orangepi-5-ultra.dtb
```

This clones:

```text
https://github.com/ophub/fnnas.git
```

into:

```text
work/fnnas
```

Then it patches:

```text
work/fnnas/make-fnnas/fnnas-files/common-files/etc/model_database.conf
```

using the `orange-pi-5-plus` entry as the template.  The generated Orange Pi 5
Ultra entry changes:

- `FDTFILE` to `rockchip/rk3588-orangepi-5-ultra.dtb`
- `MODEL` to `Orange-Pi-5-Ultra`
- `BOARD` to `orange-pi-5-ultra`

The script also copies the generated DTB beside the existing 5 Plus DTB if it can
find that file.  If it cannot infer the upstream location, it copies to:

```text
work/fnnas/make-fnnas/fnnas-files/common-files/boot/dtb/rockchip/rk3588-orangepi-5-ultra.dtb
```

## Step 4: Download FnNAS ARM64 Base Image

Create the image directory:

```bash
mkdir -p work/fnnas/fnnas-arm64
```

Download the official ARM64 base image from:

```text
https://www.fnnas.com/download-arm
```

Place the downloaded file under:

```text
work/fnnas/fnnas-arm64/
```

Supported file names should match the upstream `renas` expectations.  A typical
name starts with `fnos_arm_` and ends with `.img` or `.img.xz`.

## Step 5: Package

```bash
cd work/fnnas
sudo ./renas -b orange-pi-5-ultra -k 6.18.y
```

Generated images are under:

```text
work/fnnas/out/
```

## Step 6: Flash And Test

Find the TF card device:

```bash
lsblk
```

Flash the image.  Replace `/dev/sdX` with the real TF card device.

```bash
sudo dd if=out/fnnas_rockchip_*.img of=/dev/sdX \
  bs=4M status=progress conv=fsync
```

Boot Orange Pi 5 Ultra, find its IP address from the router, then open:

```text
http://IP:5666
```

## GitHub Actions

The workflow in `.github/workflows/build-fnnas-orangepi5ultra.yml` can:

1. Build the Orange Pi 5 Ultra DTB.
2. Clone and patch the FnNAS packaging tree.
3. Optionally download a base image from a manually supplied URL.
4. Optionally run `sudo ./renas -b orange-pi-5-ultra -k 6.18.y`.
5. Upload the DTB, patch log, and generated image artifacts.

Because the official FnNAS ARM64 base image is distributed from the vendor
download page, the workflow does not hard-code a direct image URL.  Start it with
`base_image_url` only when you have a stable direct download URL.

## Most Likely Debug Points

- DTB compatibility: if boot fails, compare the Orange Pi BSP 6.1 DTS against
  the 5 Plus DTS used by the FnNAS kernel package and adjust unsupported nodes.
- Network: if the board boots but networking is absent, check PCIe and Ethernet
  nodes in the DTB first.
- Model database format drift: if upstream `model_database.conf` changes, rerun
  `scripts/prepare-fnnas.sh`; it validates that the final row contains the
  expected `FDTFILE`, `MODEL`, and `BOARD`.
