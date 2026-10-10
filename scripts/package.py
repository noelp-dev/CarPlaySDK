#!/usr/bin/env python3
"""Create a reproducible source-only review archive; never include SDKs or app data."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'build/nativephp-carplay-0.1.0-review.zip'
output.parent.mkdir(exist_ok=True)
directories = ['src', 'config', 'resources', 'docs', 'examples', 'tests', 'scripts', '.github']
top_level = ['composer.json', 'nativephp.json', 'package.json', 'README.md', 'LICENSE', 'NOTICE.md', 'CHANGELOG.md', 'CONTRIBUTING.md', '.gitignore']
files = [root / name for name in top_level]
for directory in directories:
    files.extend(p for p in (root / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(files):
        if path.is_symlink():
            raise RuntimeError(f'Refusing to archive a symlink: {path}')
        info = zipfile.ZipInfo('nativephp-carplay/' + path.relative_to(root).as_posix(), (1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes())
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
print(f'Packaged {len(files)} source/documentation files: {output}')
print(f'SHA-256: {digest}')
