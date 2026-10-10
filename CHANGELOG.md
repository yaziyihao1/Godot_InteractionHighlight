# Changelog / 更新记录

## 0.3.1 — 2026-10-09

- Reorganized the repository into `scene/`, `scripts/`, `shader/`, `addons/interaction_highlight/`, `tests/` and `docs/`, matching the project's runnable-scene layout.
- Moved all demo/host code out of the addon; the addon now contains runtime code and integration documentation only.
- Default entry is `res://scene/interaction_highlight_demo.tscn`; the six rendering core files and public API are unchanged.
- Added a clean addon-only package audit rule and refreshed bilingual import/integration instructions.

中文版：

- 按可运行场景项目的方式重排为 `scene/`、`scripts/`、`shader/`、`addons/interaction_highlight/`、`tests/` 和 `docs/`。
- 所有演示/宿主代码移出 addon，addon 现在只包含运行时代码和接入文档。
- 默认入口改为 `res://scene/interaction_highlight_demo.tscn`，六个渲染核心文件与公共 API 不变。
- 增加 addon 纯运行时目录审计，并更新中英文导入/接入说明。

## 0.3.0 — 2026-10-09

Documentation follow-up: reorganized both READMEs into demo import, addon installation, Inspector tuning, interaction hooks and troubleshooting. The optional `scripts/quick_start.gd` host example is outside the addon; exported scene references and both modes were verified in a fresh addon-only GPU project. Six rendering core files remain unchanged.

说明更新：中英文 README 改为演示导入、模块复制、检查器调参、互动接入和排错的顺序；可选入门脚本放在仓库根目录 `scripts/`，已在仅复制模块的新项目验证场景引用与两模式。六个渲染核心文件未改。

- Portable release project with a standalone WASD/mouse-ray playground, seven procedural models and an E-key tuning panel that retains selection; session-only settings.
- Optional diagnostics, off by default: numeric coverage, linearized target-depth preview and renderer readiness/freshness/error status.
- Complete English/Chinese installation, public API/defaults, depth/compute implementation, support and local QA/packaging documentation; copied historical notes clarified.
- Version metadata, optional Pillow/NumPy test requirements and generated-output ignore rules that preserve Godot UID files.
- Existing six core renderer files retained unchanged: R32F depth capture, RGBA16F depth-tested coverage and canvas blending.
- Validation: real-GPU matrix 36 cases / 218 captures, playground 35 captures / 27 pixel checks, and blank addon-only off/outline/fill/clear plus hole/material checks passed. Screenshots reviewed; per-file hashes accompany the archive.

中文版：

- 独立 portable 项目，WASD/鼠标射线演示，七种程序化模型，E 调参面板保留选择；设置仅当前会话。
- 诊断默认关闭：数值 coverage、线性化目标深度、ready/freshness/错误状态。
- 完整中英文安装、公共 API/默认值、深度/compute 原理、支持范围与本地 QA/打包文档；澄清复制的历史记录。
- 版本信息、可选 Pillow/NumPy 测试依赖与生成物忽略规则，保留 UID。
- 六个核心 renderer 文件未改，继续使用 R32F 深度、RGBA16F 遮挡 coverage 和 Canvas 混合。
- 验证：真实 GPU 矩阵 36 用例/218 捕获、演示 35 次截图/27 项像素检查、仅含 addon 的空项目两模式及孔洞/材质检查均通过；截图已复核，归档附逐文件哈希。

Earlier copied development reports are historical context, not published version history or final-package evidence. / 复制的早期开发报告属于历史背景，不是已发布版本记录或最终包证据。
