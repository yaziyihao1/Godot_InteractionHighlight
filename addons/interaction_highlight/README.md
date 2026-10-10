# Interaction Highlight 0.3.1

[English installation](docs/install.md) · [中文安装](docs/install.zh-CN.md) · [API / defaults](docs/api.md) · [中文 API](docs/api.zh-CN.md)

A pure-GDScript Godot 4.7 Forward+ addon for a host-selected object: white screen-space outline with subtle glow, optionally visible-surface fill. Copy only this complete `addons/interaction_highlight/` directory, preserving its path and `.uid` files.

纯 GDScript Godot 4.7 Forward+ 模块，为宿主选中的对象绘制屏幕空间轮廓、微光及可选可见填充。安装只需复制本目录，保留路径与 `.uid`。宿主负责射线、输入、菜单及存档。

Core defaults: mode 1, white outline at 2 output pixels, opacity 1, glow strength 0.12/width 3, pale-gold fill `Color(1, 0.85, 0.4, 1)` at alpha 0.25, depth bias 0.002 metres. Alpha 0.25 means 75% transparency. The release project's playground instead uses 2.5 px and yellow fill.

核心默认 mode 1、白色 2 输出像素轮廓、不透明度 1、微光强度 0.12/宽度 3、淡金填充 alpha 0.25（75% 透明）、深度容差 0.002 米。发布项目 playground 则用 2.5 像素及黄色填充。

[Installation](docs/install.md) includes deferred-ready binding and all five integration methods: `bind_camera`, `set_target`, `set_meshes`, `apply_style`, `clear_target`. [安装示例](docs/install.zh-CN.md)覆盖延后绑定、替换/切换/清除、菜单和生命周期。The complete repository demo is `res://scene/interaction_highlight_demo.tscn`; this addon directory contains runtime code and integration docs only.

The renderer captures R32F target depth at auxiliary POST_OPAQUE, computes depth-tested RGBA16F coverage at main POST_TRANSPARENT, and blends a canvas overlay without sampling scene color or changing source materials. [Implementation](docs/technical.md) / [技术说明](docs/technical.zh-CN.md).

Directly tested environment: Windows, Godot 4.7 stable Mono, Vulkan Forward+, RTX 5060 Laptop. The release GPU matrix and blank addon-only consumer passed. [Support/evidence](docs/support.md) / [支持与证据](docs/support.zh-CN.md) list limitations; no separate non-Mono/platform validation is claimed.

[MIT](LICENSE) — Copyright (c) 2026 Interaction Highlight contributors. Original procedural samples are included; host-game assets and engine binaries are not. 原版权声明保持不变，不包含宿主资产。
