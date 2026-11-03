# Phase 5 — Build NetHunter kernel (WSL2)

**Goal:** Compile sm8350 kernel for porsche with NetHunter features + AnyKernel zip.

**Detailed walkthrough:** [05-build-kernel-detailed.md](05-build-kernel-detailed.md) · Docker `CONFIG_*`: [../docker-kernel-options.md](../docker-kernel-options.md)

## Checklist

- [ ] WSL toolchain ready (`verify-wsl.sh --require-toolchain`).
- [ ] Dry-run clone plan: `ROM=lineage scripts/wsl/clone-kernel-tree.sh` (no network until `CONFIRM=1`).
- [ ] Clone kernel + device tree: `CONFIRM=1 ROM=lineage|pixelos scripts/wsl/clone-kernel-tree.sh` (match installed ROM).
- [ ] Clone **device tree** for `porsche` (included in clone script).
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

## Repo commands

```bash
bash scripts/wsl/verify-wsl.sh --require-toolchain
ROM=pixelos bash scripts/wsl/clone-kernel-tree.sh
CONFIRM=1 ROM=pixelos bash scripts/wsl/clone-kernel-tree.sh
bash scripts/wsl/check-kernel-docker-config.sh ~/android/kernel/.config
```

## Notes

- Levion_kernel_OP9 reference in old docs is **404** — use Sakura only.
- Wi-Fi driver may be vendor module; confirm whether injection patch applies to your tree layout.
