# 本地开发与复现
[English](portable-release.md)

集成只需 addon 目录。开发时用 Godot 4.7 Forward+ 打开完整发布项目的 `project.godot`，默认入口为 `res://scene/interaction_highlight_demo.tscn`。演示宿主代码统一放在仓库根目录 `scripts/`，不属于可复制 addon。

在发布项目根目录安装可选像素检查依赖并运行：

```text
python -m pip install -r requirements-test.txt
godot --path . --scene res://tests/interaction_highlight/gpu_qa.tscn -- --matrix --output=<absolute-dir>
python tests/interaction_highlight/check_pixels.py <absolute-dir>
```

把 `<absolute-dir>` 换成自己的可写绝对目录，含空格时给完整参数加引号。`godot` 指 PATH 上的 Godot 4.7 控制台程序，可改为自己的执行文件。必须真实 GPU 运行，不传 `--headless`。显式输出便于区分批次；默认输出是 `user://gpu_qa`。Pillow/NumPy 仅供检查器，不是 addon 运行依赖。

QA 写入 `manifest.json`、截图及 R32F/RGBA16F 数值读回；检查器生成 `pixel_report.json`、差分图，成功时另生成审阅裁剪。需查看完整引擎日志、捕获完整性、非零效果和全尺寸 off/outline/fill/clear，包括孔洞与局部遮挡；不能仅靠 JSON PASS 或退出码。`--matrix` 应含 36 个完整五阶段用例、218 捕获及四种分辨率下第 1/2/3/5/10 帧的 20 个 resize 瞬态。

本次发布项目及空白 consumer 的证据见[支持说明](support.zh-CN.md)；打包另行完成。

## 可选本地打包

完整发布项目中运行 `pwsh -File scripts/build_release.ps1`。脚本读取 VERSION（0.3.1），生成含各文件尺寸/SHA256 的 `release_manifest.json`，默认把 `GodotInteractionHighlight_v0.3.1.zip` 写到父目录，并逐条核对 ZIP 内文件尺寸/哈希。已有 ZIP 时使用带时间戳的替代文件名。`-SourceDirectory`、`-OutputDirectory` 可调整位置。

脚本使用的 .NET API 需要 PowerShell 7（`pwsh`）。先完成文档再打包；检查包内容，另需导入/运行实际解包副本。归档哈希检查不能代替运行和目视验证。脚本不创建远程仓库、不上传。

MIT 覆盖所含 addon、原创程序化示例、测试和文档；保留原版权声明。宿主游戏资产及引擎二进制不属于 portable 发布包。
