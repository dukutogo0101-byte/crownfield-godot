#!/usr/bin/env python3
"""Fingerprint runtime source; fail if source changes during exports."""
import argparse, hashlib, json, pathlib, datetime
ROOT = pathlib.Path(__file__).resolve().parents[1]
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def source():
    files=[]
    for top in ('core','ui','view','src','data','assets','scenes'):
        base=ROOT/top
        if base.exists():
            files.extend(p for p in base.rglob('*') if p.is_file() and not p.name.endswith('.import'))
    files += [ROOT/name for name in ('project.godot','export_presets.cfg') if (ROOT/name).exists()]
    entries={str(p.relative_to(ROOT)):digest(p) for p in sorted(set(files))}
    return {'sha256':hashlib.sha256(json.dumps(entries,sort_keys=True,separators=(',',':')).encode()).hexdigest(),'files':entries}
parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['start','finish','verify']);args=parser.parse_args()
stamp=ROOT/'builds/source_stamp.json'
if args.mode=='start':
    stamp.write_text(json.dumps(source(),ensure_ascii=False,indent=2)+'\n')
elif args.mode=='finish':
    before=json.loads(stamp.read_text()); after=source()
    if before!=after: raise SystemExit('SOURCE CHANGED DURING EXPORT — discard and rebuild')
    artifacts={p.name:{'size_bytes':p.stat().st_size,'sha256':digest(p)} for p in (ROOT/'builds').iterdir() if p.suffix in ('.exe','.x86_64','.apk','.pck')}
    manifest={'built_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'godot':'4.5.2.stable','source_sha256':after['sha256'],'source_files':after['files'],'artifacts':artifacts,'verification':{'linux':'pending','windows':'PE export only; native execution not tested','android':'signature/manifest verification pending; device execution not tested'}}
    (ROOT/'builds/build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('BUILD SOURCE UNCHANGED',after['sha256'])

else:
    import zipfile, struct
    manifest_path=ROOT/'builds/build_manifest.json'
    manifest=json.loads(manifest_path.read_text())
    apk=ROOT/'builds/Crownfield-debug.apk'
    with zipfile.ZipFile(apk) as archive:
        names=archive.namelist()
        assert 'assets/project.binary' in names, 'Missing Godot project in APK'
        assert any('core/simulation' in n for n in names), 'Missing simulation resource in APK'
        assert any('ui/game' in n for n in names), 'Missing game UI resource in APK'
        assert 'assets/data/maps/four_rivers.json' in names, 'Missing map JSON in APK'
        assert not any(n.startswith(('assets/tests/','assets/research/','assets/tools/','assets/docs/','assets/builds/')) for n in names), 'Unexpected development payload in APK'
        alignments={}
        for n in names:
            if n.startswith('lib/') and n.endswith('.so'):
                data=archive.read(n)
                assert data[:4]==b'\x7fELF' and data[4]==2
                phoff=struct.unpack_from('<Q',data,32)[0];phsize,phnum=struct.unpack_from('<HH',data,54)
                alignments[n]=[struct.unpack_from('<Q',data,phoff+i*phsize+48)[0] for i in range(phnum) if struct.unpack_from('<I',data,phoff+i*phsize)[0]==1]
        manifest['android_elf_load_alignment']=alignments
    permissions=(ROOT/'builds/android_permissions.log').read_text()
    assert 'android.permission.INTERNET' not in permissions, 'Unexpected internet permission'
    manifest['verification']={'linux':'Exported binary headless startup, 30 frames, no game errors','windows':'PE export only; native execution not tested','android':'Signature, manifest, ARM64 payload and no INTERNET permission verified; no device connected, execution not tested'}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('ARTIFACT VERIFICATION PASSED; Android ELF alignment:',alignments)
