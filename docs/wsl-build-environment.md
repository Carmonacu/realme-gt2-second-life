# WSL2 build environment (Phase 0)

NetHunter kernel work for Realme GT2 Porsche (SM8350) assumes **WSL2** with **Ubuntu 22.04+**. This host was verified with Ubuntu 24.04 LTS on WSL2.

## Prerequisites on Windows

1. WSL2 enabled with an Ubuntu distro (default `Ubuntu`).
2. **Disk space:** reserve **~40–60 GB** free inside the Linux filesystem (WSL `ext4.vhdx`), not only on `C:`. Kernel sources, `ccache`, and build artifacts grow quickly.
3. Clone this repo on the Windows side or inside WSL; scripts live under `scripts/wsl/`.

Check WSL from PowerShell:

```powershell
wsl -l -v
```

Ubuntu should show **VERSION 2**. Start it if stopped:

```powershell
wsl -d Ubuntu
```

## Verify WSL2 and disk

From WSL (or `wsl -d Ubuntu -- bash ...`):

```bash
bash /mnt/c/Users/carmo/Desktop/Proyects/nethunter-realme-gt2-porsche/scripts/wsl/verify-wsl.sh
```

The script exits non-zero if the environment is not WSL2. It prints `df` for `$HOME` and `/` so you can confirm free space.

## Install build packages

Run once on a fresh Ubuntu WSL instance:

```bash
cd /mnt/c/Users/carmo/Desktop/Proyects/nethunter-realme-gt2-porsche
bash scripts/wsl/setup-build-env.sh --help
bash scripts/wsl/setup-build-env.sh --dry-run   # preview only
bash scripts/wsl/setup-build-env.sh             # installs via apt
```

**Do not** run a full `apt upgrade` unless you intentionally maintain the distro; the setup script only installs the listed build dependencies.

Installed packages include: `build-essential`, `bc`, `bison`, `flex`, `libssl-dev`, `clang`, `lld`, `python3`, `git`, `ccache`, `repo` (when available in apt), `zip`, `curl`, `wget`, and related basics.

### Optional (Kali / NetHunter-specific)

On Kali or when following [kali-nethunter-kernel-builder](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder) docs, you may additionally need tools such as `device-tree-compiler`, `lz4`, `zstd`, `cpio`, and sparse utilities. Install those per the upstream README when you clone the builder.

## Suggested kernel tree layout

After cloning **kali-nethunter-kernel-builder**, a common layout is:

```text
~/android/kernel/sm8350
```

Keep large trees under the WSL home directory (`~/...`) for performance, not under `/mnt/c/...`.

## Next steps

1. Run `verify-wsl.sh` after setup.
2. Clone kali-nethunter-kernel-builder and vendor/device kernel sources per project docs.
3. Proceed to Phase 1 kernel configuration and build scripts in this repository.
