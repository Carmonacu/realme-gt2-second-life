# Device record (RMX3311)

Captured via `check-adb-device.ps1` on **2026-10-30**. Update after ROM flashes or OTA upgrades.

| Field | Value |
|-------|--------|
| Model | **RMX3311** |
| `ro.product.device` | RE58B2L1 (Realme prop; port codename remains **porsche**) |
| Build (`ro.build.display.id`) | **RMX3311_15.0.0.1650(EX01)** |
| Firmware suffix | **EX01** (ColorOS 15 export/EU channel — not the older `EUEX` string) |
| adb serial | `YOUR_ADB_SERIAL` |
| Battery (last check) | 100% |

## OTA you need

Download a **Full OTA** zip that matches this **exact build** (or the same `15.0.0.1650(EX01)` lineage).

| Verified EU package (XDA / Stano36) | |
|---------------------------------------|---|
| Filename stem | `RMX3311_11.H.29_EUEX_202603191634` |
| MD5 | `efb2705f94cffb79a6ff8527ffb40b18` |
| Changelog (live) | https://gauss-componentotamanual.allawnofs.com/remove-d7d73202b5d43c3bf8420115af609441/component-ota/26/04/03/5f626fbc18e645b4ba5b14cf8d98d502.html |
| Zip CDN | **Dead** — `curl -I -L` → **404 NoSuchKey** on all documented EU/component URLs (verified **2026-10-31**). XDA host-swap trick does not help once the OSS object is gone. |
| XDA index | https://xdaforums.com/t/collection-of-ota-packages.4542941/ |

Search terms if links rot: `RMX3311` + `1650` + `EX01`, `RMX3311_11.H.29_EUEX`.

- Do **not** flash CN (`RMX3310`) or IN (`RMX3312`) packages.

### OTA hunt notes (2026-10-31)

| Source | Result for **1650 / H.29** |
|--------|----------------------------|
| XDA thread (pages 1–23) | Same Realme CDN links only; **no** working third-party mirrors (Mega, Drive, AFH, etc.). |
| OTA-Pulse web / app catalog | Queries vendor for letter **H** → returns **1305 (H.25)**, not 1650. |
| OPlus-Tracker `tomboy_pro.py` | Explicit `RMX3311_11.H.29_EUEX_202603191634 eu` → API **500**; `client_auto` → **H.25** link only. |
| realme-ota (pip) | Repo **DMCA** — unavailable. |
| realmefirmware.com / romprovider / firmwaredrive | Old OFP/XML builds only (≤ Android 14 in public listings); **no** 1650 full OTA found. |

### Optional fallback (Android 15 EU, **older** — not 1650)

| Package | `RMX3311EEA_11.H.25_EUEX_202510181132` → display **1305 (EX01)** |
|---------|---------------------------------------------------------------------|
| CDN | https://gauss-opexcostmanual-eu.allawnofs.com/remove-90310e4fd1ef95d66bfa162a8b300a24/component-ota/25/10/20/2d69a6715c2a420ebb24d18ca8b42da2.zip (**200 OK**, ~7.09 GB) |
| Safe for this phone? | **No** for “match current build” — flashing would **downgrade** from 1650. OK only as a separate EU A15 reference image (local install allowed per XDA). |

Place the **1650** zip in `downloads/` and run:

```powershell
.\scripts\windows\verify-downloads.ps1
.\scripts\windows\verify-ota-md5.ps1
```

Older plan examples use `…_EUEX_…` in the **zip filename**; your phone shows **EX01** in Settings — the verified EU package `RMX3311_11.H.29_EUEX_…` matches display build **1650 (EX01)** (see table above).
