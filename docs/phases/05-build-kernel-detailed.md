# Phase 5 — NetHunter kernel build (detailed)

Step-by-step companion to [05-build-kernel.md](05-build-kernel.md). Run everything in **WSL2 Ubuntu** with **40–60 GB** free disk and deps from [../wsl-build-environment.md](../wsl-build-environment.md) when available.

**Device:** Realme GT 2 (RMX3311 EU), codename **porsche**, **SM8350**, kernel **5.4**, Wi-Fi **WCN6856** / **qcacld-3.0**.

---

## 0. Layout on disk (recommended)

```text
~/android/
  kernel/                    # KERNEL_DIR — sm8350 tree (multi-GB; clone when ready)
    kali-nethunter-kernel-builder/
    local.config             # copy from scripts/wsl/local.config.example
  device/
    realme_porsche/          # device tree only (smaller clone)
  reference/
    Sakura_Kernel_OP9Pro/     # read-only reference (optional clone)
```

Set `KERNEL_DIR` before using [../../scripts/wsl/clone-kernel-tree.sh](../../scripts/wsl/clone-kernel-tree.sh).

---

## 1. Clone kernel source (match your ROM)

Use the **same kernel branch/tag** your installed ROM was built from (PixelOS 16 or LineageOS 23 for porsche).

| ROM | Kernel repo (documented in clone script) | Device tree |
|-----|------------------------------------------|-------------|
| **LineageOS** | `https://github.com/LineageOS/android_kernel_oneplus_sm8350` | `https://github.com/LineageOS/android_device_realme_porsche` |
| **PixelOS** | `https://github.com/PixelOS-Devices/kernel_oneplus_sm8350` (verify org/repo name on [pixelos.net](https://www.pixelos.net/download/porsche)) | `https://github.com/PixelOS-Devices/android_device_realme_porsche` |

**Why OnePlus sm8350?** Community ROMs for porsche reuse the **OnePlus 9 / 9 Pro** kernel tree; porsche DTS and board config are added on top.

**Do not clone yet** if you are only scaffolding — run the clone script with `CONFIRM=1` when ready:

```bash
cd /mnt/c/Users/<you>/Desktop/Proyects/realme-gt2-second-life/scripts/wsl
ROM=lineage KERNEL_DIR=~/android/kernel CONFIRM=1 ./clone-kernel-tree.sh
```

After clone:

- Confirm **porsche** appears under `arch/arm64/boot/dts/vendor/` (or your tree’s equivalent).
- Note the **defconfig** name your ROM uses (often `vendor/porsche_defconfig`, `lahaina_*`, or similar — check device tree `BoardConfig.mk` / ROM kernel README).

---

## 2. Reference kernel — Sakura OP9 Pro

Study injection and NetHunter Kconfig on a **working** OP9 Pro port (same SoC, same driver class):

- Repo: [Madara273/Sakura_Kernel_OP9Pro](https://github.com/Madara273/Sakura_Kernel_OP9Pro)
- Branch: **`staging_sakura`**

Compare (do not blindly copy vendor blobs):

- Defconfig deltas for **USB HID**, **OTG**, **NetHunter** options.
- **qcacld-3.0** changes and `CONFIG_FEATURE_FRAME_INJECTION_SUPPORT`.
- Any **Docker-related** `CONFIG_*` already enabled there.

Optional clone:

```bash
git clone -b staging_sakura --depth 1 \
  https://github.com/Madara273/Sakura_Kernel_OP9Pro.git ~/android/reference/Sakura_Kernel_OP9Pro
```

**Note:** `varakumar01/Levion_kernel_OP9` is **404** — use Sakura only.

---

## 3. Install kali-nethunter-kernel-builder

Inside **`KERNEL_DIR`** (kernel root):

```bash
cd "$KERNEL_DIR"
git clone https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder.git
cp kali-nethunter-kernel-builder/config local.config   # if no example yet
# Prefer project template:
cp /mnt/c/Users/<you>/Desktop/Proyects/realme-gt2-second-life/scripts/wsl/local.config.example local.config
```

Edit `local.config`:

- `ARCH=arm64`
- `DEFCONFIG=` — your porsche vendor defconfig (placeholder until tree is cloned)
- `IMAGE_NAME=` — usually `Image` or `Image.gz-dtb` (tree-dependent)
- `boot_block` / AnyKernel — Realme A/B layout (see builder docs and device tree)
- Codename **`porsche`**

See [../../scripts/wsl/local.config.example](../../scripts/wsl/local.config.example).

---

## 4. `build.sh` flow — **S → 2 → (iterate) → 8 → 6**

From `kali-nethunter-kernel-builder/`:

| Step | Menu key | Purpose |
|------|----------|---------|
| Toolchains | **`S`** | Download/setup cross toolchain (first time) |
| Clean build | **`2`** | Full compile from defconfig — **validate a plain kernel boots** before NetHunter extras |
| (edit defconfig) | **`3`** / manual | Enable features per section below; rebuild with **`2`** |
| AnyKernel edit | **`8`** | Set codename **`porsche`**, `boot_block`, slot A/B |
| Package | **`6`** | Create **AnyKernel3** zip for Magisk / NetHunter flasher |

**First milestone:** menu **`S`**, then **`2`**, flash resulting boot image on device (Magisk-patched if needed) and confirm boot **before** injection/Docker changes.

---

## 5. Enable features in phases (defconfig)

Apply in order; rebuild with **`2`** after each group and test on device when possible.

### 5.1 HID + OTG (low risk)

Use Sakura `staging_sakura` and [Kali NetHunter kernel docs](https://www.kali.org/docs/nethunter/nethunter-kernel-8-config-1/) as guides. Typical areas:

- USB gadget / configfs
- HID function drivers NetHunter expects
- OTG / dual-role USB where applicable

Smoke-test: NetHunter HID / BadUSB / OTG attach (Phase 6).

### 5.2 qcacld-3.0 frame injection

The builder ships **universal injection patches** (2026 commits on upstream builder — kimocoder/Loukious lineage). Workflow:

1. In builder menu, apply **Wi-Fi injection / qcacld** patches (wording varies by builder version).
2. Enable in Kconfig / defconfig:

   ```text
   CONFIG_FEATURE_FRAME_INJECTION_SUPPORT=y
   ```

3. Confirm the driver tree is **qcacld-3.0** (WCN6856 on porsche), not an out-of-tree module-only layout that bypasses your patch path.
4. Rebuild (**`2`**), flash, then test monitor mode + `aireplay-ng --test` in Phase 6.

If injection fails on internal `wlan0`, Phase 7 (USB adapter) remains the fallback.

### 5.3 Docker (kernel options)

Enable options listed in [../docker-kernel-options.md](../docker-kernel-options.md) (derived from Docker/runc [`check-config.sh`](https://github.com/opencontainers/runc/blob/main/script/check-config.sh)).

Quick local check before flash:

```bash
./scripts/wsl/check-kernel-docker-config.sh "$KERNEL_DIR/.config"
```

Optional: download upstream checker and compare:

```bash
curl -fsSL -o /tmp/check-config.sh \
  https://raw.githubusercontent.com/opencontainers/runc/main/script/check-config.sh
chmod +x /tmp/check-config.sh
/tmp/check-config.sh --kernel-config "$KERNEL_DIR/.config"
```

Reference kernel with Docker helper: NetHunter `c2s-oui-ksu` ([MR !448](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels/-/merge_requests/448)) — **`nh-docker`** script for iptables/forwarding on device.

### 5.4 `IKCONFIG_PROC` (required for on-device validation)

In defconfig:

```text
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
```

After boot, the running kernel exposes **`/proc/config.gz`**.

---

## 6. Validate configuration

### 6.1 On WSL2 (before flash)

```bash
# Docker-focused grep checker (this repo)
./scripts/wsl/check-kernel-docker-config.sh "$KERNEL_DIR/.config"

# Full Docker checker (recommended)
/tmp/check-config.sh --kernel-config "$KERNEL_DIR/.config"
```

Fix any `missing` / `not set` lines; rebuild.

### 6.2 On device (after flash)

```bash
adb shell su -c 'zcat /proc/config.gz' > /tmp/device-config.gz.txt
# Or save binary:
adb shell su -c 'cat /proc/config.gz' > device-config.gz
zcat device-config.gz | grep -E 'IKCONFIG|OVERLAY|NET_NS|FEATURE_FRAME_INJECTION'
```

Re-run `check-config.sh` against exported config:

```bash
zcat device-config.gz > /tmp/device.config
/tmp/check-config.sh --kernel-config /tmp/device.config
```

If `/proc/config.gz` is missing, **`IKCONFIG_PROC`** was not enabled in the flashed image — fix defconfig and rebuild.

---

## 7. Package for install

1. `./build.sh` → **`8`** — AnyKernel: codename **`porsche`**, correct **`boot_block`**, A/B **`slot`** if applicable.
2. `./build.sh` → **`6`** — produce **`AnyKernel3-*.zip`**.
3. Copy zip to PC `downloads/` (gitignored). Record:
   - Kernel git SHA
   - Defconfig name
   - Builder version / patch set
   - ROM version the kernel targets

Install in Phase 6 via Magisk / NetHunter kernel tab.

---

## 8. Troubleshooting

| Issue | Action |
|-------|--------|
| Defconfig not found | Read device tree `BoardConfig.mk` / ROM kernel manifest for exact name |
| Compile errors after injection patch | Compare with Sakura branch; check qcacld path |
| Boot loop after flash | Restore stock `boot`/`vendor_boot` from Phase 3 backup |
| Docker fails on device | Re-run `check-config.sh` on `/proc/config.gz`; consider `nh-docker` |
| No `/proc/config.gz` | Enable `CONFIG_IKCONFIG` + `CONFIG_IKCONFIG_PROC`, rebuild |

---

## Related files

- [../docker-kernel-options.md](../docker-kernel-options.md)
- [../../scripts/wsl/local.config.example](../../scripts/wsl/local.config.example)
- [../../scripts/wsl/clone-kernel-tree.sh](../../scripts/wsl/clone-kernel-tree.sh)
- [../../scripts/wsl/check-kernel-docker-config.sh](../../scripts/wsl/check-kernel-docker-config.sh)
