# QA oracle and evidence limits / QA 参照与证据边界

## English

The bundled QA scene first captures original-art off/outline/fill, then independent white-target/black-surroundings geometry passes for complete projection and visible geometry. Coverage/depth readbacks are outputs under test, not independent ground truth. Material identity, surface assignments and property fingerprints help detect unintended source changes.

The matrix covers 36 complete five-phase cases and 218 captures, including 20 resize transients, nine distance/angle combinations, real bone/blend-shape changes, occlusion, shared resources and lifecycle comparisons. The pixel checker constrains changed image regions with a one-pixel raster guard, compares complete/visible masks, checks foreground-wall leaks, cross-mode R/B equality and nonzero effects, and rejects missing required matrix phases/transients/lifecycle pairs.

The 2 px envelope test uses GPU seeds after comparison with the independent raster reference; it is not a wholly independent subpixel width measurement. Depth tests check finite values and reversed-Z range, not precise error at every known surface. The independent floor model is a ray/plane approximation for the fixture, not proof for arbitrary scenes. A later state snapshot does not establish screenshot-time visibility.

The release passed the 36-case/218-capture GPU run and Python checks, plus a blank addon-only consumer's off/outline/fill/clear and actual hole/material checks. Screenshots were reviewed. Archive integrity and extraction/runtime results are separate evidence, recorded in the delivery report.

Earlier copied notes described pre-fix resize white screens, stale coverage and shutdown errors, followed by fixed-core regression results. Those claims and private artifact references belonged to historical development snapshots; they are not a current failure report or final-package acceptance. The current source contains freshness, wrapper-rebinding and deferred teardown protections. No historical counts, hashes or unavailable host logs are used to certify this release.

## 简体中文

QA 先捕获原材质 off/outline/fill，再用独立的白色目标/黑色周围几何渲染完整投影与可见域。coverage/深度读回是待测输出，不是独立真值。材质 identity、surface 指派和属性 fingerprint 用于检测意外修改。

矩阵包含 36 个完整五阶段用例、218 捕获，其中有 20 个 resize 瞬态、九种距离/角度组合、真实骨骼/BlendShape、遮挡、共享资源及生命周期对照。像素检查器以 1 像素光栅 guard 限定修改域，比较完整/可见域、前景墙泄漏、跨模式 R/B 和非零效果，并拒绝缺失的必需阶段、瞬态与生命周期配对。

2 像素包络在独立光栅参照核对后仍使用 GPU 种子，不是完全独立的亚像素测宽。深度检查有限值和反向 Z 范围，并非逐面精确误差；独立地面射线/平面模型仅适用于 fixture，不能证明任意场景。截图后的状态快照不证明截图当帧实际显示。

发布通过 36 用例/218 捕获的真实 GPU 与 Python 检查，以及仅含 addon 的空项目两模式、孔洞/材质检查；截图已复核。归档完整性与解包运行是独立证据，单独记于交付报告。

早期复制文档记载过修复前 resize 白屏、旧 coverage 和退出错误，以及之后固定核心的回归。它们与私有产物引用属于历史开发快照，不是当前缺陷报告，也不是最终包验收。现源码包含 freshness、包装器重绑和延后清理防护；不使用旧计数、哈希或不可用宿主日志为本次发布认证。
