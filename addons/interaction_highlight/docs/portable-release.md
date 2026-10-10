# Local development and reproduction
[简体中文](portable-release.zh-CN.md)

Integration needs only the addon directory. For development, open the complete release project's `project.godot` in Godot 4.7 Forward+; the default entry is `res://scene/interaction_highlight_demo.tscn`. Demo host code is kept at the repository root under `scripts/` and is not part of the portable addon.

From the release project root, install optional pixel-checker dependencies:

```text
python -m pip install -r requirements-test.txt
godot --path . --scene res://tests/interaction_highlight/gpu_qa.tscn -- --matrix --output=<absolute-dir>
python tests/interaction_highlight/check_pixels.py <absolute-dir>
```

Replace `<absolute-dir>` with your own writable absolute directory, quoting the argument if it contains spaces. `godot` means a Godot 4.7 console executable on PATH; use your executable name/path if different. Run on a real GPU, without `--headless`. Explicit output keeps separate runs reproducible; the QA default is `user://gpu_qa`. Pillow and NumPy are checker dependencies, not addon runtime dependencies.

QA writes `manifest.json`, screenshots and numeric R32F/RGBA16F readbacks; the checker writes `pixel_report.json`, difference images and, on success, review crops. Inspect full engine logs, capture completeness, nonzero effects and full-size off/outline/fill/clear images, including holes and partial occlusion. A JSON PASS or exit code alone is insufficient. For `--matrix`, expect 36 complete five-phase cases, 218 captures and 20 resize transients at frames 1/2/3/5/10 across four resolutions.

Current release-project and blank-consumer evidence is described in [support](support.md); packaging is a separate step.

## Optional local packaging

In the full release project, run `pwsh -File scripts/build_release.ps1`. The recipe reads VERSION (0.3.1), generates `release_manifest.json` with per-file sizes/SHA256, writes `GodotInteractionHighlight_v0.3.1.zip` in the parent directory by default, and checks archived entries against source sizes/hashes. Existing ZIPs get a timestamped alternative name. Optional `-SourceDirectory` and `-OutputDirectory` change those locations.

Use PowerShell 7 (`pwsh`) for the .NET APIs used by this script. Finalize docs before packaging. Inspect archive contents and import/run an extracted copy; archive hash checks do not replace runtime/visual verification. No repository creation or upload is part of the recipe.

MIT applies to the included addon, original procedural examples, tests and documentation. Keep the original copyright notice. Host-game assets and engine binaries are not part of the portable release.
