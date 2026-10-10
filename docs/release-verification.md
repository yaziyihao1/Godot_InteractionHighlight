# v0.3.1 verification / 发布验证

The six runtime core files match the manually accepted game implementation byte-for-byte. Release work adds a standalone host, documentation and reproducible tests; the original game and its player settings were not modified.
六个运行核心文件与用户手动验收的游戏版本逐字节一致；发布工作只新增独立演示、文档与测试，未改动原游戏或其玩家设置。

## Actual environment / 实际环境

Godot 4.7 stable Mono, Windows, Vulkan Forward+, NVIDIA GeForce RTX 5060 Laptop GPU. The independent project and addon use only GDScript; running the regular non-Mono engine or another platform/GPU was not part of this verification.
实际使用上述 Mono 引擎运行纯 GDScript 项目；未单独验证普通非 Mono 引擎、其他平台或显卡。

## Rendering core / 渲染核心

- Full real-window matrix: 36 cases, 218 captures, Python pixel report PASS, zero failures.
- Coverage includes outline/fill, true holes, thin structures, opaque full/partial occlusion, materials and overlays, bone and BlendShape deformation, target switching, lifecycle cleanup, camera rebinding, 720p/1080p/1440p/4:3 and resize transients.
- Captures are actual GPU images and RGBA16F/R32F readbacks, not generated mockups. Representative hole, occlusion and skinned images were visually reviewed.

完整真实窗口矩阵 36 用例、218 次截图，像素报告通过。包括两模式、孔洞、薄结构、遮挡、材质、形变、切换、清理、重绑定与分辨率；主进程看图复核，不把状态标签代替视觉证据。

## Minimal consumer / 最小接入

A new empty Godot project installed only `addons/interaction_highlight`, without the release's root demo or tests. A small host created a Camera3D and torus, bound the renderer after scene setup, applied a style and exercised clear/outline/fill/clear. Real GPU images and pixel comparisons verified visible outlines, fill, an untouched hole, unchanged material and exact cleanup.
全新空项目只复制插件目录，创建摄像机与圆环并按接入流程绑定。实际 GPU 截图与像素比较确认轮廓、填充、孔洞、材质保持和清除，不需要原游戏或发布根演示。

## Standalone playground and final archive / 独立演示与最终归档

The standalone playground passed 35 actual GPU captures and 27 independent pixel checks: seven objects in both modes, exact cleanup, true hole interior, E-key selection retention, width/color/opacity/glow controls, reset, resize, and visible coverage/depth previews. An explicit asynchronous R32F readback reconstructed the target's view depth in metres. Host control checks also passed 58 assertions.
独立演示通过 35 次实际 GPU 截图和 27 项像素检查，包含七对象两模式、精确清除、孔洞、E 面板保留选择、调参恢复、缩放及真正显示出来的诊断纹理。异步 R32F 读回验证米制深度，宿主控制另有 58 项断言通过。

The archive recipe reads and hashes every entry. The separate package auditor checks resource/document links, excluded host dependencies and private paths. Fresh extraction/import/runtime acceptance and the final ZIP SHA256 are recorded in the external delivery report, avoiding a self-referential ZIP hash inside the archive. No remote repository was created.
归档逐条读取并核对哈希，独立审计检查资源/文档链接、宿主依赖和私有路径。最终解包导入/运行结果及 ZIP SHA256 记于外部交付记录，避免归档内哈希自引用；未创建远程仓库。

## Known environment notices / 环境提示

Restricted runs cannot write the engine's user-data Vulkan shader cache, so the engine disables caching and prints a cache-directory diagnostic. Rendering and readbacks still run on the actual GPU. This is not a claim that all environments are warning-free; scene/script exceptions and lifecycle errors must be reviewed separately.
受限运行无法写入引擎用户目录的 Vulkan 缓存，缓存关闭但实际 GPU 渲染正常。不能因此忽略脚本、场景或生命周期错误，也不宣称所有环境都无警告。
