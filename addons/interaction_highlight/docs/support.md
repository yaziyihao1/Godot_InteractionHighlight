# Support and evidence
[简体中文](support.zh-CN.md)

Target environment: Godot 4.7 Forward+, pure GDScript, one explicitly bound camera, opaque MeshInstance3D geometry and 1:1 3D rendering. Directly tested environment: Windows, Godot 4.7 stable Mono, Vulkan, RTX 5060 Laptop. Pure GDScript has no C# project dependency, but that does not establish separately tested non-Mono binaries, other GPUs, platforms or engine versions.

The 0.3.1 structure release retains the validated 0.3.0 renderer and its real-GPU evidence. The restructured source passed a 35-capture playground run, the 36-case/218-capture core matrix, and a fresh addon-only consumer check; the final delivery record names the exact archive and evidence.

Source handles root/descendant/explicit meshes, transforms, inherited visibility, shared mesh/material resources, skinned poses and blend shapes. QA covers opaque occlusion, target switching/clearing, hide/free, rebind, output resolutions and resize transients. The core's 2 px style is the QA baseline; the playground uses 2.5 px. A hidden interval during bind/resize is permitted.

## Limits

- Compatibility and Mobile are unsupported. The runtime rejects TAA, XR and unsupported scaling/upscalers; use 1:1 without FSR or dynamic 3D scaling.
- Transparent targets, glass occluders, alpha cutout and custom vertex-shader deformation are outside the contract. Proxies do not copy material discard/alpha/vertex logic. Transparent geometry that does not write depth cannot occlude this effect; POST_TRANSPARENT does not manufacture glass depth.
- Multi-camera simultaneous highlighting, XR/multiview, portal selection and arbitrary MSAA combinations are not validated.
- One collection is one combined selected projection, not separately styled targets. Recollect meshes after structural changes.
- No systematic performance/VRAM stress budget, precise per-face metre-error measurement, exposure-variation comparison or exhaustive permanent GPU/shader failure injection is claimed.

[QA limits](qa-oracle-review.md) distinguish renderer output, independent geometry references and visual acceptance. Historical host-game integration results do not expand this addon contract.
