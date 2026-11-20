# RG34XX SP Andr36oid — Performance-First 64-Bit Edition

A performance-first community fork of **Andr36oid (Android 11 / LineageOS 18.1)** tuned specifically for the **Anbernic RG34XX SP** (Allwinner H700 quad-core Cortex-A53, Mali-G31 MP2, 2 GB RAM, 640×480 4:3 clamshell).

This fork strips out unused R36S/Rockchip components, `userdebug` profiling overhead, heavy launcher bloat, and broken donor HALs while adding hardware-specific power management, kernel storage optimizations, working hardware video decoding, and RG34XX SP controller profiles—leaving **~1.36 GB (`68.9%`) of RAM available at idle** for emulators, streaming, and native Android apps.

---

## Key Capabilities & Optimizations

### Memory & Runtime Efficiency
* **Pure 64-Bit Runtime (`zygote64`):** Boots a single 64-bit Zygote (`arm64-v8a`) instead of dual 64/32-bit Zygotes, permanently reclaiming ~45–60 MB of RAM and speeding up cold boot.
* **Lightweight Default Frontend:** Uses the pre-profiled, AOT-compiled **Andr36oid Launcher** (`~28–40 MB` RSS) as the default home screen so the launcher stays resident in memory during heavy emulation instead of reloading on exit.
* **Cortex-A53 Compiler Targets:** Configures Bionic and Dalvik/ART (`dex2oat` / JIT) for `cortex-a53` instruction scheduling instead of `generic`.
* **Lean System Footprint:** Removes unused R36S/Rockchip hardware utilities, `SettingsIntelligence`, SurfaceFlinger background blur, Power Menu graph polling, `userdebug` tracing/profiling daemons, crashing donor HALs (`camera.provider`, `vendor.keymint-default`, `rild`), and 78 unused `/product/overlay` theme APKs—while preserving lazy-loaded `ThoriumWebView` (`0 MB` idle RAM), `PerfOverlay`, `GameComfort`, `GamepadKeyboard`, `JoyMouseSettings`, and `ControllerTester`.

### Storage, Kernel & Scheduler Tuning
* **Kernel `sdcardfs` Storage Path:** Routes internal and external storage directly through the kernel's built-in `sdcardfs` instead of userspace FUSE (`MediaProvider`) for lower latency on ROM loads and save states.
* **MicroSD & VM Tuning:** Disables Transparent Huge Pages (`never`), disables `sched_schedstats` profiling, tunes dirty-page writeback ratios, and optimizes TF1/TF2 (`mmcblk0`/`mmcblk1`) I/O queues (`read_ahead_kb = 512`, `iostats = 0`, `add_random = 0`).
* **CPU Governor & Cpuset Partitioning:** Uses a boot-time `performance` boost handing off to fast-ramping `schedutil` on `sys.boot_completed`, isolates background tasks to low-impact cores, and runs post-boot idle broadcast receiver trimming alongside adaptive RAM profiling.

### Hardware Video Decoding
* **Framework `IAllocator/ashmem` Support:** Automatically starts `/system/bin/hw/android.hidl.allocator@1.0-service` (`rg34xx-hidl-memory`) with its `hal_allocator_default` SELinux domain and HIDL interface registration, allowing the Allwinner `OMX.allwinner.video.decoder.avc` hardware decoder and `Codec2` to allocate video buffers cleanly for **Moonlight**, **YouTube**, and media players without forcing software decoding.

### Clamshell Power & Sleep Management
* **Event-Driven Hall-Sensor Lid Sleep (`rg34xx-lid-sleep.sh`):** Monitors the AXP2202 PMIC input device (`axp2202-pek`) at `0%` gameplay CPU overhead. Closing the lid clamps CPU clocks to `480 MHz` on `cpu0`, powers down active Wi-Fi/Bluetooth radios (saving their prior state), and forces Deep Doze; opening the lid synchronously restores full `1512 MHz` clocks across all four cores in `<2 ms` before asynchronously restoring radios.
* **Reliable Wake on H700:** Holds a lightweight kernel partial wake lock (`rg34xx_no_mem_suspend`) so screen timeouts and lid closures turn off the panel, backlight, and radios without entering un-wakeable H700 `mem` suspend states.

### Handheld Controls & Companion Tooling
* **RG34XX SP RetroArch Controls (`configs/retroarch/`):** Pre-configured `ANBERNIC-keys.cfg` and `retroarch.cfg` mapping the RG34XX SP's hardware HAT D-pad (`h0up`/`h0down`/`h0left`/`h0right`), face/shoulder buttons, analog sticks, and ArkOS-style hotkeys out of the box.
* **Wireless Debugging Ready:** Enables ADB over TCP (`5555`) across reboots for cable-free ROM transfers and APK management.
* **Optional On-Demand `microG`:** Includes a helper script (`scripts/microg/`) to install and toggle lightweight `microG` Google Services on or off (`0 MB` RAM when disabled).

---

## Download & Installation

Pre-built flashable images and SHA-256 checksums are published on **[GitHub Releases](https://github.com/gamecorner-033/rg34xxsp-andr36oid/releases/latest)**.

### Option 1: Fresh MicroSD Flash (Recommended)
1. Back up your microSD card (**flashing erases all data**). Use a reliable 32 GB or larger card.
2. Download the latest complete `.img.gz` release from **[GitHub Releases](https://github.com/gamecorner-033/rg34xxsp-andr36oid/releases/latest)** and verify its SHA-256 checksum.
3. Flash the `.img.gz` directly using [balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/).
4. Insert the card into the handheld's **TF1** slot and boot. Allow first-boot storage expansion to finish before powering off.

### Option 2: In-Place Partition Update (Windows, Preserves User Data)
1. Power off the handheld and insert the existing RG34XX SP Android microSD card into a Windows PC reader.
2. Place the matching partition images alongside the updater scripts in [`scripts/card-updaters/`](scripts/card-updaters/).
3. Right-click `UPDATE-CARD-V45.cmd` (full `system` + `vendor` + `product` update) or `UPDATE-VENDOR-ONLY.cmd` (fast `vendor`-only patch) and select **Run as administrator**.
4. Wait for read-back SHA-256 verification to report `SUCCESS`, safely eject the card, and boot.

---

## Controls

* **Menu (`M`):** Short press = Home; `M + B` = App Switcher.
* **Menu + `X`:** Toggle **JoyMouse** virtual cursor (right stick moves pointer, left stick scrolls, `A` or `R1` left-clicks).
* **Long-Press Power:** Power / Global Actions menu.
* **RetroArch Hotkeys (with bundled config):** Hold `Select` + `Start` (twice) to quit, `Select + X` (or `L1 + R1 + Start + Select`) for Quick Menu, `Select + R1 / L1` to save/load state, `Select + Up / Down` to change slot.

---

## Repository Layout

* [`scripts/`](scripts/) — Reproducible Linux/WSL partition build, verification, image assembly, and compression pipeline.
* [`scripts/card-updaters/`](scripts/card-updaters/) — SHA-256-verified in-place Windows SD card updaters, partition manifest, and checksums.
* [`scripts/microg/`](scripts/microg/) — Optional `microG` installer and on-demand enable/disable toggle scripts.
* [`configs/retroarch/`](configs/retroarch/) — RG34XX SP `ANBERNIC-keys` autoconfig and `retroarch.cfg`.
* [`OPTIMIZATION_BRIEFING.md`](OPTIMIZATION_BRIEFING.md) — Full architectural audit, telemetry notes, and optimization breakdown.
* [`patches/`](patches/) — Upstream standalone patch tooling preserved for compatibility with stock base cards.

---

## Experimental — Use at Your Own Risk

This is unofficial, experimental firmware provided as-is without warranty. Charging cutoff and thermal protection have not been independently validated on this Android port. Monitor charging and use a spare microSD card.

## Credits and Upstream Sources

* **[Andr36oid](https://github.com/andr36oid)** — Android 11 handheld base, Andr36oid Launcher, joyMouse, and controller/emulator framework (**itskenny0, turtleletortue, sonic011gamer, notime2d8**, and contributors).
* **[icameronrb/RG34XXSP-Andr36oid](https://github.com/icameronrb/RG34XXSP-Andr36oid)** — Upstream RG34XX SP (H700) port, display adapter, storage resizer, hardware bring-up, and video allocator fix.
* **[well83](https://github.com/well83)** — Allwinner H616/H700 Android donor components.
* **[Anbernic](https://anbernic.com/)**, **AOSP**, **LineageOS**, **Linux**, **Allwinner**, **Arm**, and **Realtek**.
