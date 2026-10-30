# WSL build environment

Kernel builds for Phase 5 run in **WSL2** (Ubuntu 22.04+ recommended).

Setup scripts (`setup-build-env.sh`, `verify-wsl.sh`) and `docs/wsl-build-environment.md` are added by the **WSL preparation agent** in the same project.

Until then:

1. `wsl --install` or install Ubuntu from Microsoft Store.
2. Allocate **40–60 GB** free disk inside WSL.
3. Install base packages: `build-essential`, `bc`, `bison`, `flex`, `libssl-dev`, `clang`, `lld`, `python3`, `git`, `ccache`, `zip`, `curl`, `wget`.

See [docs/phases/05-build-kernel.md](../../docs/phases/05-build-kernel.md).
