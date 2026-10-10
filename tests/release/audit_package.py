"""Verify a release ZIP's manifest, local links and independent dependencies."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path, PurePosixPath

parser = argparse.ArgumentParser()
parser.add_argument('archive', type=Path)
parser.add_argument('--report', type=Path)
args = parser.parse_args()
failures = []
with zipfile.ZipFile(args.archive) as archive:
    names = set(archive.namelist())
    manifest = json.loads(archive.read('release_manifest.json').decode('utf-8-sig'))
    expected = {f['path']: f for f in manifest['files']}
    if names != set(expected) | {'release_manifest.json'}:
        failures.append('Archive files differ from manifest')
    for name, entry in expected.items():
        data = archive.read(name)
        if len(data) != entry['size'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
            failures.append('Hash/size mismatch: ' + name)
    required = ['README.md', 'README.zh-CN.md', 'LICENSE', 'VERSION', 'project.godot',
                'CONTRIBUTING.md', 'CHANGELOG.md', 'scene/interaction_highlight_demo.tscn',
                'scripts/interaction_highlight_demo.gd',
                'addons/interaction_highlight/highlight_renderer.gd',
                'tests/interaction_highlight/gpu_qa.gd']
    for name in required:
        if name not in names:
            failures.append('Missing required file: ' + name)
    for name in sorted(names):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts:
            failures.append('Unsafe archive path: ' + name)
        if any(p in ['.godot', '.git', '__pycache__', 'runs', 'bin', 'obj', 'godot-mcp'] for p in path.parts):
            failures.append('Cache/host/plugin leak: ' + name)
        if name.startswith('addons/interaction_highlight/examples/'):
            failures.append('Demo leaked into runtime addon: ' + name)
        if path.suffix.lower() in ['.cs', '.csproj', '.dll', '.exe', '.fbx', '.log', '.pyc'] or path.name == 'settings.json':
            failures.append('Host asset or generated/private file: ' + name)
        if path.suffix.lower() not in ['.md', '.gd', '.gdshader', '.ps1', '.py', '.tscn', '.godot', '.txt', '.json']:
            continue
        text = archive.read(name).decode('utf-8-sig')
        if re.search(r'[A-Za-z]:[/\\]Users[/\\][^/\\\s]+|\u0063odex\u5de5\u4f5c\u533a', text):
            failures.append('Developer/private path: ' + name)
        if path.suffix.lower() in ['.gd', '.tscn']:
            refs = re.findall(r'(?:preload\(|extends\s+|path=)"res://([^"\n]+)"', text)
            for ref in refs:
                if ref not in names:
                    failures.append(f'Missing resource {ref} referenced by {name}')
        if path.suffix.lower() == '.md':
            links = re.findall(r'\]\(([^)]+)\)', text)
            for link in links:
                link = link.split('#', 1)[0].strip('<>')
                if not link or '://' in link or link.startswith('mailto:'):
                    continue
                # Resolve relative Markdown targets without touching the filesystem.
                parts = []
                for part in (path.parent / link).parts:
                    if part == '..':
                        if parts:
                            parts.pop()
                    elif part != '.':
                        parts.append(part)
                resolved = '/'.join(parts)
                if resolved not in names:
                    failures.append(f'Broken documentation link {link} in {name}')
report = {'version': manifest['version'], 'files': len(expected), 'failures': failures,
          'status': 'PASS' if not failures else 'FAIL',
          'zip_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest()}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(report, indent=2, ensure_ascii=False))
raise SystemExit(bool(failures))
