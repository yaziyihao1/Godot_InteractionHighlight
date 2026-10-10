# 支持范围与证据
[English](support.md)

目标环境为 Godot 4.7 Forward+、纯 GDScript、单个显式绑定相机、不透明 MeshInstance3D、1:1 3D 渲染。直接测试环境是 Windows、Godot 4.7 stable Mono、Vulkan、RTX 5060 Laptop。纯 GDScript 无 C# 项目依赖，不等于已分别测试非 Mono 二进制、其他 GPU/平台或引擎版本。

0.3.1 结构版本保留已验证的 0.3.0 渲染核心及其 GPU 证据。重排后的源码已通过 35 张演示截图、36 用例/218 张截图的核心矩阵，以及仅复制 addon 的新项目检查；最终交付记录会标明确切归档与证据。

源码处理根/后代/显式网格、变换、祖先可见性、共享网格/材质、骨骼姿态和 BlendShape。QA 覆盖不透明遮挡、选择切换/清除、hide/free、rebind、输出分辨率及 resize 瞬态。核心 2 像素样式为 QA 基线，playground 用 2.5 像素；绑定/resize 期间允许暂时隐藏。

## 限制

- 不支持 Compatibility/Mobile。运行时拒绝 TAA、XR 和不支持的缩放/上采样；使用 1:1，关闭 FSR 与动态 3D 缩放。
- 透明目标、玻璃遮挡、alpha cutout 和自定义顶点 shader 形变不在契约内。代理不复制材质 discard/alpha/顶点逻辑；不写深度的透明几何无法遮挡高光，POST_TRANSPARENT 不会凭空产生玻璃深度。
- 未验证多相机同时高光、XR/multiview、传送门选择及所有 MSAA 组合。
- 一个集合合并为一个选择投影，不支持集合内独立样式；结构变化后需重新收集。
- 不宣称系统性性能/显存压力预算、逐面精确米制误差、曝光变化对照或全部永久 GPU/shader 故障注入结果。

[QA 边界](qa-oracle-review.md)区分 renderer 输出、独立几何参照与目视验收。历史宿主游戏集成结果不扩大 addon 的支持契约。
