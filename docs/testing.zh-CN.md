# 测试与本地打包
[English](testing.md)

在发布项目根目录运行：

```text
python -m pip install -r requirements-test.txt
godot --path . --scene res://tests/interaction_highlight/gpu_qa.tscn -- --matrix --output=<absolute-dir>
python tests/interaction_highlight/check_pixels.py <absolute-dir>
```

使用自己的 Godot 4.7 控制台程序，占位符换为可写绝对目录，含空格时加引号。场景要求真实 GPU，拒绝 headless。Pillow/NumPy 是可选检查依赖；批次分目录保存，同时审阅完整日志及截图。

发布矩阵（36 用例/218 捕获）、仅含 addon 的空项目、演示（35 次截图/27 项像素检查）均通过，截图已复核。单独复现演示检查：

```text
godot --path . --script res://tests/release/playground_qa.gd --resolution 1280x720 -- --output=<absolute-dir>
python tests/release/check_playground_pixels.py <absolute-dir>
```

阶段完整性、格式与证据边界见[复现说明](../addons/interaction_highlight/docs/portable-release.zh-CN.md)和[参照审查](../addons/interaction_highlight/docs/qa-oracle-review.md)。使用 `pwsh -File scripts/build_release.ps1` 生成 SHA256 清单及默认位于父目录的 ZIP，再用 `python tests/release/audit_package.py <zip-path>` 检查链接、依赖与隐私。另需对全新解包副本导入、运行和看图复核，哈希不能替代视觉验收。不创建远程仓库、不上传。
