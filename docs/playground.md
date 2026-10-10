# Playground
[简体中文](playground.zh-CN.md)

The release entry is `res://scene/interaction_highlight_demo.tscn`. Host input/UI scripts live in `res://scripts/`, the diagnostic preview shader lives in `res://shader/`, and the unchanged addon owns only the highlight runtime.

| Control | Action |
|---|---|
| WASD / mouse | Flat movement / look while mouse is captured |
| Centre crosshair | Physics ray selects the first reachable sample; misses/other geometry clear selection |
| E | Toggle settings; selected target remains active while movement and selection queries pause |
| Esc | Close settings and release the mouse |
| Click outside UI | Close settings and recapture the mouse |

Movement is a bounded free camera, not a collision-driven player controller. The ray reaches 24 metres. Seven original procedural models are box, sphere, handle with a real hole, thin rod/panel, rigid multipart mesh with artist overlay, two-bone skinned mesh, and blend-shape mesh. Bone/blend-shape samples animate by default; a foreground block demonstrates partial occlusion. Collisions are static fixture shapes rather than continuously deformed animation geometry.

The compact, scrollable panel pairs sliders with numeric inputs, independent eight-color outline/fill palettes, outline width/opacity, glow strength, fill toggle, fill transparency and reset. Changes apply live. Reset restores demo defaults: outline-only, white 2.5 px, opacity 1, glow strength 0.12/width 3, yellow fill alpha 0.25 and depth bias 0.002 m. Transparency is `100 × (1 - fill_alpha)`; 75% transparency means 0.25 opacity. There is no save/load persistence.

## Diagnostics

Diagnostics are collapsed and preview is off by default. Enabling them shows status and either Coverage (RGBA16F) or Target Depth (metres). Coverage displays R outline, G visible fill and B glow; A contains complete projection but is not displayed as the RGB preview's alpha. Target Depth converts raw reversed-Z with the camera's inverse projection to positive view-space metres and maps near/far display range from cyan to orange; dark means no target. The displayed range follows the selected target and is a visualization, not a different depth texture format.

Status uses `get_debug_state()` for ready, overlay readiness, freshness, depth/coverage frame ages and support/runtime errors. The preview reacquires `get_debug_coverage_texture()` or `get_debug_depth_texture()`, checks readiness/size and refreshes sampler binding. It does not request per-frame GPU readbacks. `request_debug_readback()` remains available for explicit tools/QA.

These public methods are stable interfaces; internal node/RID lifetimes are not promised. See [API](../addons/interaction_highlight/docs/api.md), [core defaults](../addons/interaction_highlight/docs/api.md) and [implementation](../addons/interaction_highlight/docs/technical.md).
