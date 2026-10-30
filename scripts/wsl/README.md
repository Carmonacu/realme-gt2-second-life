# WSL build environment

Kernel builds for Phase 5 run in **WSL2** (Ubuntu 22.04+). Verified: **Ubuntu 24.04.3 LTS**, WSL version **2**.

## Quick start

From Ubuntu (WSL):

```bash
bash /mnt/c/Users/carmo/Desktop/Proyects/nethunter-realme-gt2-porsche/scripts/wsl/verify-wsl.sh
bash /mnt/c/Users/carmo/Desktop/Proyects/nethunter-realme-gt2-porsche/scripts/wsl/setup-build-env.sh
```

Dry run: `setup-build-env.sh --dry-run`

Full notes: [docs/wsl-build-environment.md](../../docs/wsl-build-environment.md)

Suggested kernel tree path: `~/android/kernel/sm8350` (see `clone-kernel-tree.sh`).

See also [docs/phases/05-build-kernel.md](../../docs/phases/05-build-kernel.md) and [05-build-kernel-detailed.md](../../docs/phases/05-build-kernel-detailed.md).
