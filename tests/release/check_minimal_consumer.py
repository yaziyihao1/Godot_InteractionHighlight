"""Check external minimal-consumer captures without depending on demo assets."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

out = Path(sys.argv[1])
images = {name: np.asarray(Image.open(out / (name + '.png')).convert('RGB')).astype(float)
          for name in ['off', 'outline', 'fill', 'clear']}
report = json.loads((out / 'manifest.json').read_text(encoding='utf-8'))
checks = {
    'cleared_exactly': np.array_equal(images['off'], images['clear']),
    'outline_drawn': int((np.abs(images['outline'] - images['off']).max(axis=2) > 2).sum()) > 100,
    'fill_drawn': int((np.abs(images['fill'] - images['outline']).max(axis=2) > 2).sum()) > 100,
    'material_unchanged': report['material_unchanged'],
    'hole_not_filled': np.array_equal(images['off'][350:370, 630:650], images['fill'][350:370, 630:650]),
    'pure_addon_consumer': report['addon_only'],
}
(out / 'pixel_report.json').write_text(json.dumps(checks, indent=2), encoding='utf-8')
print(json.dumps(checks, indent=2))
raise SystemExit(not all(checks.values()))
