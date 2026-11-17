# WSL build environment

Kernel builds for Phase 5 run in **WSL2** (Ubuntu 22.04+). Verified: **Ubuntu 24.04.3 LTS**, WSL version **2**.

## Quick start

From Ubuntu (WSL):

```bash
export REPO_ROOT="/mnt/c/Users/<user>/path/to/realme-gt2-second-life"   # ajusta tu clon
bash "$REPO_ROOT/scripts/wsl/verify-wsl.sh"
bash "$REPO_ROOT/scripts/wsl/verify-wsl.sh" --require-toolchain
bash "$REPO_ROOT/scripts/wsl/setup-build-env.sh"
```

Dry run: `setup-build-env.sh --dry-run`  
**Install requires interactive Ubuntu** (sudo password); non-TTY runs print instructions and exit.

Windows helper: `../windows/start-wsl-build-setup.ps1` (opens Ubuntu; paste the two `bash` lines it prints — sudo needs a TTY).

Full notes: [docs/wsl-build-environment.md](../../docs/wsl-build-environment.md)

Suggested kernel tree path: `~/android/kernel/sm8350` (see `clone-kernel-tree.sh`).

See also [docs/phases/05-build-kernel.md](../../docs/phases/05-build-kernel.md) and [05-build-kernel-detailed.md](../../docs/phases/05-build-kernel-detailed.md).
