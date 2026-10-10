# 安装
[English](install.md)

## 最快接入：拖入相机与目标

复制模块后，在自己的场景下新建 Node3D，使用仓库中的 `scripts/quick_start.gd` 作为宿主示例，或把它复制到自己项目的 `scripts/`。把正在使用的 Camera3D 拖到 `camera`，把物体根节点拖到 `test_target`。展开 `highlight_style` 调粗细、颜色和填充；运行自己的场景即可验证。

这只是可选宿主示例，不是新的核心依赖；不会添加准星、输入或调参面板。运行初始化完成后可调用 `show_target(node)` 切换目标，`clear_highlight()` 清除。不应把整个世界根节点作为目标。

## 自己写宿主脚本

下面的方法不依赖入门脚本，适合已有交互系统的项目。

只需把完整的 `addons/interaction_highlight/` 复制到目标 Godot 项目的同一路径，保留着色器、资源、场景、许可证与 `.uid`。根目录的演示、测试和打包工具可选；不需要启用编辑器插件、autoload 或宿主资产。

使用 Godot 4.7 Forward+、1:1 3D 渲染，关闭 TAA，不启用上采样，缩放模式为 bilinear/nearest。建议先关闭 MSAA，与演示及 QA 基线一致。代码为纯 GDScript；直接测试环境是 Windows、4.7 stable Mono、RTX 5060 Laptop、Vulkan。没有分别验证非 Mono 引擎或其他平台/GPU。

将以下脚本挂在含 `Camera3D` 和 `Target` 子节点的父节点上。绑定会在相机视口下添加辅助视口，因此要延后到父节点 ready 调用栈结束。

```gdscript
extends Node3D
const Renderer = preload("res://addons/interaction_highlight/highlight_renderer.gd")
const Style = preload("res://addons/interaction_highlight/highlight_style.gd")

var highlighter: Node
var bound := false

func _ready() -> void:
    highlighter = Renderer.new()
    add_child(highlighter)
    call_deferred("_bind_highlighter")

func _bind_highlighter() -> void:
    if not is_inside_tree() or not $Camera3D.is_inside_tree():
        return
    highlighter.bind_camera($Camera3D)
    highlighter.apply_style(Style.new())
    highlighter.set_target($Target)
    bound = true

func replace_selection(next_target: Node3D) -> void:
    if bound:
        highlighter.set_target(next_target) # null 同样清除选择

func use_explicit_meshes(meshes: Array[MeshInstance3D]) -> void:
    if bound:
        highlighter.set_meshes(meshes) # 替换整个选择集合

func clear_selection() -> void:
    if bound:
        highlighter.clear_target()
```

宿主负责射线、输入、距离限制和菜单策略。禁用互动的游戏菜单打开时调用 `clear_target()`，关闭后重新获取目标。调参面板可以像发布演示一样有意保留目标；只停止射线查询会继续显示上次选择。

切换相机时先让新相机入树，按需要设为 current，再调用 `bind_camera(new_camera)`。用 `bind_camera(null)` 解绑并释放运行时；删除 renderer 也会清理。目标退出会清除选择，相机退出会清除选择及运行时。新绑定或窗口 resize 等待纹理就绪期间可暂时隐藏高光，不承诺固定恢复帧数。

完整演示属于仓库根项目的 `res://scene/interaction_highlight_demo.tscn`，不属于可复制 addon。只复制 addon 时请使用本页 API 或自己的宿主输入系统。

参见 [API 与默认值](api.zh-CN.md)、[实现原理](technical.zh-CN.md)、[支持范围](support.zh-CN.md)。
