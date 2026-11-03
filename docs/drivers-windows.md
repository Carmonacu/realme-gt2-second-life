# Windows drivers (Phase 0)

Install these **before** unlock, sideload, or EDL rescue. Reboot after each driver install.

## Checklist

- [ ] **Google USB Driver** or WinUSB via platform-tools (ADB/fastboot in normal mode)
- [ ] **Oppo / Realme USB driver** (ColorOS USB) — required when fastboot/adb fail with “waiting for device”
- [ ] **Qualcomm QDLoader 9008** driver — for EDL/MSM tools if the phone is bricked
- [ ] Optional: **Oplus MSM Download Tool** + **EU OFP** package (offline backup, not in repo)

## 1 — ADB / fastboot (already mostly OK if `check-adb-device.ps1` passes)

You already have **platform-tools 37.0.1** (WinGet). For **fastboot** mode, Windows still needs the **Android Bootloader Interface** driver.

**Option A — Google USB Driver (recommended)**

1. Download [Google USB Driver](https://developer.android.com/studio/run/win-usb) (`usb_driver.zip` from SDK extras, or extract from Android Studio SDK).
2. Unzip to e.g. `C:\android\usb_driver`.
3. Boot phone to **fastboot** (Vol Down + Power, or `adb reboot bootloader`).
4. Open **Device Manager** (`Win+R` → `devmgmt.msc`).
5. Find **Android** / **Unknown device** under fastboot → **Update driver** → **Browse** → point to the folder containing `android_winusb.inf`.
6. Select **Android Bootloader Interface** (and **Android ADB Interface** if listed).
7. Reboot PC if prompted.

**Option B — 15-second ADB installer** (installs Google WinUSB system-wide): community tools such as [Android USB Drivers guides](https://www.androidusbdrivers.com/realme-4-usb-drivers/) — run installer as Administrator, answer **Y** to ADB, fastboot, and device drivers.

## 2 — Realme / Oppo USB (MTP + OEM composite)

Use when adb works but **fastboot** shows no device, or Device Manager shows **Realme** / **Oppo** with a warning icon.

1. Download Realme’s Windows package (MSI installer), e.g. **Realme-Driver-Setup-v2.0** from [realmedriver.com](https://realmedriver.com/) (verify checksum from a trusted mirror if needed).
2. Extract zip → run **`RealmeDriver-x64.msi`** (64-bit Windows).
3. Click **Next** through the wizard → **Finish** → **restart the PC**.
4. Reconnect USB (direct port, data cable). On phone: enable **USB debugging**; for fastboot, use bootloader screen (not locked MTP-only).

Alternative: manual `.inf` install — extract a Realme `usb_driver` folder with `android_winusb.inf` and use Device Manager → **Update driver** → **Browse** (same steps as Google driver).

## 3 — Qualcomm QDLoader 9008 (EDL rescue only)

Required if the phone shows **Qualcomm HS-USB QDLoader 9008** in Device Manager (EDL mode). **Wrong firmware = brick risk** — pair with matching **EU** OFP only.

1. Download **Qualcomm USB Driver** or **QDLoader** package (often bundled with QPST/MSM tool archives — use a known-good source for your tool chain).
2. Extract and run **`QDLoader.exe`** or **`Setup.exe`** as Administrator (package-dependent).
3. Complete install → reboot PC.
4. In Device Manager, the 9008 port should appear as **Qualcomm HS-USB QDLoader 9008 (COMx)** without a yellow bang.

Do **not** enter EDL or flash MSM unless you have the correct **RMX3311 EU** rescue package and have read [PLAN.md](PLAN.md) warnings.

## Verify

```powershell
.\scripts\windows\check-platform-tools.ps1
.\scripts\windows\check-adb-device.ps1      # phone on, USB debugging
.\scripts\windows\list-fastboot-devices.ps1   # phone in fastboot mode
```

**Manual check for drivers:** boot to fastboot, run `list-fastboot-devices.ps1` — expect a serial line (not empty stub message).

## If fastboot/adb is empty

1. Different USB port (direct to PC, not hub).
2. Install/update Realme USB driver; disable conflicting “MTP only” mode if needed.
3. Bootloader/fastboot: use `fastboot devices` not `adb devices`.
4. Device Manager: look for unknown “Android” or “QCOM” entries and update driver.

## EDL (last resort)

Only with matching **EU** firmware packages. Wrong region OFP can damage modem/IMEI on RMX3311.
