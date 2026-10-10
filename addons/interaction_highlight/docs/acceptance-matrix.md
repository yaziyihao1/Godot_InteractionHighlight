# Acceptance map / 验收对应表

The rows below distinguish rendering evidence from package integrity. Exact artifact hashes are recorded in the separate delivery report.

下表区分渲染证据与归档完整性；最终产物哈希单独记于交付报告。

| Requirement / 要求 | Evidence / 证据 | Boundary / 边界 |
|---|---|---|
| Outline/fill, holes, material preservation / 轮廓填充、孔洞、材质保持 | Complete GPU matrix plus blank addon-only off/outline/fill/clear and hole/material checks; screenshots reviewed / 完整矩阵＋空白 consumer 检查，截图已审阅 | Raster guard, no display colorimetry / 有光栅容差，非显示器色度测量 |
| Numeric target depth, opaque occlusion / 数值深度、不透明遮挡 | R32F/RGBA16F readbacks and independent geometry references / 数值读回＋独立几何参照 | No per-face exact metre error or glass support / 非逐面精确米制误差，不含玻璃 |
| Meshes, transforms, bones, blend shapes / 网格、变换、骨骼、形变 | 36 complete cases, 218 captures, Python PASS/no failures / 36 完整用例、218 捕获，Python PASS/无失败 | Fixture coverage, not arbitrary shader deformation / fixture 范围，不含任意 shader 形变 |
| Resize, switch, clear, hide/free, rebind / 缩放、切换、清除、隐藏释放、重绑 | Matrix lifecycle pairs, live/fresh and 20 resize transients / 生命周期配对、live/fresh、20 瞬态 | Temporary overlay suppression allowed / 允许暂时隐藏 |
| Portable installation / 独立安装 | Blank consumer with only addon tested on real GPU / 只含 addon 的空白项目真实 GPU 测试 | Windows 4.7 stable Mono, Vulkan, RTX 5060 Laptop only / 仅该环境 |
| Standalone playground / 独立演示 | 35 real GPU captures and 27 pixel checks / 35 次实际 GPU 截图及 27 项像素检查 | Host controls and previews tested separately from core / 宿主控制与预览独立检查 |
| Final package / 最终发布包 | Per-file SHA256 manifest, independent ZIP audit, separate extraction results / 逐文件哈希、独立 ZIP 审计及单独解包记录 | Hashes alone are not visual acceptance / 哈希不代替目视验收 |

Historical host-game, portal, save/menu and earlier ZIP claims from copied documentation do not certify this release or expand its public contract. See [support](support.md) and [QA limits](qa-oracle-review.md).

复制文档里的旧宿主游戏、传送门、存档/菜单和 ZIP 结论不为本次认证，也不扩大公共契约。参见[支持范围](support.zh-CN.md)和[QA 边界](qa-oracle-review.md)。
