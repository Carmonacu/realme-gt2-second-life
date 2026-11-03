# downloads/ (local only, gitignored)

Store **large firmware files here** on your PC. Nothing in this folder is committed except this README and `.gitkeep`.

Wrong or obsolete zips: move to `downloads/_wrong/` (do not delete unless you are sure).

## Required before unlock / flash (Phase 0)

| File | Purpose |
|------|---------|
| **Full OTA** zip | Must match your **RMX3311** build string. This device: **`RMX3311_15.0.0.1650(EX01)`** — see [device-record.md](../docs/device-record.md). |
| Optional: **EU OFP** | EDL/MSM rescue if soft restore fails (keep offline backup). |

### Target package (your phone) — **CDN dead 2026-10-31**

| Field | Value |
|-------|--------|
| Device | Realme GT 2 5G **RMX3311EEA** (Europe **EUEX**) |
| Package name | `RMX3311_11.H.29_EUEX_202603191634` |
| Display build | **`RMX3311_15.0.0.1650(EX01)`** |
| MD5 | `efb2705f94cffb79a6ff8527ffb40b18` |
| Local install | **Forbidden** (non-display OTA) |

**XDA canonical thread** (Stano36, OP maintained — no Mega/Drive/MediaFire mirrors found; only Realme CDN + OFP refs):

- https://xdaforums.com/t/collection-of-ota-packages.4542941/ (GT 2 **RMX3311 EUEX** block; also pages 2–23)

**Documented zip URLs (all tested `curl -I -L` → HTTP 404, ~445 B XML `NoSuchKey`):**

- https://gauss-componentotamanual.allawnofs.com/remove-d7d73202b5d43c3bf8420115af609441/component-ota/26/03/23/6d95a198c77648949bd5866b85274712.zip
- https://gauss-opexcostmanual-eu.allawnofs.com/remove-d7d73202b5d43c3bf8420115af609441/component-ota/26/03/23/6d95a198c77648949bd5866b85274712.zip

Host swaps from XDA (*componentotacostmanual* → *otacostmanual* → *opexcostmanual-eu*) were tried on the same path — still **404** (object removed from OSS, not a browser gate).

**Metadata still online (changelog only):**

- https://gauss-componentotamanual.allawnofs.com/remove-d7d73202b5d43c3bf8420115af609441/component-ota/26/04/03/5f626fbc18e645b4ba5b14cf8d98d502.html

**OTA server query (2026-10-31):**

- [OPlus-Tracker](https://github.com/JerryTse-OSS/OPlus-Tracker) `tomboy_pro.py RMX3311_11.H.29_EUEX_202603191634 eu` → **HTTP 500** from vendor API.
- `tomboy_pro.py RMX3311 eu --mode client_auto` → latest queryable **H.25 / 1305**, not H.29.
- [R0rt1z2/realme-ota](https://github.com/R0rt1z2/realme-ota) — **GitHub DMCA takedown** (Sep 2025); not installable.

**[OTA-Pulse](https://0x8008.github.io/otapulse-web/)** — catalog only maps **Android 15 → letter H**; live query returns the same **1305 (H.25)** package as the server, **not** 1650. Do **not** expect 1650 from the web UI today.

**Naming when you eventually obtain it:** `RMX3311_11.H.29_EUEX_202603191634_full_ota.zip`

### Working CDN fallback (older EU Android 15 — **not** your build)

Use only if you accept **1305** instead of **1650** (downgrade from your current phone — **not** a safe “same build” backup).

| Field | Value |
|-------|--------|
| Package | `RMX3311EEA_11.H.25_EUEX_202510181132` / **`RMX3311_15.0.0.1305(EX01)`** |
| Size | **7 088 107 685** bytes (~6.6 GiB) |
| MD5 | Not listed on XDA — verify locally after download |
| Local install | Allowed (per XDA) |

**Working links (`HTTP 200`, same blob):**

- https://gauss-opexcostmanual-eu.allawnofs.com/remove-90310e4fd1ef95d66bfa162a8b300a24/component-ota/25/10/20/2d69a6715c2a420ebb24d18ca8b42da2.zip
- https://gauss-opexcostmanual-eu.allawnofs.com/remove-24c49209b0dbfc8b29d02327e1cf9592/component-ota/25/10/20/2d69a6715c2a420ebb24d18ca8b42da2.zip (alternate `remove-` token from OPlus-Tracker)

Changelog: https://gauss-componentotamanual.allawnofs.com/remove-90310e4fd1ef95d66bfa162a8b300a24/component-ota/25/11/12/0cc748da536b4fb38e4dd02bf189ed34.html

**Do not use** Android 12 **`RMX3311_11.A.22_…`** (OTA-Pulse / server still exposes it for letter **A**). Keep out of `downloads/` or under `_wrong/`.

## Later phases

| File | Phase |
|------|--------|
| PixelOS / Lineage **ROM** zip for `porsche` | 4 |
| NetHunter **AnyKernel** zip (your build) | 5 → 6 |
| Extracted `boot.img`, `vendor_boot.img`, `dtbo.img`, `modem.img` | 3–4 (from OTA) |

## Verify from repo root (Windows)

```powershell
.\scripts\windows\verify-downloads.ps1
.\scripts\windows\verify-ota-md5.ps1   # expects MD5 efb2705f… (1650 only)
```
