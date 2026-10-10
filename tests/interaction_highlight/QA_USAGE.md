# GPU regression / GPU 回归

Use Godot 4.7 Forward+ with a real window. The QA scene rejects `--headless`.
使用 Godot 4.7 Forward+ 的真实窗口；无窗口运行不作为视觉验收。

From the repository root / 在仓库根目录：

```text
godot --path . --scene res://tests/interaction_highlight/gpu_qa.tscn --audio-driver Dummy --resolution 1280x720 -- --matrix --output=<absolute-output-directory>
python -m pip install -r requirements-test.txt
python tests/interaction_highlight/check_pixels.py <absolute-output-directory>
```

Replace the engine command and output directory with local absolute paths. Drop `--matrix` for smoke testing; use `--focus` for thin and skinned poses. Without `--output`, results go to the application's user-data `gpu_qa` folder. No developer-machine paths are required.
替换引擎命令和输出目录；去掉 `--matrix` 为冒烟测试，`--focus` 测试细结构和骨骼姿态。未指定输出目录时使用应用数据目录的 `gpu_qa`，不依赖开发机路径。

The engine writes a manifest, actual screenshots, RGBA16F coverage and R32F reverse-Z depth, then exits. The Python checker writes `pixel_report.json` and labeled evidence crops. A passing report is necessary but visual review is still required. Full matrix includes 36 cases, lifecycle checks and resize transients; a smoke run is not a full matrix.
引擎输出截图、覆盖和深度读回后退出；检查器输出报告及证据裁切。报告通过后仍需看图；完整矩阵包括 36 用例、生命周期和窗口缩放瞬态，不可用冒烟测试代替。

Optional PowerShell fresh staging / 可选 PowerShell 全新隔离副本：

```powershell
./tests/interaction_highlight/stage_gpu_qa.ps1 -StageDirectory '<new-absolute-directory>'
```

The staging directory must not exist. Copies only the standalone module and QA files, records matching core hashes, and never deletes or resets an existing project.
隔离目录必须尚不存在；只复制独立模块及测试，记录核心哈希，不删除或重置现有项目。
