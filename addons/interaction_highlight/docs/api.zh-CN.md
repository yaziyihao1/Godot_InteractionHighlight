# 公共 API
[English](api.md)

`InteractionHighlighter` 继承 Node，`HighlightStyle` 继承 Resource。按[安装示例](install.zh-CN.md)显式 preload，并在节点入树且父节点 ready 调用栈结束后绑定。

| 方法 | 行为 |
|---|---|
| `bind_camera(camera: Camera3D)` | 显式绑定一个相机；null 解绑。重绑定重建运行时，保留已选网格；旧相机退出会清除选择。 |
| `set_target(target: Node3D)` | 用根本身（若为网格）及后代 MeshInstance3D 替换选择；null 清除。 |
| `set_meshes(meshes: Array[MeshInstance3D])` | 替换显式网格集合；忽略无效、重复或无 mesh 项，断开根目标关联。 |
| `apply_style(value: HighlightStyle)` | 保留资源引用；null 创建默认样式。 |
| `clear_target()` | 清除源/代理、使 coverage 失效并立即隐藏叠加，可重复调用。 |

目标只在提交时扫描。同一有效根再次调用 `set_target()` 会提前返回；增删子网格时应提交完整集合，或 clear 后重新提交根。已收集网格的变换、祖先可见性、相机层可见性、mesh 资源替换、BlendShape 与骨骼最终姿态会同步；拓扑变化需主动重新提交。

样式按引用共享；独立参数请 new 或 duplicate。字段修改每帧更新，`apply_style()` 也会立即更新叠加参数。

## 核心字段默认值

| 字段 | 默认值 | 含义 / 范围 |
|---|---|---|
| `mode` | `1` | 1 轮廓；2 可见填充＋相同轮廓 |
| `outline_color` | `Color.WHITE` | 颜色 alpha 参与轮廓/微光不透明度 |
| `outline_width_px` | `2.0` | 输出像素半径，限制 0.5–12 |
| `outline_alpha` | `1.0` | 不透明度，限制 0–1 |
| `glow_strength` | `0.12` | 限制 0–1；为零时不计算微光宽度 |
| `glow_width_px` | `3.0` | 额外输出像素范围，限制 0–16 |
| `fill_color` | `Color(1.0, 0.85, 0.4, 1.0)` | 淡金色，颜色 alpha 参与填充不透明度 |
| `fill_alpha` | `0.25` | 不透明度，限制 0–1，即 75% 透明 |
| `depth_bias_m` | `0.002` | 米制视空间深度容差，运行时限制非负，Inspector 范围 0–0.05 |

仅用有限数值；depth bias 没有运行时上限。宽度是屏幕空间抗锯齿半径，不是世界空间外壳厚度。mode 0 不属于约定样式模式；关闭效果请用 `clear_target()`。

根目录 playground 有意改为 2.5 像素及 `Color.YELLOW` 填充，初始白色轮廓完全不透明、填充 alpha 0.25（75% 透明）。这些是演示设置，核心默认值未改。renderer 的 `overlay_layer` 默认 1，宿主 UI 应放在更高层。

## 稳定公共诊断接口

| 方法 | 输出 |
|---|---|
| `get_debug_state()` | Dictionary：活动/就绪、错误、光栅尺寸、新鲜度/帧龄、回调计数、代理/骨骼计数、目标 ID、通道说明。 |
| `get_debug_coverage_texture()` | 当前 coverage Texture2DRD 包装器；未绑定时可为 null。 |
| `get_debug_depth_texture()` | 当前目标深度 Texture2DRD 包装器；未绑定时可为 null。 |
| `request_debug_readback(kind, callback)` | 主动 GPU 读回，主线程延后回调；kind 为 `depth`、`scene_depth`、`coverage`。 |

这些方法保留为公共 API；getter 不读回 GPU 内存。resize/rebind 会替换包装器，应重新获取。内部节点、字典新增字段与 RID 身份/寿命不是稳定契约，不要释放诊断 RID。

成功 payload 含 `kind`、`size`、`format`、`data`；无效/未绑定请求另含 `error`，释放后可能返回空数据。解码前检查尺寸、格式和字节数。coverage 为 RGBA16F；深度为 R32F 反向 Z，并非线性米制值。读回可造成停顿，适合工具/QA，不用于每帧正常显示。

`ready` 表示数据状态，`overlay_ready` 表示显示门限；二者都不能单独证明截图效果正确，需核对非零 coverage 和实际像素。参见[技术说明](technical.zh-CN.md)。
