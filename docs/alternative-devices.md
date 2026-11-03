# Alternative devices — full Kali NetHunter

Use this list when **RMX3311 EU unlock stays blocked** ([STATUS.md](STATUS.md), [unlock-research.md](unlock-research.md)) but you still want **monitor mode, injection, HID**, or a **maintained NetHunter kernel**.

**Source of truth:** Kali **pre-built images** and device kernels — fetched **2026-10-31**:

- [Pre-created images](https://nethunter.kali.org/images.html)
- [Device kernels index](https://nethunter.kali.org/device-kernels.html)
- [NetHunter documentation hub](https://www.kali.org/docs/nethunter/) — notes **~110** kernel-supported devices and published images

Always confirm **exact codename**, **Android version**, and **ROM** (LineageOS / OxygenOS / stock) on the image row before buying or flashing.

---

## Tier 1 — Strong official support (shortlist)

### OnePlus 9 / 9 Pro (`lemonade` / `lemonadep`)

| Item | Detail |
|------|--------|
| **Kali images** | Listed on [images.html](https://nethunter.kali.org/images.html): **OnePlus 9 / 9 Pro** with **LineageOS 23.2**, **Evolution X**, **crDroid** (Android **16** channel in table snapshot) |
| **Kernel** | Active NetHunter kernel work for **lemonadep** ([GitLab MR !443](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels/-/merge_requests/443)) — injection modules, monthly update intent (**2025** thread) |
| **Unlock** | OnePlus historically allows **OEM unlock** on many global units (verify **your SKU** before purchase) |
| **Why pick it** | Close successor era to SD888; mature NetHunter community; Wi‑Fi injection path documented in MR |

### Google Pixel (unlocked bootloader)

| Device (examples on [images.html](https://nethunter.kali.org/images.html)) | Codename | Notes |
|-------------|----------|--------|
| Pixel (LoS 22.2) | `sailfish` | Older; still listed |
| Pixel 3 / 3 XL | `blueline` / `crosshatch` | Android 13 images |
| Pixel 4a / 4a 5G | `sunfish` / `bramble` | Android 12 images |
| Pixel 6a (LoS 23.2) | `bluejay-los` | Android **16**, **full** rootfs; community doc linked from Kali table |

**Why Pixel:** `fastboot flashing unlock` on supported Pixels; **easy AOSP/LoS** alignment; Google publishes images. **Tradeoff:** NetHunter image set is **not** every retail Pixel model — check table for **your** generation (Pixel 7/8 may rely on community kernels not in this snapshot).

### OnePlus 7 / 7T family (`oneplus7`)

| Item | Detail |
|------|--------|
| **Images** | Multiple rows: LineageOS **23.2** (Android **16**), OxygenOS 11 paths — [images.html](https://nethunter.kali.org/images.html) |
| **Docs** | [Installing NetHunter on OnePlus 7](https://www.kali.org/docs/nethunter/installing-nethunter-on-the-oneplus-7/) |
| **Why pick it** | Cheaper used hardware; long NetHunter history |

### OnePlus 5 / 5T (`oneplus5`)

Listed with **LineageOS 22**, Android **15** on [images.html](https://nethunter.kali.org/images.html) — older but still maintained in catalog.

---

## Tier 2 — Listed on Kali images (verify before buying)

Examples present on [images.html](https://nethunter.kali.org/images.html) (2026-10-31 snapshot):

| Device | Codename | Android (image row) |
|--------|----------|---------------------|
| OnePlus 11 5G | `salami` | OxygenOS 15 / 16 |
| OnePlus 6 / 6T | `oneplus6` | LoS 19.1 / 22.2, Android 15 |
| OnePlus 8 series | `oneplus8` | OOS 12 |
| Nothing Phone (1) | `spacewar` | Android 14 |
| Moto G Stylus 5G 2022 | `milanf` | LoS 23.2, Android 16 |
| Nubia Z17 | `nx563j` | LoS 22.2 — **5 GHz injection validated** per Kali notes |

**Kernel inventory (separate from images):** [device-kernels.html](https://nethunter.kali.org/device-kernels.html) lists many older Xiaomi / Nexus devices — cross-check **Qty Kernels &gt; 0** before assuming support.

---

## Not a NetHunter upgrade path

| Device | Reason |
|--------|--------|
| **Realme GT 2 RMX3311 EU** | Unlock **blocked** on stock A15; no official Kali image for `porsche` |
| **RMX3312 IN** | Different SKU; custom ROM/unlock paths do **not** transfer to EU 3311 ([unlock-research.md](unlock-research.md)) |

---

## Decision checklist

1. **Need Wi‑Fi injection on phone?** → Tier 1 **OnePlus 9** or **Pixel + matching Kali image**, not rootless GT2.
2. **Budget / secondary lab phone?** → OnePlus 7 or 5 + LoS image from [images.html](https://nethunter.kali.org/images.html).
3. **Stay on GT2 daily driver?** → [rootless-kali.md](rootless-kali.md) + [phases/08-ai-local.md](phases/08-ai-local.md); accept **no monitor mode**.

---

## Sources

| URL | Accessed |
|-----|----------|
| https://nethunter.kali.org/images.html | 2026-10-31 |
| https://nethunter.kali.org/device-kernels.html | 2026-10-31 |
| https://www.kali.org/docs/nethunter/ | 2026-10-31 |
| https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels/-/merge_requests/443 | 2026-10-31 |
| https://www.kali.org/docs/nethunter/installing-nethunter-on-the-oneplus-7/ | 2026-10-31 |
