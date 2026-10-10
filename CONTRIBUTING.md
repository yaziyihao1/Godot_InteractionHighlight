# Contributing / 贡献说明

## English

Work locally in a complete release-project copy. Keep integration docs inside the addon and update their English/Chinese pairs together. Preserve the original MIT notice and `.uid` files. Use original procedural fixtures; do not include host assets, engine binaries, cache directories or private machine paths.

Changes should describe the problem, resulting behavior, affected support boundaries and checks actually run. Keep the five integration methods and four diagnostic methods compatible. Do not make callers depend on private nodes or RID identities. Source inspection, historical results and a fresh release run are different evidence.

For renderer changes, use Godot 4.7 Forward+ on a real GPU and run:

```text
python -m pip install -r requirements-test.txt
godot --path . --scene res://tests/interaction_highlight/gpu_qa.tscn -- --matrix --output=<absolute-dir>
python tests/interaction_highlight/check_pixels.py <absolute-dir>
```

Replace the output placeholder, quote spaces, and do not use headless. Record engine binary/build, OS, GPU/backend, rendering settings, logs and report; inspect full-size off/outline/fill/clear, holes and occlusion. Confirm required phases and nonzero effects rather than accepting a PASS label alone. For docs-only changes, check links, source/default consistency and path hygiene; do not claim GPU tests you did not run.

In the 0.3.1 structure refactor the six renderer core files remain frozen. Propose future core changes separately; this document does not authorize edits to that freeze. Packaging is optional/local; see [testing](docs/testing.md). No external repository, message or upload is part of local contribution.

## 简体中文

在完整发布项目副本内本地开发；集成文档放在 addon 内，中英文同步修改。保留原 MIT 版权与 `.uid`。使用原创程序化 fixture，不夹带宿主资产、引擎二进制、缓存或私人机器路径。

变更说明应写清问题、最终行为、支持边界及实际完成检查。保留五个集成方法和四个诊断方法的兼容性，不依赖内部节点/RID 身份。静态检查、历史结果和新的发布运行是不同证据。

渲染修改需 Godot 4.7 Forward+ 真实 GPU，运行上面的完整矩阵和 Python 检查；占位符改成自己的输出目录，含空格加引号，不用 headless。记录引擎构建、OS、GPU/后端、渲染参数、日志和报告，亲看全尺寸 off/outline/fill/clear、孔洞和遮挡；核对阶段完整及非零效果，不能只看 PASS。仅文档修改检查链接、源码/默认值一致性与路径，不宣称未运行的 GPU 测试。

本次 0.3.1 结构重构中六个核心文件继续冻结，未来核心修改另提，不因本文获得解冻授权。可选打包只在本地，见[测试说明](docs/testing.zh-CN.md)，不涉及外部仓库、发消息或上传。
