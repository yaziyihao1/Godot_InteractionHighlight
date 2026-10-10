"""Check real-window playground captures; run after playground_qa.gd."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('capture_directory', type=Path)
args = parser.parse_args()
root = args.capture_directory
manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
checks = []


def check(passed, label, **evidence):
    checks.append(dict(passed=bool(passed), check=label, **evidence))


def image(name):
    return np.asarray(Image.open(root / (name + '.png')).convert('RGB'), dtype=np.int16)


check(not manifest['headless'] and not manifest['failures'], 'Real GPU host assertions pass')
for index in range(7):
    off = image(f'sample_{index}_off')
    outline = image(f'sample_{index}_outline')
    fill = image(f'sample_{index}_fill')
    clear = image(f'sample_{index}_clear')
    # Skip the selection HUD; all targets are centered in these captures.
    region = (slice(170, 650), slice(320, 950))
    edge_count = int(np.count_nonzero(np.max(np.abs(outline[region] - off[region]), axis=2) > 15))
    fill_count = int(np.count_nonzero(np.max(np.abs(fill[region] - outline[region]), axis=2) > 8))
    check(edge_count > 40, f'Sample {index} visible outline', pixels=edge_count)
    check(fill_count > 40, f'Sample {index} independent surface fill', pixels=fill_count)
    check(np.array_equal(off, clear), f'Sample {index} exact cleanup')

# A camera aiming into the true hole must not produce surface fill at the center.
off = image('sample_2_off')
fill = image('sample_2_fill')
height, width = off.shape[:2]
center = (slice(height // 2 - 3, height // 2 + 4), slice(width // 2 - 3, width // 2 + 4))
check(np.array_equal(off[center], fill[center]), 'Handle hole interior stays untouched')

for name in ['diagnostic_coverage', 'diagnostic_depth']:
    capture = next(c for c in manifest['captures'] if c['case'] == name)
    x, y, w, h = [round(n) for n in capture['preview_rect']]
    pixels = image(name)
    preview = pixels[y:y + h, x:x + w]
    check(0 <= x and 0 <= y and x + w <= pixels.shape[1] and y + h <= pixels.shape[0],
          name + ' preview on screen')
    colored = int(np.count_nonzero(preview.max(axis=2) - preview.min(axis=2) > 20))
    check(colored > 40, name + ' actual numeric texture visible', pixels=colored)

report = dict(status='PASS' if all(c['passed'] for c in checks) else 'FAIL', checks=checks,
              captures=len(manifest['captures']), adapter=manifest['adapter'])
(root / 'pixel_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(report['status'] != 'PASS')
