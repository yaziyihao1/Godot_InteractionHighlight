# Standalone playground host

For installing highlights in your own scene without this playground, follow the
[quick-start steps](../README.md#2-install-in-your-own-godot-project) and attach
`res://scripts/quick_start.gd` to a new Node3D.
Assign camera/target and expand its style in the Inspector. The complete
playground below is optional and is not a dependency of that helper.

Open `res://scene/interaction_highlight_demo.tscn`. Seven procedural samples come directly from
the frozen addon factory: box, sphere, through-hole handle, thin geometry, rigid
compound, actual two-bone skinned mesh, and actual BlendShape mesh. The ground and
partial sphere occluder are neutral, non-selectable colliders.

WASD moves horizontally; mouse looks with a clamped pitch. E opens/closes the
small top-right settings panel. While open, movement and aim selection pause but
the selected object's highlight continues updating. Escape closes and releases
the pointer. Left-click outside the panel closes it and captures the pointer.
The scrollable panel stays readable in physical pixels at 960×600. No settings
or saves are written by the scene.

## QA interface

Root variables: `camera`, `highlighter`, `style`, `targets`, `panel`,
`selected_target`, `preview_mode`, `binding_ready`, `animate_samples`,
`ray_selection_enabled`, and `capture_mouse_on_start`. Set the last three before
adding an instance to the tree to prevent animation/input during automated QA.
Wait for `binding_ready` after instantiation. Camera binding is deferred until
the root finishes readiness; this avoids viewport sibling creation while the
parent is busy setting up children.

Root methods:

- `set_sample_animation(enabled, time_seconds=0.0)`: freeze/update both deformation samples.
- `select_target(root_or_null)`: explicit selection or clear.
- `target_from_collider(node)`: climb collider ancestors to a known target.
- `update_aim_selection()`: center ray; no-op while the panel is open.
- `set_panel_open(open, capture_on_close=true)`: preserves selection; false/false releases pointer.
- `controls_active()`: whether the pointer is captured and panel closed.
- `move_camera(axes, delta)`: normalized horizontal motion; no pitch drift.
- `set_preview_mode(value)`: 0 off, 1 Coverage, 2 Target Depth.

`panel.controls` keys are also node names:

| Field | Slider | Numeric control |
| --- | --- | --- |
| Width (.5–12, step .1) | `OutlineWidthSlider` | `OutlineWidthSpinBox` |
| Outline opacity (0–1) | `OutlineOpacitySlider` | `OutlineOpacitySpinBox` |
| Glow (0–1) | `GlowSlider` | `GlowSpinBox` |
| Fill transparency (0–100, inverse alpha) | `FillTransparencySlider` | `FillTransparencySpinBox` |

Other keys: `FillToggle`, `ResetButton`, `CloseButton`, `SettingsScroll`,
`DiagnosticsToggle`, `PreviewMode`, `DebugStatus`, `DebugPreview`, `PreviewLegend`.
Color keys are `OutlineColor<HEX>` and `FillColor<HEX>`, for exactly `FFFFFF`,
`FF0000`, `FF8000`, `FFFF00`, `00FF00`, `00FFFF`, `0000FF`, `8000FF`.
Assign Range `.value` or Button `.button_pressed` to exercise real signals.

Panel helpers: `reset_defaults()`, `set_diagnostics_open(bool)`,
`set_preview_mode(int)`, `update_diagnostics(target=null)`,
`linearize_target_depth(raw_depth, uv=Vector2(.5,.5))`.

The diagnostic shader samples only public debug textures. Coverage displays
RGBA16F's R outline / G visible fill / B glow. Depth uses the camera's inverse CPU
projection after converting reverse-Z to CPU NDC with `1 - 2 * depth`. This
undoes the engine's [depth correction](https://github.com/godotengine/godot/blob/4.7/core/math/projection.cpp#L733).
Its cyan-to-orange meter range follows selected target depth ±2m, rather than
mapping the whole camera far plane. Empty/stale/unavailable textures stay dark.
Renderer readiness, freshness, capture/coverage frame ages and all public error
fields appear in the diagnostic text. The preview never replaces scene materials.

## Bounded verification

`--headless --check-only --script res://scripts/interaction_highlight_demo.gd` checks parsing.
`--headless --script res://tests/release/playground_host_checks.gd` checks host controls,
real ray selection, selection retention/clearing, sample structure, and numerical
depth reconstruction. These short tests do not claim GPU visual acceptance;
the main release QA owns the real GPU checks and matrix. Direct any engine
diagnostic log to `examples/` when validating within this bounded write scope.
