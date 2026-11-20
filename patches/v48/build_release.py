"""Build the V43-compatible video patch from the verified public V43 image.

Run as root on Linux with e2fsprogs/util-linux. No physical disks are used.
"""
from pathlib import Path
import gzip, hashlib, json, shutil, subprocess, urllib.request, zipfile

b=Path(__file__).resolve().parent
source=b/'source-v43/vendor.img'
out=b/'RG34XXSP-v48-video-playback-fix-after-v43'
def digest(p):
    with p.open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()
if not source.exists():
    url='https://github.com/icameronrb/RG34XXSP-Andr36oid/releases/download/v43/RG34XXSP-Andr36oid-Android11-v43-complete.img.gz'
    compressed=b/'v43-source.img.gz'
    urllib.request.urlretrieve(url,compressed)
    assert digest(compressed)=='67681fd18292427b829063b1fcc93f3c4b8fbe6948eed65a69ea6e9f30979e31'
    rawhash=hashlib.sha256(); offset=0; start=2436890624; end=start+536870912
    with gzip.open(compressed,'rb') as f, source.open('xb') as vendor:
        while data:=f.read(8*1024*1024):
            rawhash.update(data)
            left=max(start,offset);right=min(end,offset+len(data))
            if left<right: vendor.write(data[left-offset:right-offset])
            offset+=len(data)
    assert offset==12101615616
    assert rawhash.hexdigest()=='756609773bb05e1672de69d8c44c4ef75c2b54225e090c248b43fb702e10d2a8'
assert source.stat().st_size==536870912
assert digest(source)=='276e58135db98f5f096f268dda4dcd9b9e0dac9686d30b268fd16fbb96e51748'
subprocess.run(['python3',str(b/'build_vendor_v48.py')],check=True)
subprocess.run(['python3',str(b/'package_v48.py')],check=True)
for name in ['build_release.py','build_vendor_v48.py','package_v48.py']:
    shutil.copyfile(b/name,out/name)
checks={p.name:dict(bytes=p.stat().st_size,sha256=digest(p)) for p in sorted(out.iterdir()) if p.is_file() and p.name!='package-checksums.json'}
(out/'package-checksums.json').write_text(json.dumps(checks,indent=2))
archive=out.with_suffix('.zip')
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(out.iterdir()):
        if p.is_file():z.write(p,out.name+'/'+p.name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name,info in checks.items():
        with z.open(out.name+'/'+name) as f:
            assert hashlib.file_digest(f,'sha256').hexdigest()==info['sha256']
archive.with_suffix('.zip.sha256').write_text(digest(archive)+'  '+archive.name+'\n')
print(json.dumps(dict(archive=str(archive),bytes=archive.stat().st_size,sha256=digest(archive),verified=True)))
