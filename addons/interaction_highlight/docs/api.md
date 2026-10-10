# Public API
[简体中文](api.zh-CN.md)

`InteractionHighlighter` extends Node; `HighlightStyle` extends Resource. Use explicit preloads as in [installation](install.md). Bind after both nodes enter the tree and the parent's ready stack finishes.

| Method | Behavior |
|---|---|
| `bind_camera(camera: Camera3D)` | One explicit camera; null unbinds. Rebinding rebuilds the runtime, retaining selected source meshes unless the old camera exits. |
| `set_target(target: Node3D)` | Replaces selection with the root mesh, if any, plus descendant MeshInstance3D nodes; null clears it. |
| `set_meshes(meshes: Array[MeshInstance3D])` | Replaces selection with an explicit set; ignores invalid, duplicate or mesh-less entries and disconnects the root target. |
| `apply_style(value: HighlightStyle)` | Retains the resource reference; null creates a default style. |
| `clear_target()` | Clears sources/proxies, invalidates coverage and hides the overlay; repeatable. |

A target is scanned at submission, not every frame. Calling `set_target()` again with the same valid root returns early. For added/removed children, submit the complete mesh set or clear and resubmit the root. Existing mesh transforms, visibility through ancestors, camera layer visibility, mesh resource replacements, blend shapes and final skeleton poses are synchronized. Topology changes need deliberate resubmission.

Styles are shared by reference. Create or duplicate a resource for independent settings. Mutating a style is picked up each frame; `apply_style()` also updates overlay parameters immediately.

## Core field defaults

| Field | Default | Meaning / range |
|---|---|---|
| `mode` | `1` | 1 outline; 2 visible fill + same outline |
| `outline_color` | `Color.WHITE` | Color alpha multiplies outline/glow opacity |
| `outline_width_px` | `2.0` | Output-pixel radius, clamped 0.5–12 |
| `outline_alpha` | `1.0` | Opacity, clamped 0–1 |
| `glow_strength` | `0.12` | Clamped 0–1; zero disables glow width |
| `glow_width_px` | `3.0` | Additional output-pixel extent, clamped 0–16 |
| `fill_color` | `Color(1.0, 0.85, 0.4, 1.0)` | Pale gold; color alpha multiplies fill opacity |
| `fill_alpha` | `0.25` | Opacity, clamped 0–1: 75% transparent |
| `depth_bias_m` | `0.002` | Nonnegative view-depth tolerance in metres; inspector range 0–0.05 |

Use finite values. The depth bias has no runtime upper clamp. Width describes the screen-space antialiased radius, not world-space shell thickness. Mode 0 is not a documented style mode: turn the effect off with `clear_target()`.

The root playground deliberately overrides width to 2.5 and fill to `Color.YELLOW`; it starts with a white opaque outline and fill alpha 0.25 (75% transparency). These are demo settings, not changed core defaults. `overlay_layer` on the renderer defaults to 1; place host UI above it.

## Stable public diagnostics

| Method | Output |
|---|---|
| `get_debug_state()` | Dictionary: activity/readiness, errors, raster sizes, freshness/frame ages, callback counts, proxy/skeleton counts, target ID and channel description. |
| `get_debug_coverage_texture()` | Current Texture2DRD wrapper, or null when unbound. |
| `get_debug_depth_texture()` | Current target-depth Texture2DRD wrapper, or null when unbound. |
| `request_debug_readback(kind, callback)` | Explicit GPU readback; callback is deferred to the main thread. Kinds: `depth`, `scene_depth`, `coverage`. |

Keep these diagnostic methods as public API. Getters do not read back GPU memory. Wrappers can be replaced on resize/rebind; reacquire them rather than caching them permanently. Internal nodes, dictionary expansion and RID identity/lifetime are not stable public contracts. Never free diagnostic RIDs.

Successful readback payloads contain `kind`, `size`, `format`, `data`; an invalid/unbound request also provides `error`, while disposal may yield empty data. Validate size, format and byte length before decoding. Coverage is RGBA16F; depths are R32F reversed-Z, not linear metres. Readback can stall and is for tools/QA, not the normal per-frame display.

`ready` describes data; `overlay_ready` describes presentation gating. Neither alone proves a screenshot contains the intended effect. Inspect nonzero coverage and actual pixels. See [technical details](technical.md).
