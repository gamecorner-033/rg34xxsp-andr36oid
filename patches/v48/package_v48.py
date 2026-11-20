from pathlib import Path
import hashlib,json,struct
b=Path(__file__).resolve().parent;out=b/'RG34XXSP-v48-video-playback-fix-after-v43';src=b/'source-v43'
info=json.loads((out/'image-manifest.json').read_text());assert json.loads((out/'preservation-check.json').read_text())['result']=='PASS'
t=(src/'legacy-Update-Card.ps1').read_text(encoding='utf-8-sig')
t=t.replace('v35','v48').replace('Version=35;','Version=48;')
t=t.replace('storage expansion runtime and Windows MTP identification','shared-memory service for hardware video playback')
old="$_.BusType -eq 'USB' -and $_.Size -eq 64021856256 -and $_.PartitionStyle -eq 'GPT'"
new="$_.BusType -in @('USB','SD') -and $_.Size -ge 30000000000L -and $_.Size -le 2199023255552L -and $_.PartitionStyle -eq 'GPT' -and -not $_.IsBoot -and -not $_.IsSystem -and -not $_.IsReadOnly"
assert t.count(old)==1;t=t.replace(old,new)
t=t.replace('Exactly one matching spare 64 GB USB card is required.','Connect exactly one writable USB/SD card of 32GB or larger with the known V43 layout. Unplug other qualifying external disks.')
marker="    Write-Host 'Checking the existing vendor filesystem (512 MB)...'"
assert t.count(marker)==1
t=t.replace(marker,"""    if((RegionHash $stream 2973761536L 536870912L) -ne $expected.product_sha256){
        Write-Host 'Verifying all allocated product blocks and filesystem metadata...'
        Assert-AllocatedVendor $stream 2973761536L $expected.product_allocated_ranges
        Write-Host 'Product allocated contents match; only unused bytes differ.'
    }
"""+marker)
t=t.replace('allow up to 15 minutes for offline storage expansion. Do not interrupt the first boot.','wait for Android to start, then test video playback. No storage resize is performed by this patch.')
(out/'Update-Card.ps1').write_text(t,encoding='utf-8-sig')
expected=json.loads((src/'legacy-expected-card.json').read_text());expected.update(info)
expected['accepted_vendor_sha256']=[info['old_vendor_sha256'],info['new_vendor_sha256']]
expected['product_sha256']='925f0458d0493722a8f0851e512a04a43387c94766e5517af7dc5d82e3d2598b'
expected['product_allocated_ranges']=json.loads((src/'product-allocated-ranges.json').read_text())
ranges=[]
with (src/'vendor.img').open('rb') as f:
 f.seek(1024);sb=f.read(1024);blocks=struct.unpack_from('<I',sb,4)[0];pergroup=struct.unpack_from('<I',sb,32)[0]
 assert blocks==131072 and struct.unpack_from('<I',sb,24)[0]==2
 f.seek(4096);desc=f.read(((blocks+pergroup-1)//pergroup)*32);used=[]
 for i in range((blocks+pergroup-1)//pergroup):
  f.seek(struct.unpack_from('<I',desc,i*32)[0]*4096);bitmap=f.read(4096)
  used.extend(bool(bitmap[j//8]&(1<<(j%8))) for j in range(min(pergroup,blocks-i*pergroup)))
 i=0
 while i<blocks:
  if not used[i]:i+=1;continue
  first=i
  while i<blocks and used[i]:i+=1
  offset=first*4096;length=(i-first)*4096;f.seek(offset)
  ranges.append(dict(offset=offset,length=length,sha256=hashlib.sha256(f.read(length)).hexdigest()))
expected['old_vendor_ranges']=ranges
(out/'expected-card.json').write_text(json.dumps(expected,indent=2))
(out/'UPDATE-CARD.cmd').write_bytes(b'@echo off\r\ntitle RG34XX SP v48 Video Playback Fix\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Card.ps1"\r\necho.\r\npause\r\n')
(out/'README.txt').write_text('''RG34XX SP v48: hardware video playback startup fix AFTER v43

Finding: video playback was failing across apps, as reported by the tester.
During diagnosis in YouTube for Android TV, the Allwinner H.264 decoder
waited for the missing android.hidl.allocator@1.0 ashmem service and failed
to initialize. This addresses a system video-buffer allocation problem.
Preferring software decoding produced stuttering/freezes. Starting the
existing framework ashmem service and restoring normal codec preference
allowed hardware playback; user confirmed smooth 720p with seek/pause.

This patch starts that existing allocator automatically with system UID
and its intended SELinux domain. It declares its HIDL interface for init
and starts it after data setup, with a boot-complete fallback. Init restarts
it if it exits. The framework binary/VINTF declaration already exist.

Only vendor build.prop's revision number and the board init RC change.
No decoder ranking overrides or software-decoder preference are added.
Application APKs are unmodified. Existing V43 hardware fixes, charging
settings, apps and user data are preserved. This variant requires the
original V43 vendor; V44 RAM and V45-V47 test builds are not accepted.

INSTALL
1. Back up important files. Power off, then put the current v43 SD card in
   the PC's card reader. Disconnect other qualifying USB/SD disks.
2. Extract the entire ZIP. Run UPDATE-CARD.cmd as administrator.
3. After SUCCESS, safely eject and boot. Test a video at 720p for at least
   one minute, including seek/pause; also test another cold boot.

Installer safeguards: exactly one writable USB/SD card, expected GPT bounds,
known boot/resources/environment/product and source vendor, verified vendor
backup before writes, bounded vendor-only write and complete read-back hash.
Unused-byte differences are accepted only if every allocated filesystem block
and its metadata match the known build. Keep the backup and recovery image.

The live service test passed. The NEW firmware startup has NOT yet been
hardware tested. This is an experimental public patch, not a complete firmware image.
Only hardware AVC in the test app was verified live; other codecs/players
have not all been tested. Back up first. Provided as-is without warranty;
use at your own risk. The maintainer is not responsible for damage or loss.
The intermittent USB resume/MTP issue remains a separate unresolved item.
''')
print('V48_INSTALLER_AND_GUARDS_PREPARED')
