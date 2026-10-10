# Review clarification / 审查说明

## English

This replaces the copied development chronology with a portable clarification. Earlier pre-fix failure statements and later historical acceptance claims described different source snapshots. They must not be read as current defects, nor as acceptance of the final 0.3.0 ZIP. Developer machine paths and unavailable host evidence are omitted.

Source review confirms the fixed core has generation/frame freshness checks, callback/raster/wrapper display gates, fresh Texture2DRD wrappers and material rebinding on resize, hidden queued proxies on switches, render-thread GPU disposal, and conditional compositor restoration. These protections explain the implementation; source inspection alone does not prove runtime success.

Current evidence: release-project real-GPU matrix 36 cases / 218 captures and Python checks passed; a separate blank addon-only consumer passed both modes, hole/material and cleanup checks, with screenshots reviewed. Exact ZIP identity and extracted-package results are recorded in the separate delivery report.

Remaining boundaries: unsupported temporal/upscaled/XR rendering, transparent/cutout/custom-vertex materials, simultaneous multi-camera effects, other platforms/GPUs/non-Mono binaries, exhaustive fault injection and systematic performance budgets. See [support](support.md) and [oracle limits](qa-oracle-review.md).

## 简体中文

本文件将复制的开发时间线整理为可移植说明。旧版修复前失败与之后历史验收对应不同源码快照，既不能当作当前缺陷，也不能当作最终 0.3.0 ZIP 放行。开发机路径及不可用宿主证据已省略。

源码确认固定核心具备 generation/帧龄检查、回调/光栅/包装器显示门限、resize 新建 Texture2DRD 并重绑材质、切换时隐藏并排队删除代理、渲染线程 GPU 释放及有条件恢复 compositor。这些是实现事实，静态检查本身不证明运行通过。

本次证据：真实 GPU 36 用例/218 捕获与 Python 检查通过；仅含 addon 的空项目通过两模式、孔洞/材质及清除检查，截图已复核。ZIP 身份和实际解包结果单独记于交付报告。

边界仍包括时域/上采样/XR、透明/裁剪/自定义顶点材质、多相机同时效果、其他平台/GPU/非 Mono 二进制、全部故障注入及系统性性能预算。参见[支持范围](support.zh-CN.md)和[参照边界](qa-oracle-review.md)。
