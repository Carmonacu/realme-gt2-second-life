# Bootloader unlock research — RMX3311 EU (porsche)

**Research date:** 2026-10-31  
**Device context:** RMX3311, build `RMX3311_15.0.0.1650(EX01)` (ColorOS 15 / H.29 EUEX channel), `fastboot getvar unlocked` → `no`, Deep Testing → “model not supported”.  
**Scope:** Web research only (no adb/fastboot on device).  
**Project constraint:** Never flash CN/IN firmware on RMX3311; recovery = dumps + EU OTA.

---

## Executive summary (evidence-weighted)

| Path | Verified for RMX3311 EU on A14/A15? | Notes |
|------|-------------------------------------|--------|
| Deep Testing on stock EU A15 | **No** — symptom matches widespread reports | User state + forum pattern |
| `deeptesting-junk.pl` / server bypass | **Was** working on old EU build; **explicitly dead** | XDA OP marks “NOT WORK ANYMORE” |
| Rollback → Deep Testing → unlock → restore EU | **Partially documented** (Stano36); **success not verified on A15 1650** | Region-swap tricks; CN path conflicts with project rules |
| EDL / Qualcomm Toolbox / paid MSM | **No GT2 RMX3311 EU guide fetched**; SM8350 loaders are device-specific | GT Master Edition ≠ porsche |
| Official Realme EU unlock | **No supported method** for GDPR/EU GT2 in primary sources | China-only quota policy; old EU support email |

**Phase 2 gate:** With “model not supported” on current firmware and no verified safe EU path on Android 15, the NetHunter plan should treat unlock as **blocked** until new primary evidence appears—or accept **high brick/IMEI risk** on Stano36-style rollback (conflicts with CN ban if CN packages are used).

---

## 1. Unlock on RMX3311 EU (Android 14 / 15, 2024–2026)

### Verified (fetched pages)

**A. Stano36 unlock test thread (Apr 30, 2024 → Oct 2024 result)**  
[Unlock bootloader for RMX3311 - Test](https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/)

- Maintainer sought testers for a new method; PC required after approval.
- On GT2-related testing: old Deeptest “without connection”; new Deeptest → **unsupported device**.
- Linked experiment: applicant got **approval date Oct 8**, request **approved**, but **“Fastboot didn't show up”** — unlock **not completed**. Stano36: **“Testing failed !”** (earlier tester: Deeptest for another model → device not supported on global GT2 attempt).

**B. Historical EU unlock via API script (superseded)**  
[Unlock BL on Realme GT2 RMX3311(GDPR)](https://xdaforums.com/t/unlock-bl-on-realme-gt2-rmx3311-gdpr.4585749/)

- Guide author reported success on **`RMX3311_11.C.10_EU_202303171905`** using `deeptesting-junk.pl`, then official fastboot flow.
- Same post is marked **`!!NOT WORK ANYMORE!!!!`** with direction to Telegram.
- Thread discussion (not independently verified): “global has been fixed and the unlock is impossible again”; India may still work on **RMX3312**, not EU SKU.

**C. PixelOS install path = Indian variant only (verified scope)**  
[Realme GT 2 (RMX3312) - PixelOS Android 14 (Full Guide)](https://xdaforums.com/t/realme-gt-2-rmx3312-pixelos-android-14-full-guide.4663480/) (Mar 24, 2024)

- Author: **“I've tried this on Indian version and it is working fine.”**
- Reply to “India and China only?” — confirmed **Indian RMX3312**.
- Jun 14, 2025: user asks if **RMX3311** works — **no maintainer “yes” captured in fetched page**.

**D. XDA global ROM thread (EU limitation, 2022-era posts in thread)**  
[How to Unlock Bootloader and Install Global ROM](https://xdaforums.com/t/how-to-unlock-bootloader-and-install-global-rom.4450729/page-2)

- Quote attributed to user **henrique araujo**: **“unfortunately the 3311 has no way to unlock it yet”**.
- Another user: Deep Test from Realme official post **doesn't work on 3311**, **only chinese and indian variants**.

**E. Reddit (secondary, consistent with EU block)**  
[Realme GT 2 Bootloader Unlock Disabled](https://www.reddit.com/r/Realme/comments/1g7weqv/realme_gt_2_bootloader_unlock_disabled_any/) — Deep Test **“This phone model doesn't support Deep Testing”**; months of retries (~2024–2025 thread activity in snippet).  
[Realme GT 2 battery / unlock](https://www.reddit.com/r/Realme/comments/1n2e2eq/realme_gt_2_terrible_battery_drain_seeking_advice/) — **Aug 28, 2025** comment: European **RMX3311**, **“they don't allow unlocking at all the European ones”** (anecdote).

### Hearsay / blocked fetch / low-trust (not verified on fetch)

- XDA [4739634](https://xdaforums.com/t/unlocking-bootloader-rmx3312-realme-gt-2-realme-ui-5-0-android-14.4739634/) — bunny.net blocked full fetch; search snippets claim **CN rollback + Deeptest + success** and **new Deep Testing APK / 2-month penalty** for old APK. Treat as **lead**, not proof for RMX3311 EU A15.
- XDA [4566661 page-2](https://xdaforums.com/t/any-method-to-unlock-rmx331-gdpr-eu-version.4566661/page-2) — blocked fetch; snippets mention **Jul 12, 2025** Stano36 post on new APK and conflicting **Aug 2025** “unlocked successfully” vs **3312 no hope** posts.
- XDA OTA collection post #90563674 — blocked fetch; snippet: **“Unlocking only works on Android version 14”** and Telegram claim **ARB index 0** — **unverified**.
- [hosbootloader.blogspot.com (Jul 2025)](https://hosbootloader.blogspot.com/2025/07/how-to-unlock-bootloader-on-realme-2025.html) — claims **Deep Testing shutdown 10 Jul 2025**; **not corroborated** by Realme primary docs in this research.

### Not applicable / no evidence for RMX3311

- **mtkclient** — MediaTek only; porsche is **SM8350**.
- **Qualcomm Toolbox / EDL unlock** — documented for **RMX3360/3363 GT Master** ([XDA 4782377](https://xdaforums.com/t/guide-unlock-bootloader-on-realme-gt-master-edition-rmx3360-rmx3363-without-deep-testing-using-qualcomm-toolbox.4782377/)); **porsche not listed**.
- **4PDA** — fetched section discusses **GT Master** “Model not supported” + EDL method, **not RMX3311**.

---

## 2. Downgrade (A15 → A12/A13) on RMX3311

### Verified

**Primary guide:** [Rollback RMX3311](https://xdaforums.com/t/rollback-rmx3311.4622841/) — Stano36, **start Sep 1, 2023**, **last edited Mar 18, 2025**.

- **No official Realme rollback package for RMX3311 EU** — “alternative method that works with a **locked bootloader**.”
- **Stage 1:** `Fake_Rollback` (EU `C.05` or TR `C.10`) + **`RMX3312_ROLL_BACK_android12_IN.zip`**, renamed `ota.zip`, **local update + split-screen file swap**; requires **`Force activities to be resizable`** in Developer options ([downgrade thread confirms](https://xdaforums.com/t/downgrade-rmx3311-android-14-0-0-1100-ex01.4704269/) — Settings split-screen blocked until that toggle is on).
- **Stage 2:** Modified EU full OTA **`RMX3311_11.A.21_EU_wipe.zip`** via **`OPLocalUpdate_For_Android12.apk`** after clearing Software Update app data.
- **Explicit warning:** after stage 1, **“device without IMEI and SIM”**; Stano36 confirms **RMX3311 stays without SIM/IMEI if you stay on Indian build**; **stage 2 restores** SIM/IMEI (user reports in thread, Sep–Oct 2023).
- **Updaters:** `Updater_Android14.apk` / **`Updater_Android15.apk`** listed for running the trick from newer OS (guide edit 2025) — **does not prove** every A15 build passes verification.
- **Page 5 quote (search snippet only — page not fully fetched):** Stano36: **“If you only want to Rollback the EU version, you must use Rollback_Android12; to unlock the bootloader, use Rollback_Android13.”** — Implies unlock path needs **A13 rollback package**, not A12-only EU restore.

**Brick / region risk (verified thread posts):**  
[RMX3311 GDPR downgrade A13 to A12](https://xdaforums.com/t/rmx3311-gdpr-version-downgrade-a13-to-a12.4543663/)

- **“European version of the RMX3311 does not have a Rollbackpack available”** (only RMX3312 India rollback cited).
- Warning: changing region via Full OTA **“will certainly not overwrite all partitions”** — manifest region mismatch (**India vs Europe**) → **“a little is enough and the brick is born.”**

**Downgrade without unlock:** [Is it possible to downgrade without unlocked bootloader?](https://xdaforums.com/t/is-it-possible-to-downgrade-without-unlocked-bootloader.4618549/) — Stano36 confirms IN rollback possible locked BL; **temporary no SIM/IMEI** until EU OTA restored.

### Anti-rollback (ARB)

- **No official ARB table for RMX3311** found in fetched primary docs.
- **Unverified:** Telegram via XDA OTA post — “ARB index is 0” (snippet only).
- **Risk for this project:** Downgrading **1650 → 1305** (known older EU A15 OTA in `device-record.md`) is a **major version jump backward**; even if local install is “Allowed” on catalog metadata, **fuse/verification behavior on H.29 is not documented** here.

### Conflict with project rules

- Stano36 / XDA **4739634** (snippet) describes **CN rollback (`RMX3310_ROLL_BACK_android13_CN.zip`)** and completing unlock on **CN ROM** before returning to EU — **violates “NEVER flash CN/IN firmware on RMX3311.”**
- Stage 1 uses **Indian rollback package** on EU hardware — still a **region swap** with IMEI/baseband risk; project allows caution but not CN/IN **as final target**; using IN rollback as intermediate is what community guides require for A12 path.

### Recovery impact (this repo)

- Full OTA for **1650** URLs **404** per `device-record.md` (2026-10-31). Rollback/unlock experiments **without** a verified 1650 restore zip **increase unrecoverable brick risk**.

---

## 3. Deep Testing — “model not supported”

### Verified pattern

- **4669611:** new Deeptest → **unsupported device**; old APK disconnected.
- **4585749:** EU global unlock **closed** after server-side fix (thread narrative).
- **Reddit / XDA:** same English message **“This phone model doesn't support Deep Testing”** / **doesn't support Deep Testing** for GT2 EU.

### Reported fixes (mixed verification)

| Report | Source quality | Notes |
|--------|----------------|-------|
| Use **model-specific** Deep Testing APK from Realme India tutorial | Verified for **RMX3312** flow | Not evidence for **3311 EU** eligibility |
| **New BL Unlock Tool APK**; old APK → **2-month re-apply lockout** | Stano36 quoting Realme community notice in **4739634 snippet** | Fetch blocked; align with Realme CN quota posts |
| **Rollback to A13/A14** then apply | Stano36 rollback page 5 snippet | Unlock-oriented, not “fix on A15” |
| **HeyTap account / VPN / region switch** | Mostly forum hearsay | No primary Realme EU doc |
| **Tap version in Settings** hidden unlock | **Not found** in fetched Realme EU docs | Deep Testing remains the named official channel in India tutorials |

**Realme China policy (not EU):** IT之家 / Sina repost of Realme community **2025-01-19** — Deep Testing quotas for **mainland China purchased devices**; GT series **300 slots** first month then **200/month** ([finance.sina.cn](https://finance.sina.cn/tech/2025-01-19/detail-inefnhpe4802112.d.html?vt=4)). **Does not extend to RMX3311 EU SKU.**

---

## 4. Custom ROM maintainers (Phase 4)

### LineageOS

- **`https://wiki.lineageos.org/devices/porsche/` → 404** (fetched 2026-10-31).
- [LineageOS device list](https://wiki.lineageos.org/devices/) — **no Realme GT 2 / porsche** entry (Realme section lists other codenames only).
- **Conclusion:** No official LineageOS wiki unlock prerequisite for porsche; any porsche ROM in this project is **out-of-tree**.

### PixelOS

- [pixelos.net/download/porsche](https://www.pixelos.net/download/porsche) — **Active**, **Android 16**, last updated **17 Jan 2026** (fetched metadata).
- Install docs on XDA still assume **Deep Testing unlock** ([India tutorial](https://xdaforums.com/t/realme-gt-2-rmx3312-pixelos-android-14-full-guide.4663480/)).
- XDA PixelOS 16 thread reports: flashing **RMX3312-oriented** artifacts on **3311** can cause **IMEI loss**; recovery = **return to stock RMX3311** or flash **RMX3311 `modem.img`** ([4650893 page 5 snippets](https://xdaforums.com/t/rom-16-official-pixelos-aosp-stable.4650893/page-5)).

**Phase 4 dependency:** **Unlocked bootloader** + correct **modem/partition** alignment for **RMX3311** — not satisfied today.

---

## 5. Official / legit alternatives (EU 2026)

### Verified historical EU position (Realme 8 Pro — may reflect policy culture)

[XDA Realme 8 Pro unlock](https://xdaforums.com/t/unlock-bootloader-realme-8-pro.4263875/page-2) — user quotes **realme Europe** email: **“we don't unlock the bootloader anymore”**; GDPR ROM **without Deep Test tutorial**.

Not GT2-specific, but **only fetched Realme Europe statement** on bootloader program.

### TheCustomRom aggregator (Oct 19, 2026 fetch)

[Realme Deep Testing guide](https://thecustomrom.com/guides/realme-deep-testing) — secondary compilation stating many global models have **no official unlock**; points to LineageOS device pages for model checks. Useful framing, **not a Realme legal document**.

### Settings “tap version” unlock

**No evidence** in fetched Realme EU/GT2 docs. Official path remains **Deep Testing app** where Realme publishes support (India/China posts).

---

## 6. Rollback-unlock claim vs this device (user hypothesis)

**Claim:** Local update + split-screen → old Android 12 (or CN) → Deep Testing works → wait ≤7 days → `fastboot flashing unlock` → update to latest.

**Assessment:**

| Step | Evidence |
|------|----------|
| Split-screen local update downgrade | **Verified mechanism** for **IN rollback → EU A12** ([4622841](https://xdaforums.com/t/rollback-rmx3311.4622841/)) |
| Deep Testing works after EU A12 restore only | **Weak** — EU A12 restore returns normal IMEI; **unlock eligibility for 3311 EU still disputed** |
| CN / IN firmware for Deeptest | **Snippets** in 4739634; **conflicts with project CN/IN ban**; IMEI loss until EU restore |
| A13 rollback for unlock | **Stano36 page-5 snippet** — unlock tied to **Rollback_Android13**, not A12-only |
| On **A15 1650** today | **No verified success chain**; user already sees **model not supported** on stock |
| After unlock, return to **1650** | **1650 full OTA not mirrored** in repo hunt — high restore risk |

---

## 7. Recommended decision matrix (for PLAN Phase 2)

1. **Stop / pause NetHunter device path** if policy is “no unlock → stop” (`PLAN.md` stop condition) — **matches current evidence** on stock A15 EU.
2. **Do not start rollback** until: (a) **verified Full OTA 1650** (or MSM EU OFP path) on disk, (b) explicit acceptance of **IMEI/SIM/brick** risk, (c) clarification whether guide uses **CN/IN** packages (project forbids CN; IN rollback is community-standard but risky).
3. **Monitor** Stano36 XDA/Telegram for **RMX3311 A15**-specific unlock retest — last structured test **failed at fastboot stage** (Oct 2024).
4. **Do not use** dead `deeptesting-junk.pl` path or random “Oppo/Realme unlock tools” without **GT2 RMX3311 EU** primary write-ups.

---

## 8. Information that would help (from user, no flash yet)

- Deep Testing **APK package name + version** (e.g. `DeepTesting-porsche-xxxx.apk`).
- Exact **Spanish/English error string** (screenshot) — “model not supported” vs “not eligible” vs network error.
- Whether **OEM unlocking** toggle is present and ON.
- **`getprop` / About** — HeyTap region, **EX01** vs **EUEX** display strings (already partially in `device-record.md`).
- Whether **Local install** appears in stock updater on 1650.
- If willing to share (redacted): prior Deep Testing **apply** attempts / cooldown messages (2-month lockout).

---

## Sources (accessed 2026-10-31 unless noted)

| ID | URL | Notes |
|----|-----|--------|
| S1 | https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/ | Fetched — test failed |
| S2 | https://xdaforums.com/t/unlock-bl-on-realme-gt2-rmx3311-gdpr.4585749/ | Fetched — script dead |
| S3 | https://xdaforums.com/t/rollback-rmx3311.4622841/ | Fetched — downgrade guide |
| S4 | https://xdaforums.com/t/downgrade-rmx3311-android-14-0-0-1100-ex01.4704269/ | Fetched — split-screen fix |
| S5 | https://xdaforums.com/t/rmx3311-gdpr-version-downgrade-a13-to-a12.4543663/ | Brick/region warnings |
| S6 | https://xdaforums.com/t/realme-gt-2-rmx3312-pixelos-android-14-full-guide.4663480/ | RMX3312 only |
| S7 | https://xdaforums.com/t/how-to-unlock-bootloader-and-install-global-rom.4450729/page-2 | 3311 no unlock quotes |
| S8 | https://wiki.lineageos.org/devices/ | No porsche |
| S9 | https://wiki.lineageos.org/devices/porsche/ | 404 |
| S10 | https://www.pixelos.net/download/porsche | Active ROM |
| S11 | https://thecustomrom.com/guides/realme-deep-testing | Secondary 2026 guide |
| S12 | https://finance.sina.cn/tech/2025-01-19/detail-inefnhpe4802112.d.html?vt=4 | CN quota policy |
| S13 | https://www.reddit.com/r/Realme/comments/1g7weqv/ | EU unsupported anecdote |
| S14 | https://xdaforums.com/t/guide-unlock-bootloader-on-realme-gt-master-edition-rmx3360-rmx3363-without-deep-testing-using-qualcomm-toolbox.4782377/ | Wrong device class |
| S15 | https://xdaforums.com/t/unlocking-bootloader-rmx3312-realme-gt-2-realme-ui-5-0-android-14.4739634/ | **Fetch blocked** — snippets only |
| S16 | https://xdaforums.com/t/any-method-to-unlock-rmx331-gdpr-eu-version.4566661/page-2 | **Fetch blocked** |
| S17 | https://xdaforums.com/t/collection-of-ota-packages.4542941/post-90563674 | **Fetch blocked** |
| S18 | https://xdaforums.com/t/collection-of-ota-packages.4542941/page-23 | Fetched round 2 — Stano36 “A14 only” |
| S19 | https://xdaforums.com/t/unlocking-bootloader-rmx3312-realme-gt-2-realme-ui-5-0-android-14.4739634/ | Snippets only (bunny.net block) |
| S20 | https://xdaforums.com/t/any-method-to-unlock-rmx331-gdpr-eu-version.4566661/page-2 | Snippets only — new APK / BGGR claim |
| S21 | https://raw.githubusercontent.com/zenfyrdev/bootloader-unlock-wall-of-shame/main/brands/oppo/README.md | DT v1.0.1 / v1.1.0 taxonomy |
| S22 | https://xdaforums.com/t/discussion-a-thread-to-collate-and-share-what-is-known-about-unlocking-fastboot-on-oppo-devices.4490041/page-2 | Fetched — EU 3311 spoof discussion |
| S23 | https://xdaforums.com/t/finded-new-method-for-unlock-bootloader-testing.4695768/ | Snippets — GT2 Pro unlock Oct 2025 |
| S24 | https://xdaforums.com/t/rom-16-official-pixelos-aosp-stable.4650893/page-4 | Snippet — afzi07 “model not supported” |
| S25 | https://xdaforums.com/t/selecting-regional-rom.4744549/ | Secondary — EU DT token rejection note |

---

## Testimonies (round 2)

**Search date:** 2026-10-31 (targeted pass). **Goal:** evidence not already captured in sections 1–7 above (S1–S17). XDA thread bodies often **blocked** (bunny.net); where only search snippets were available, rows are marked **snippet-only**.

### Verified successes

| Date | Model | Firmware (before) | Method | Outcome | Link |
|------|-------|-------------------|--------|---------|------|
| 2023-05 (~) | **RMX3311 EU** | `RMX3311_11.C.10_EU_202303171905` | `deeptesting-junk.pl` + official fastboot flow (guide author **b0nb0n3v**; follower **wizard8400** confirms unlock) | Bootloader unlocked (orange warning at boot) | [4585749](https://xdaforums.com/t/unlock-bl-on-realme-gt2-rmx3311-gdpr.4585749/) — *already in §1; repeated here because it remains the only **fetched** EU RMX3311 completion* |
| 2025-05-26+ | **RMX3312 IN** | `RMX3312_14.0.0.1700(EX01)` (Realme UI 5 / A14) | Stano36 rollback/CN-region path + Deep Testing (thread guide); user **mahin.kk2** | **Approval** for Deep Testing obtained (“using @stano36 method”) — **full `fastboot flashing unlock` not quoted in fetched snippet** | [4739634](https://xdaforums.com/t/unlocking-bootloader-rmx3312-realme-gt-2-realme-ui-5-0-android-14.4739634/) — **snippet-only** |

**Count (round 2 definition): verified RMX3311 EU unlock on Android 14 or 15 stock firmware = 0.** The only verified EU **RMX3311** completion in primary fetches is **2023 on Android 12-era build `.C.10`**, not A14/A15.

### Verified failures / blocks (match user symptom)

| Date | Model | Firmware | Method / context | Outcome | Link |
|------|-------|----------|------------------|---------|------|
| 2024-10 | **RMX3311** (tester, EU path) | New Deeptest after Stano36 experiment | Approved **Oct 8**; “Start deep test” | **Fastboot did not appear** — unlock incomplete | [4669611](https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/) — S1 |
| 2025-08-28 | **RMX3311 EU** | (thread: battery/ROM; user on EU unit) | Deep Testing on stock | **~3 months** trying; “they don't allow unlocking at all the European ones” | [Reddit 1n2e2eq](https://www.reddit.com/r/Realme/comments/1n2e2eq/) — S13 |
| 2025 (Stano36, OTA thread) | **RMX3312** user on **A15** | Attempted Stano36 unlock path | User quote in OTA collection | Method **did not work**; “still at **15**” | [4542941/page-23](https://xdaforums.com/t/collection-of-ota-packages.4542941/page-23) — **S18 fetched** |
| 2025 (Stano36, same page) | **GT2 family** | Unlock path discussion | Maintainer statement | **“Unlocking only works on Android version 14”** | S18 |
| 2022–2023 XDA | **RMX3311 EU/GDPR** | Global Deep Testing APK | Official app submit | **“Failed to submit application. This phone model does not support deep testing.”** (same English string as user) | [4429669/page-2](https://xdaforums.com/t/chinese-and-global-version-unlock-bootloader-updated.4429669/page-2) — *not in S-table; fetched via search* |
| 2025-06 (~) | **RMX3311** (assumed; PixelOS thread) | Stock before custom ROM | Deep Test | **“This phone model does not support deep testing”** — maintainer points to Stano36 | [4650893/page-4](https://xdaforums.com/t/rom-16-official-pixelos-aosp-stable.4650893/page-4) — snippet |
| 2023-11-04 | **RMX3311 EU** | Region-change idea | CN server open + swap region | Stano36: **different modem** → **SIM/IMEI loss**; “unlocking … **not possible**” on that path | [4639692](https://xdaforums.com/t/unlock-rmx-3311-gdpr.4639692/) |

### Unverified / snippet-only (do not count as proof)

| Date | Model | Claim | Why unverified | Link |
|------|-------|-------|----------------|------|
| 2025-08-17 | “realme gt 2” (SKU **not stated**) | **BGGR** / **Mahadeva swamy S**: “unlocked bootloader successfully” | XDA page-2 **not fetched**; no firmware, no `fastboot` proof | [4566661/page-2](https://xdaforums.com/t/any-method-to-unlock-rmx331-gdpr-eu-version.4566661/page-2) — S20 |
| 2025 (4739634 thread) | Likely **RMX3312** / CN path | “Hi Everyone, This is successful, and I was able to unlock the bootloader” (+ new HeyTap account after old APK) | **No username/date/firmware** in snippet; thread **fetch blocked** | S19 |
| 2025-09-07 | N/A (reply to Realme 6 Pro user) | Stano36: “Yes, there is a solution” | Not GT2 RMX3311-specific | [4695768](https://xdaforums.com/t/finded-new-method-for-unlock-bootloader-testing.4695768/) — S23 |
| 2025-10-08 | **RMX3300 GT2 Pro CN** | **Emigrate86**: CN A12 rollback + **DeepTesting-targa-0516.apk** → “the loader is unlocked!” | **Wrong device** (Pro CN), not RMX3311 EU | S23 |
| 2025-09-27 | **RMX3311** | **Powerst**: cannot root 3311 | Failure adjacent; not unlock | S18 |

### Deep Testing / In-Depth Test APK (round 2)

| Finding | Source quality | Notes |
|---------|----------------|-------|
| User’s **In-Depth Test v1.0.1** aligns with community taxonomy **v1.0.1 / v1.1.0** for Realme UI 3+ | [zenfyr README](https://raw.githubusercontent.com/zenfyrdev/bootloader-unlock-wall-of-shame/main/brands/oppo/README.md) — **S21 fetched** | No **official** fetched doc for **v1.0.2 / v1.0.3 / 2.x** Realme DT on GT2 EU |
| Realme **BL Unlock Tool** major upgrade; **old APK → 2-month re-apply lockout** | Stano36 quoting Realme community notice in **4739634** snippets — S19 | Matches **Jul 12, 2025** Stano36 post in **4566661/page-2** snippets (S20): attachment **`DeepTesting-targa-0516.apk`** |
| India official GT2 tutorial still hosts legacy **~2.91 MB** unlock APK | [c.realme.com/in GT2 post](https://c.realme.com/in/post-details/1587344342215921664) — fetched metadata | **India community**; not evidence EU RMX3311 eligibility on ColorOS 15 |
| **No EU** Realme community In-Depth Test / GT2 unlock tutorial found | realme.com/eu legal pages only — web search | Consistent with EU email “we don't unlock the bootloader anymore” (§5) |

### Maintainer / recovery notes (not unlock, but new for 1650)

| Date | Item | Source |
|------|------|--------|
| 2026-04-03 | EU **`RMX3311_15.0.0.1650(EX01)`** full OTA resolved URL posted (still **Local install: Forbidden** on metadata) | Stano36 [4542941/page-23](https://xdaforums.com/t/collection-of-ota-packages.4542941/page-23) — S18 |
| 2026-04-08 | **Talha Gümüş**: Stano36 on Telegram — **ARB index 0** for 1650 TR/EU build (install safety, not unlock) | S18 |

---

*Internal repo cross-ref: `docs/device-record.md`, `docs/PLAN.md` Phase 2 stop condition.*
