## V48 experimental patch: general video playback

Video playback failures were reported across apps, not only YouTube. During diagnosis, the Allwinner hardware AVC decoder waited for a missing framework ashmem allocator service and failed to initialize. This patch starts the existing service automatically, allowing the video decoder to allocate its buffers.

Starting the service manually and restoring normal hardware-decoder preference produced smooth 720p playback in YouTube for Android TV, including pause/resume and seeking, as confirmed by the tester. Software-decoder preference had stuttered and is not part of this patch. Other apps and codecs have not all been tested. **The new automatic startup still needs a hardware boot test**, so this is an experimental patch release.

### Download and install

- Download `RG34XXSP-v48-video-playback-fix-after-v43.zip` and optionally its `.sha256` file.
- This asset requires the original **V43 complete image**, with no V44–V47 vendor patches. The installer checks the source and stops on other builds. It is not a complete flashable image.
- Back up important files. Power off the handheld and put its SD card in the PC card reader. Disconnect other external disks.
- Extract the entire ZIP and run `UPDATE-CARD.cmd` as administrator. The updater verifies the card layout and source, saves a verified vendor backup, writes only the vendor partition, and verifies the result.
- After SUCCESS, safely eject, boot, and test video playback. Repeat after another cold boot. Keep the backup and original firmware image.

Only the board startup configuration and revision metadata change. No application APKs, decoder binaries, codec preference overrides, charging limits, or user data are modified. V43's hardware fixes and Controller Tester remain. The intermittent USB resume/MTP issue is separate and is not addressed here.

### Credits and disclaimer

Thanks to the Andr36oid contributors, AOSP/LineageOS contributors, Anbernic/Allwinner platform developers, and icameronrb for physical testing. OpenAI Codex assisted with diagnosis and patch packaging. See the main README for full credits and source links. The allocator binary already exists in the firmware; this adds its startup configuration.

Unofficial experimental firmware, provided as-is without warranty. Use at your own risk. The maintainer is not responsible for device, battery, SD card damage, lost data, or other loss. Back up before applying.
