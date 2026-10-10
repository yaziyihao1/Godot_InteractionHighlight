# 演示
[English](playground.md)

发布入口为 `res://scene/interaction_highlight_demo.tscn`。宿主脚本位于 `res://scripts/`，诊断预览着色器位于 `res://shader/`，未改动的 addon 只负责高光核心。

| 操作 | 行为 |
|---|---|
| WASD / 鼠标 | 捕获鼠标时水平移动 / 转向 |
| 中央准星 | 物理射线选择首个可命中样本；未命中或命中其他几何时清除选择 |
| E | 开关设置面板；暂停移动/选择查询，但保留当前高光 |
| Esc | 关闭设置并释放鼠标 |
| UI 外点击 | 关闭面板并重新捕获鼠标 |

移动是范围受限的自由相机，不是基于碰撞的玩家控制器。射线长 24 米。七种原创程序化模型为方块、球体、真实孔洞把手、细杆/薄面、含艺术家 Overlay 的刚性多网格、双骨骼蒙皮、BlendShape。骨骼/形变默认动画，前景挡块展示局部遮挡。碰撞为静态 fixture 形状，不随动画连续形变。

小型可滚动面板含同步滑块/数字输入、独立八色轮廓/填充色板、轮廓宽度/不透明度、微光强度、填充开关、填充透明度及重置。即时应用；重置恢复演示默认：仅轮廓、白色 2.5 像素、不透明度 1、微光强度 0.12/宽度 3、黄色填充 alpha 0.25、深度容差 0.002 米。透明度为 `100 × (1 - fill_alpha)`，75% 透明即 0.25 不透明度。不提供保存/加载。

## 诊断

默认折叠诊断并关闭预览；启用后显示状态，可切换 Coverage（RGBA16F）或 Target Depth（米）。coverage 预览 RGB 分别显示轮廓、可见填充和微光；A 保存完整投影，不用作该 RGB 预览的 alpha。目标深度把原始反向 Z 经相机投影逆矩阵转换为正的视空间米制值，再将显示范围从青色映射到橙色；暗色表示没有目标。显示范围随目标移动，只影响可视化，不改变深度纹理格式。

状态通过 `get_debug_state()` 展示数据/叠加 ready、新鲜度、depth/coverage 帧龄和支持/运行错误。预览重新获取 `get_debug_coverage_texture()` 或 `get_debug_depth_texture()`，核对就绪与尺寸并刷新 sampler，不逐帧读回 GPU。`request_debug_readback()` 保留供显式工具/QA 使用。

这些公共方法为稳定接口，内部节点/RID 寿命不作承诺。参见[API 与核心默认值](../addons/interaction_highlight/docs/api.zh-CN.md)和[实现说明](../addons/interaction_highlight/docs/technical.zh-CN.md)。
