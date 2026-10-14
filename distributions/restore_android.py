#!/usr/bin/env python3
"""Reassemble the preserved Android APK and verify every byte with SHA-256."""
import hashlib
import json
from pathlib import Path


def main():
    directory = Path(__file__).resolve().parent
    parts_directory = directory / 'android'
    manifest = json.loads((parts_directory / 'manifest.json').read_text())
    output = directory / manifest['output_file']
    expected = manifest['sha256']
    if output.exists():
        if output.stat().st_size == manifest['size_bytes'] and hashlib.sha256(output.read_bytes()).hexdigest() == expected:
            print(f'Already restored and verified: {output}')
            return
        raise SystemExit(f'Refusing to overwrite a different file: {output}')
    temporary = output.with_suffix('.apk.tmp')
    digest = hashlib.sha256()
    try:
        with temporary.open('wb') as target:
            for part in manifest['parts']:
                data = (parts_directory / part['file']).read_bytes()
                if len(data) != part['size_bytes'] or hashlib.sha256(data).hexdigest() != part['sha256']:
                    raise ValueError(f"Missing or damaged part: {part['file']}")
                digest.update(data)
                target.write(data)
        if temporary.stat().st_size != manifest['size_bytes'] or digest.hexdigest() != expected:
            raise ValueError('Reassembled APK checksum does not match the original')
        temporary.rename(output)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    print(f'Restored and verified: {output}')
    print(f'SHA256: {expected}')


if __name__ == '__main__':
    main()
