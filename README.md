# Andr36oid Android 11 for Anbernic RG34XX SP — v45 Performance-First 64-Bit Edition

An experimental, performance-first community fork of Andr36oid for the **Anbernic RG34XX SP (Allwinner H700)**, paired with the lightweight **Andr36oid Launcher** (`SproutLauncher` fork) as the default home frontend and configured for a **64-bit-only (`zygote64`)** runtime.

---

## Build Artifacts (Local Workspace)

* **Complete Flashable Image (`.img.gz`):** `releases/RG34XXSP-Andr36oid-Android11-v45-perf-complete.img.gz` (`892.02 MiB`)
* **Complete Uncompressed Image (`.img`):** `releases/RG34XXSP-Andr36oid-Android11-v45-perf-complete.img` (`11.27 GiB`)
* **In-Place Card Updater (`v43`/`v44` $\rightarrow$ `v45`):** `releases/v45-perf-partitions/UPDATE-CARD-V45.cmd` ([Update-Card-v45.ps1](scripts/card-updaters/Update-Card-v45.ps1))
* **Checksums:** [RG34XXSP-v45-SHA256SUMS.txt](scripts/card-updaters/RG34XXSP-v45-SHA256SUMS.txt)
* **Technical Briefing:** [OPTIMIZATION_BRIEFING.md](OPTIMIZATION_BRIEFING.md)
* **RetroArch RG34XX SP Controls Config:** [ANBERNIC-keys.cfg](configs/retroarch/ANBERNIC-keys.cfg) & [retroarch.cfg](configs/retroarch/retroarch.cfg)
* **microG On-Demand Installer & Toggle:** [Install-And-Toggle-microG.ps1](scripts/microg/Install-And-Toggle-microG.ps1)

---

## What Changed in v45 (Performance-First 64-Bit Build)?

1. **Lightweight Default Frontend (`Andr36oidLauncher`):**
   * Replaced heavy Daijishō (`110–160 MB` RAM) with the pre-profiled, AOT-compiled **Andr36oid Launcher** (`~28–40 MB` RAM) as the default home activity.
   * Removed duplicate APK copies from `/vendor/etc/rg34xx/` and stripped `Daijishou` from `/system/app/`.
2. **64-Bit-Only Zygote (`ro.zygote=zygote64`):**
   * Configured `/system/etc/init/hw/init.zygote64.rc`, `/system/build.prop`, and `/vendor/build.prop` for single-Zygote 64-bit operation (`arm64-v8a`), reclaiming **45–60 MB of permanent RAM** previously held by `zygote_secondary` (`app_process32`).
3. **Ultra-Low-Power Clamshell Lid Sleep Manager (`rg34xx-lid-sleep.sh` — Option 1):**
   * Listens exclusively on the AXP2202 PMIC input device (`axp2202-pek`, `0%` CPU during gameplay) for Hall-sensor lid-close (`KEY_INSERT` / `0x006e`) and lid-open (`KEY_DELETE` / `0x006f`).
   * **On Lid Close:** Clamps CPU max frequency to `480 MHz` on `cpu0`, saves active Wi-Fi/Bluetooth states and brings `wlan0` down (powering down the `axp2202-cldo4` 3.3V Wi-Fi rail to eliminate the `25–45 mA` standby drain), and immediately forces Android into **Deep Doze** (`cmd deviceidle force-idle deep`) so the H700 enters hardware **ARM PSCI `universal-standby` (`mem`)** with DRAM in self-refresh.
   * **On Lid Open:** Synchronously restores full `1512 MHz` CPU clocks and all 4 cores (`0-3`) in `<2ms` via direct sysfs writes for instant wake, then asynchronously exits Deep Doze and restores your prior Wi-Fi/Bluetooth state.
4. **Cortex-A53 Compiler & Bionic Tuning:**
   * Updated Bionic and Dalvik/ART instruction set targets in `/vendor/build.prop` from `generic` to `cortex-a53` (`ro.bionic.cpu_variant=cortex-a53`, `dalvik.vm.isa.arm64.variant=cortex-a53`).
4. **Kernel `sdcardfs` Enabled (Bypassing Userspace FUSE):**
   * Restored `setprop persist.sys.fuse false` and `setprop persist.sys.fflag.override.settings_fuse false` in `/vendor/etc/init/hw/init.sun50iw9p1.rc` so ROM reads and emulator saves go directly through the kernel's built-in `sdcardfs` instead of bouncing through the Java `MediaProvider` FUSE daemon.
5. **Removed Boot-Time Input Sniffing & Diagnostic Polling Loops:**
   * Removed `rg34xx-power-usb-report` (which ran `getevent -lt` for the first 300 seconds of every boot piping every button/stick input through a shell loop, plus a 24×10s `dumpsys` loop) and `rg34xx-cpu-report`.
   * Added a `<5ms` fast-path exit to `rg34xx-owner-setup.sh` on subsequent boots and trimmed `rg34xx-hardware-v27.sh` to load `8821cs.ko` and exit cleanly without `dmesg`/`dumpsys` diagnostic dumps.
6. **VM, THP, CPU Governor, Cpuset & MicroSD I/O Queue Tuning:**
   * Disabled Transparent Huge Pages (`transparent_hugepage/enabled = never`) and tuned `min_free_kbytes = 8192`, `dirty_background_ratio = 5`, `dirty_ratio = 15`.
   * Added boot-time `performance` governor boost with automatic handoff to `schedutil` (`up_rate_limit_us = 1000`, `down_rate_limit_us = 10000`) on `sys.boot_completed=1`.
   * Disabled `iostats`, `add_random`, and `rotational` on `mmcblk0` (TF1) and `mmcblk1` (TF2) with `read_ahead_kb = 512`.
   * Added post-boot idle broadcast receiver trimming (`rg34xx-boot-trim.sh`) and included the v44 adaptive RAM profiler (`rg34xx-ram-profile.sh`).
7. **Service, HAL, Permission & APK Debloat:**
   * Disabled `userdebug` scheduler profiling (`sched_schedstats = 0`) and stripped 21 `userdebug`/unused init `.rc` services (`incidentd`, `perfetto`, `traced_perf`, `heapprofd`, `iorapd`, `atrace`, `bootstat`, `dumpstate`, `racoon`, `mdnsd`, `gsid`, etc.).
   * Disabled redundant vendor HALs (`vendor.keymint-default`, `vendor.rebootescrow-default`, `boringssl_self_test`), cleaned dead HAL entries (`camera.provider`, `tv.cec`) from `/vendor/etc/vintf/manifest.xml`, moved 14 unused donor feature XMLs out of `/vendor/etc/permissions/`, and added `gameconsole_unavailable_features.xml`.
   * Removed `SettingsIntelligence`, 19 R36S/Rockchip-specific hardware/utility apps, and all 78 `/product/overlay` RRO theme APKs while preserving `ThoriumWebView` (lazy-loaded, `0 MB` idle RAM), `PerfOverlay`, `GameComfort`, `GamepadKeyboard`, `JoyMouseSettings`, and `ControllerTester`.

---

## Installation

### Option 1: Fresh MicroSD Flash (Complete Image)
1. Back up the selected microSD card (**flashing erases the card**). Use a reliable 32GB or larger card.
2. Flash `releases/RG34XXSP-Andr36oid-Android11-v45-perf-complete.img.gz` using [balenaEtcher](https://etcher.balena.io/) or Rufus.
3. Insert the card into the handheld's **TF1** slot and boot. Allow first-boot storage expansion to complete.

### Option 2: In-Place Upgrade of an Existing v43 / v44 Card
1. Power off the handheld and insert your existing v43/v44 microSD card into a Windows PC reader.
2. Right-click `releases/v45-perf-partitions/UPDATE-CARD-V45.cmd` and select **Run as administrator**.
3. The updater verifies the card layout and `boot` partition, writes and read-back verifies the v45 `system`, `vendor`, and `product` partitions, and preserves your existing `userdata` (`/data`) partition.

---

## Controls

* **Menu (M):** Home (short press), `M + B` App Switcher.
* **Menu + X:** Toggle joystick mouse/cursor mode (right stick moves pointer, left stick scrolls, A or R1 left-clicks).
* **Long-Press Power:** Power / Global Actions menu.

---

## SHA-256 Checksums (v45)

Compressed image (`RG34XXSP-Andr36oid-Android11-v45-perf-complete.img.gz`):
```text
601f2fe5ffdca168347df45941af520fa69aafd65ad685dff5c9306af49eccc7
```

Uncompressed image (`RG34XXSP-Andr36oid-Android11-v45-perf-complete.img`):
```text
c6b07602b9af30911b285242984ea886fe46df5286089faa03f09cffc3fb2535
```

Individual partitions (`releases/v45-perf-partitions/`):
```text
57ec6e4cc00c1fbc33a1bd59b91cfd4daf0198998968ab2da04481758b1b753a  RG34XXSP-v45-system.img
d5ec5301b788e583fe2b53bf7bedc3b59d1b7d66e1ca94510e31e0e123d419ac  RG34XXSP-v45-vendor.img
6d84cd5708723587406838e934b5f1b3fc58fab7489c235b5a3e1bb3959191a6  RG34XXSP-v45-product.img
```

---

## Experimental — Use at Your Own Risk

This is unofficial, experimental firmware provided as-is without warranty. Charging cutoff and thermal protection have not been independently validated on this Android port. Monitor charging and use a spare microSD card.

## Credits and Upstream Sources

* **[Andr36oid](https://github.com/andr36oid)** — R36S Android 11 base, Andr36oid Launcher, joyMouse, and handheld framework features (**itskenny0, turtleletortue, sonic011gamer, notime2d8**, and contributors).
* **[icameronrb/RG34XXSP-Andr36oid](https://github.com/icameronrb/RG34XXSP-Andr36oid)** — RG34XX SP (H700) v43/v44 port adaptation, display adapter, storage resizer, and hardware bring-up.
* **[well83](https://github.com/well83)** — T95 H616 Android 12 donor components.
* **[Anbernic](https://anbernic.com/)**, **AOSP**, **LineageOS**, **Linux**, **Allwinner**, **Arm**, and **Realtek**.
