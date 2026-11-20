from pathlib import Path
import hashlib,json,os,shutil,stat,subprocess
b=Path(__file__).resolve().parent
source=b/'source-v43/vendor.img'; out=b/'RG34XXSP-v48-video-playback-fix-after-v43';out.mkdir(exist_ok=True)
expected=json.loads((b/'source-v43/image-manifest.json').read_text())['new_vendor_sha256']
assert hashlib.file_digest(source.open('rb'),'sha256').hexdigest()==expected
image=out/'RG34XXSP-v48-vendor.img'; assert not image.exists(),'Preserve existing build output'
shutil.copyfile(source,image)
roots=[Path('/mnt/rg48-before'),Path('/mnt/rg48-after')];mounted=[]
extra='''
# Framework ashmem allocator required by OMX native-buffer setup and Codec2.
# The system service binary and framework VINTF declaration already exist.
service rg34xx-hidl-memory /system/bin/hw/android.hidl.allocator@1.0-service
    class hal
    user system
    group system
    interface android.hidl.allocator@1.0::IAllocator ashmem
    seclabel u:r:hal_allocator_default:s0
    disabled

on post-fs-data
    start rg34xx-hidl-memory

on property:sys.boot_completed=1
    start rg34xx-hidl-memory
'''
def scan(root):
    result={}
    for p in root.rglob('*'):
        st=p.lstat(); item=[st.st_mode,st.st_uid,st.st_gid,{k:os.getxattr(p,k,follow_symlinks=False).hex() for k in os.listxattr(p,follow_symlinks=False)}]
        if stat.S_ISREG(st.st_mode):
            with p.open('rb') as stream:item.append(hashlib.file_digest(stream,'sha256').hexdigest())
        elif stat.S_ISLNK(st.st_mode):item.append(os.readlink(p))
        result[p.relative_to(root).as_posix()]=item
    return result
try:
    for root,file,options in zip(roots,[source,image],['loop,ro,noload','loop']):
        root.mkdir(exist_ok=True);subprocess.run(['mount','-o',options,str(file),str(root)],check=True);mounted.append(root)
    oldrc=(roots[0]/'etc/init/hw/init.sun50iw9p1.rc').read_bytes()
    text=oldrc.decode();assert text.count('REVISION=42')==1 and 'rg34xx-hidl-memory' not in text
    newrc=text.replace('REVISION=42','REVISION=48')+extra
    (roots[1]/'etc/init/hw/init.sun50iw9p1.rc').write_text(newrc)
    prop=(roots[0]/'build.prop').read_text(); assert prop.count('port_revision=42')==1
    newprop=prop.replace('port_revision=42','port_revision=48')
    (roots[1]/'build.prop').write_text(newprop)
    a,c=map(scan,roots);assert set(a)==set(c)
    changed=sorted(p for p in a if a[p]!=c[p]);assert changed==['build.prop','etc/init/hw/init.sun50iw9p1.rc'],changed
    assert all(a[p][:4]==c[p][:4] for p in a),'Metadata changed'
    assert (roots[1]/'etc/init/hw/init.sun50iw9p1.rc').read_text()==newrc
    assert (roots[1]/'build.prop').read_text()==newprop
    assert 'debug.stagefright' not in extra and 'setprop' not in extra
    assert 'oneshot' not in extra and 'interface android.hidl.allocator@1.0::IAllocator ashmem' in extra
    (out/'init-video-service.rc.txt').write_text(extra)
    (out/'preservation-check.json').write_text(json.dumps(dict(result='PASS',changed_files=changed,files_checked=len(a),all_existing_file_modes_owners_xattrs_preserved=True,codec_properties_unchanged=True,charging_usb_buttons_lid_swap_bluetooth_wifi_unchanged=True,device_playback_test='Manual existing allocator launch + standard decoder preference: Allwinner hardware AVC playback confirmed; user confirmed smooth 720p including seek/pause. New firmware startup still requires boot test.'),indent=2))
    subprocess.run(['sync'],check=True)
finally:
    for root in reversed(mounted):subprocess.run(['umount',str(root)],check=True)
r=subprocess.run(['e2fsck','-fn',str(image)],capture_output=True,text=True)
(out/'vendor-fsck.txt').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stdout+r.stderr
manifest=dict(old_vendor_sha256=expected,new_vendor_sha256=hashlib.file_digest(image.open('rb'),'sha256').hexdigest(),vendor_bytes=image.stat().st_size,purpose='Start missing framework ashmem HIDL allocator; retain normal hardware decoder preference',startup_hardware_tested=False)
(out/'image-manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps(manifest))
