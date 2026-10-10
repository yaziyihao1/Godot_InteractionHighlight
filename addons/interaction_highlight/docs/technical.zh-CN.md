# 渲染实现
[English](technical.md)

本文依据六个核心文件。实现是深度驱动的屏幕空间效果，加独立 Canvas 叠加。

1. `highlight_renderer.gd` 创建私有 World3D/SubViewport、目标网格代理和匹配主相机变换/投影的相机。代理共享几何与 skin，使用不透明深度代理材质，关闭阴影/GI，同步可见性、BlendShape 与骨骼最终姿态。不会修改源材质或艺术家 material_overlay；私有世界的 layer 1 不占用宿主可见层。
2. `highlight_effect.gd` 请求 resolved depth。辅助 `POST_OPAQUE` 回调将真实 depth layer 复制到 R32F 存储纹理。这是原始反向 Z，不是 ALBEDO 编码颜色，不经过曝光、Glow 或色调映射。两个 effect 都核对预期视口 render target。
3. 主相机 `POST_TRANSPARENT` 回调采样目标与主场景深度。`gpu_state.gd` 的内嵌 compute shader 先做横向 support 预处理，排除空邻域，再生成 RGBA16F coverage；另把 scene depth 复制为 R32F 供显式 QA 读回。
4. `overlay.gdshader` 以 nearest 采样数值 coverage，该 sampler 不做颜色空间转换。CanvasLayer 下的 ColorRect 用 `blend_mix` 合成轮廓/微光与可选可见填充；不采样 scene color、不重画背景，也不是扩张网格或 shader 外壳。

## 遮挡与通道

像素 p 有目标深度时，以完整目标投影 T(p) 抑制轮廓和微光，即使该面被遮挡也如此；该处只写可见填充。这避免把遮挡物造成的可见域边界描成物体内部切口线。

T 外的邻域目标种子 q 必须通过两次比较：q 的目标深度不晚于 q 的场景深度（种子可见），也不晚于落点 p 的场景深度（落点可见）。用实际渲染投影逆矩阵重建正的视空间米制深度 `-view.z/view.w`，加 `depth_bias_m` 容差。它是视空间深度，不是沿射线的欧氏距离。反向 Z 为零表示无表面/无限远。

| RGBA16F 通道 | 含义 |
|---|---|
| R | 外部轮廓覆盖量 |
| G | 目标可见填充覆盖量 |
| B | 外部微光覆盖量 |
| A | 完整目标投影，含被遮挡表面 |

A 是诊断几何覆盖，不是 Canvas 最终不透明度。叠加使用 R/G/B、样式 alpha 和颜色 alpha 计算不透明度。mode 1 忽略 G；mode 2 使用 G，但 R/B 相同。真实投影孔洞可以产生轮廓；重叠网格使用合并投影，不会因材质边界或三角接缝描线。

轮廓公式为 `clamp(width + 0.5 - distance_px, 0, 1)`；微光在轮廓半径外按二次函数衰减。宽度按输出像素计，搜索半径随轮廓及微光宽度增大；大半径/高分辨率会增加开销，没有通用帧耗时或显存预算结论。

## 帧与资源生命周期

capture/compose 共用互斥状态。目标变化增加 generation，compose 要求 generation 匹配且 capture 属于当前绘制帧。snapshot 接受 0–1 帧龄，因为主线程设置可早于当前回调；叠加还核对回调可用性、全部光栅尺寸、包装器绑定、选中网格与支持错误。

resize 暂时隐藏叠加，解除旧包装器，创建新的 Texture2DRD 并明确重绑材质 sampler。Canvas 用逻辑可见区域，coverage 用物理 3D 光栅；适用时借助原生窗口尺寸预判 resize。允许短暂隐藏，恢复时间取决于渲染就绪。

绑定把主 effect 加入新相机 compositor，保留有效的原相机/世界 effects。世界 compositor 查找使用 Godot 4.7 内部 scenario 分组，存在引擎版本敏感性。释放时仅在当前 compositor 仍是本模块安装的实例时恢复原值，保留宿主后续替换。清理会关闭回调/辅助更新、隐藏代理、清空包装器、排队删除节点并在渲染线程释放 GPU 资源。

参见[支持范围](support.zh-CN.md)、[诊断 API](api.zh-CN.md)、[QA 证据边界](qa-oracle-review.md)。
