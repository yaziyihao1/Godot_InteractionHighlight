# Rendering implementation
[简体中文](technical.zh-CN.md)

This description follows the six core source files. It is a depth-based screen-space effect with a separate canvas overlay.

1. `highlight_renderer.gd` creates a private World3D/SubViewport with mesh proxies and a camera matching the bound camera's transform/projection. Proxies share geometry and skin, use an opaque depth-only-purpose override, disable shadows/GI, and synchronize visibility, blend shapes and final skeleton poses. Source materials and artist material overlays are not edited. The private world's layer 1 does not reserve a host scene layer.
2. `highlight_effect.gd` requests resolved depth. The auxiliary `POST_OPAQUE` callback copies its real depth layer to an R32F storage texture. It is raw reversed-Z depth, not ALBEDO-encoded color, and does not pass through exposure, glow or tonemapping. Both effects check that callbacks belong to their expected viewport render target.
3. The main camera's `POST_TRANSPARENT` callback samples target depth and main resolved depth. `gpu_state.gd` uses embedded compute shaders: a horizontal support prepass prunes empty neighborhoods, then a coverage pass writes RGBA16F. It also copies scene depth to R32F for explicit QA readback.
4. `overlay.gdshader` samples numeric coverage with nearest filtering and no color-space conversion on that sampler. A ColorRect in a CanvasLayer uses `blend_mix`, combining outline/glow and optional visible fill. It samples no scene color and does not redraw the background. This is not an expanded mesh/shader shell.

## Occlusion and channels

For a pixel with target depth, the full target projection T(p) suppresses outline and glow even when that surface is occluded. Only visible fill is written there. This avoids treating the visible-mask boundary made by an occluder as an internal outline.

Outside T, candidate target seeds q within the outline/glow radius must pass two comparisons: target depth at q against scene depth at q (visible seed), and against scene depth at destination p (visible destination). The inverse render projection reconstructs positive view-space depth in metres, `-view.z/view.w`; the tolerance is `depth_bias_m`. These are view depths, not Euclidean ray distances. A reversed-Z value of zero is treated as no surface/infinite distance.

| RGBA16F channel | Meaning |
|---|---|
| R | Exterior outline coverage |
| G | Visible target fill coverage |
| B | Exterior glow coverage |
| A | Complete target projection, including occluded surfaces |

A is diagnostic geometry coverage, not the final canvas opacity. The overlay computes its own opacity from R/G/B, style alpha and color alpha. Mode 1 ignores G; mode 2 uses G with the same R/B. True projected holes can receive exterior contours; overlapping meshes contribute a combined projection, so material boundaries and triangle seams do not create lines.

The outline uses `clamp(width + 0.5 - distance_px, 0, 1)`; glow falls off quadratically outside that radius. Width is measured in output pixels and the search radius grows with outline plus glow. Large radii/resolutions increase cost; no universal frame-time or VRAM budget is established.

## Frame and resource lifecycle

Capture and compose share a mutex-protected state. Target changes increment a generation; compose requires matching generation and capture in the current drawn frame. Snapshot freshness allows ages 0–1 frames because main-thread setup can precede this frame's callbacks. The overlay additionally checks callback availability, all raster sizes, wrapper attachment, selected meshes and support errors.

Resize temporarily hides the overlay, detaches old wrappers, creates fresh Texture2DRD wrappers and explicitly rebinds the material sampler. Canvas size uses the viewport's logical visible area while coverage uses the physical 3D raster. Native window sizing is used where applicable to anticipate a resize. A brief hidden interval is allowed; recovery timing depends on rendering readiness.

Binding appends the main effect to a new camera compositor, retaining existing effective camera/world effects. The world-compositor lookup uses an internal scenario group in Godot 4.7, an engine-version sensitivity. Teardown restores the original camera compositor only if the installed compositor is still ours, so later host changes survive. It disables callbacks/auxiliary updates, hides proxies, clears wrappers, queues nodes for deletion and disposes GPU resources on the render thread.

See [support boundaries](support.md), [diagnostic API](api.md) and [QA evidence limits](qa-oracle-review.md).
