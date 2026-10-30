# Phase 5 — Build NetHunter kernel (WSL2)

**Goal:** Compile sm8350 kernel for porsche with NetHunter features + AnyKernel zip.

## Checklist

- [ ] WSL: run setup from `scripts/wsl/` when available; confirm ~40–60 GB disk.
- [ ] Clone kernel matching your ROM (e.g. `LineageOS/android_kernel_oneplus_sm8350` or PixelOS-Devices variant).
- [ ] Clone **device tree** for `porsche`.
- [ ] Clone [kali-nethunter-kernel-builder](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder) inside kernel tree.
- [ ] Study reference: [Sakura_Kernel_OP9Pro](https://github.com/Madara273/Sakura_Kernel_OP9Pro) (`staging_sakura`).
- [ ] Create `local.config` from builder `config` (arm64, porsche/lahaina defconfig, `IMAGE_NAME`, A/B slots).
- [ ] `./build.sh` → toolchains → compile clean build → **basic kernel boots**.
- [ ] Enable **HID + OTG** in defconfig; rebuild and smoke-test on device.
- [ ] Apply **qcacld-3.0 injection** (builder patches / `CONFIG_FEATURE_FRAME_INJECTION_SUPPORT`); rebuild.
- [ ] Enable **Docker** kernel options; run [check-config.sh](https://github.com/opencontainers/runc/blob/main/script/check-config.sh) on `.config` and later `/proc/config.gz`.
- [ ] Enable `IKCONFIG_PROC` for on-device config check.
- [ ] `./build.sh` → AnyKernel config (`porsche`, boot block, slot) → create **AnyKernel zip**.
- [ ] Store zip in `downloads/` (gitignored), note git SHA and defconfig name.

## Notes

- Levion_kernel_OP9 reference in old docs is **404** — use Sakura only.
- Wi-Fi driver may be vendor module; confirm whether injection patch applies to your tree layout.
