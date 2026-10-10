# Testing and local packaging
[简体中文](testing.zh-CN.md)

Run from the release project root:

```text
python -m pip install -r requirements-test.txt
godot --path . --scene res://tests/interaction_highlight/gpu_qa.tscn -- --matrix --output=<absolute-dir>
python tests/interaction_highlight/check_pixels.py <absolute-dir>
```

Use your Godot 4.7 console executable and replace the output placeholder with a writable absolute directory; quote spaces. The real-GPU scene rejects headless mode. Pillow/NumPy are optional checker dependencies. Keep runs in separate directories and review full logs and screenshots alongside the report.

The release matrix passed (36 cases / 218 captures), as did the blank addon-only consumer and the playground (35 captures / 27 pixel checks). Screenshots were reviewed. To reproduce the playground check independently:

```text
godot --path . --script res://tests/release/playground_qa.gd --resolution 1280x720 -- --output=<absolute-dir>
python tests/release/check_playground_pixels.py <absolute-dir>
```

For capture phases, output formats and evidence limits, see [reproduction](../addons/interaction_highlight/docs/portable-release.md) and [oracle review](../addons/interaction_highlight/docs/qa-oracle-review.md). Use `pwsh -File scripts/build_release.ps1` to generate the SHA256 manifest and a verified versioned ZIP in the parent directory, then `python tests/release/audit_package.py <zip-path>` for links, dependencies and privacy checks. Import/run a freshly extracted copy separately; archive hashes do not replace visual checks. No remote repository or upload is required.
