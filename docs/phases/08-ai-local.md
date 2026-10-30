# Phase 8 — Local AI (llama.cpp)

**Goal:** Optional post-NetHunter setup — **CPU first**; GPU/NPU as experiments. Does not block earlier phases.

## Checklist

- [ ] Install/build **llama.cpp** with GGUF models (1B–8B Q4 realistic on SD888).
- [ ] **CPU baseline** in Termux, Kali chroot, or Docker container — measure tokens/s.
- [ ] **OpenCL (Adreno 660):** `-DGGML_OPENCL=ON`, `LD_LIBRARY_PATH=/vendor/lib64`; check compiler > `E031.38.01.00`; compare with `llama-bench` (may be slower than CPU).
- [ ] **Vulkan / Turnip (optional):** KGSL `/dev/kgsl-3d0` from glibc chroot — treat as experimental.
- [ ] **Hexagon v68 (optional):** QNN/Hexagon SDK, NDK build — high effort, low payoff on v68.
- [ ] Package **CPU-only** workflow in Docker for reproducibility if desired.
- [ ] Do **not** expect easy GPU/NPU passthrough into Docker without advanced device/lib mapping.

## Notes

- OpenCL vendor libs are **bionic** — practical path is Termux for OpenCL, chroot for Turnip.
- This phase runs when NetHunter + kernel are stable (Phase 6 complete or Option A from Phase 7).
