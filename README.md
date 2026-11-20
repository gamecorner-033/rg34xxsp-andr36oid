# Andr36oid Android 11 for Anbernic RG34XX SP

An experimental community port of Andr36oid to the **Anbernic RG34XX SP (Allwinner H700)**, with Daijishō as the default launcher. This is regular Android 11 rather than Android TV.

I have flashed and booted this build on my own RG34XX SP with the **v2 LCD panel**. Version 43 also works on my device with the USB startup correction. Other panel revisions and other Anbernic models have not been confirmed.

## Download

**[Download v43 from GitHub Releases](https://github.com/icameronrb/RG34XXSP-Andr36oid/releases/tag/v43)**. Choose `RG34XXSP-Andr36oid-Android11-v43-complete.img.gz` under Assets. This is a complete image; earlier patches are not required.

The [earlier OneDrive sharing link](https://1drv.ms/u/c/74a5f0ffe2189a45/IQBpgC47xe8WQZ0QPKg9RvJmAUaSGnKH0G0z7gTYO-0aOhQ?e=5cU8wj) was used for the previous build. Use the GitHub v43 release for this version.

## Experimental video-playback patch (V48)

[Download the V48 video-playback patch and installation instructions](https://github.com/icameronrb/RG34XXSP-Andr36oid/releases/tag/v48-video-patch). This is a vendor-only patch for the original **V43 complete image**, not a complete firmware image. It stops on V44–V47 vendor test builds.

Video playback failures were reported across apps. Diagnosis in YouTube for Android TV found a missing shared-memory allocator service blocking the Allwinner hardware decoder. Starting that service restored smooth 720p AVC playback, including pause/resume and seeking; the patch makes startup automatic without forcing software decoding. **Automatic startup on the new patch still needs a hardware boot test**, and other codecs/players have not all been tested. It remains experimental. The separate intermittent USB resume/MTP issue is not fixed by this patch.

## What works on the tested handheld

- Display and graphics on the v2 panel; audio.
- D-pad, buttons, Home/menu and volume controls.
- Both analog sticks, with full-range calibration.
- Lid-close sleep and lid-open wake; long-press power menu.
- Wi-Fi and built-in Bluetooth.
- USB file transfer (MTP) and ADB debugging, with a USB startup correction in v43.
- Joystick mouse/cursor mode: **hold Menu (M) and press X**.
- Daijishō as the initial launcher, with Andr36oid Launcher available as an option.
- A preinstalled **Controller Tester** app for checking buttons and stick movement.
- Automatic first-boot storage expansion for apps and ROMs.

The stock CPU frequency settings are retained; this port does not add an overclock. The old approximately 2GB stock ROM partition has been replaced with a small 128MiB boot/log partition. Remaining card capacity is used for Android storage. A tested 64GB card reported approximately 56GB total Android storage after expansion.

## Installation

1. Back up the selected microSD card. **Flashing erases that card.** Use a spare, reliable 32GB or larger card.
2. Download the v43 `.img.gz` file and optionally verify the SHA-256 below.
3. Flash it using an image writer such as [balenaEtcher](https://etcher.balena.io/). If your writer does not accept `.img.gz`, extract the `.img` first. Select the correct card carefully.
4. Safely eject the card and put it in the handheld's **TF1** slot.
5. Boot and allow up to 15 minutes on the first startup for storage checks and expansion. If a restart is requested, restart once to finish.
6. Configure Daijishō and add your own games. No personal ROM collection is included.

Android app storage uses ext4. To browse files in Windows, boot Android, unlock the handheld, connect a USB data cable and select **File transfer/MTP**. Windows cannot browse the Android partition directly through a card reader.

## Controls

- **Menu (M):** Home.
- **Menu + X:** toggle cursor mode.
- In cursor mode: right stick moves the pointer, left stick scrolls, A or R1 left-clicks.
- Mouse mode can also be selected in **Settings → Joystick mouse**.
- Open **Controller Tester** from the app list to check buttons and analog sticks.

## What changed in v43?

Version 41 could expose USB interfaces while Android's active file-transfer service was not initialized. Windows would sometimes stay at “Connecting to device,” especially after a restart.

Version 43 changes the USB startup scripts to request MTP through Android's USB service, including MTP alongside ADB when debugging is enabled. It retains the hardware fixes, apps and cursor controls from v41. Music files were not removed.

The complete image passed a full decompression and byte comparison against its sources, partition-table checks and filesystem checks. The new USB scripts passed 13 simulated regression scenarios. The maintainer has reported v43 working on the handheld; this is not a guarantee of compatibility or long-term stability on every unit. Please report the panel revision, build version and steps to reproduce any issue.

## Experimental — use at your own risk

This is unofficial, experimental firmware, provided as-is without warranty. **I am not responsible for damage to your device, SD card, battery, lost data or any other loss resulting from its use.** Back up your data and use a spare card. This project is not endorsed by Anbernic or the upstream projects credited below.

Charging cutoff and thermal protection have **not** been independently validated on this Android port. Retaining stock kernel settings does not establish battery safety. Treat this as an experimental build and monitor charging.

## Credits and sources

This port depends on substantial work by other developers. Credit for their projects remains with their authors; listing a project here does not imply its maintainers developed or endorsed this port.

- **[Andr36oid](https://github.com/andr36oid)** — the R36S Android 11 base and handheld features. Thanks to **itskenny0, turtleletortue, sonic011gamer, notime2d8**, and all contributors. See the [release repository](https://github.com/andr36oid/releases) and [common device components](https://github.com/andr36oid/android_device_gameconsole_common).
- **Andr36oid joystick mouse contributors** — the adapted cursor service is based on [joyMouse at commit 0c77af628427f60dd40f6f136f45af851aac7b26](https://github.com/andr36oid/android_device_gameconsole_common/tree/0c77af628427f60dd40f6f136f45af851aac7b26/joyMouse).
- **[well83](https://github.com/well83)** — [T95 H616 Android 12 b25-final](https://github.com/well83/t95-h616-android12/releases/tag/b25-final), used as an Allwinner Android donor during the port's development. The resulting release runs Android 11.
- **[Anbernic](https://anbernic.com/)** — RG34XX SP stock firmware, kernel and hardware support used for this device adaptation; stock firmware reference: RG34XXSP v1.0.6.
- **[Daijishō](https://github.com/TapiocaFox/Daijishou)** — the launcher and its developers, including **TapiocaFox, Post-Mortem, Jetup13, official-wizard**, and the wider contributor community. Its public repository provides assets and project information, not the full application source.
- **[Android Open Source Project](https://source.android.com/), [LineageOS](https://lineageos.org/), [Linux](https://kernel.org/)** and their contributors — foundational software and tooling.
- **Allwinner, Arm and Realtek** — platform, graphics and wireless components used by the underlying firmware.
- **[Allwinner-Homlet H6 BSP Linux 4.9](https://github.com/Allwinner-Homlet/H6-BSP4.9-linux)** — a kernel/platform research reference.
- **[LPF970915/H700Android](https://github.com/LPF970915/H700Android)** — related H700 Android research consulted during investigation. Its image is not the base of this release.
- **[icameronrb](https://github.com/icameronrb)** — project direction and hands-on flashing, testing and feedback on the physical handheld.
- **OpenAI Codex** — assistance with port adaptations, diagnostics, Controller Tester, regression checks and image packaging.

Third-party components retain their own licenses and ownership. These links identify upstream projects and research references; this repository does not claim to contain a complete source tree or reproducible build system for every bundled component.

## SHA-256

Compressed image (`RG34XXSP-Andr36oid-Android11-v43-complete.img.gz`):

```text
67681fd18292427b829063b1fcc93f3c4b8fbe6948eed65a69ea6e9f30979e31
```

Uncompressed `.img`:

```text
756609773bb05e1672de69d8c44c4ef75c2b54225e090c248b43fb702e10d2a8
```
