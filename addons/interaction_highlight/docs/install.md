# Installation
[简体中文](install.zh-CN.md)

## Fastest setup: assign camera and target

After copying the addon, create a Node3D in your scene and use the repository's `scripts/quick_start.gd` as a host-side example, or copy that script into your own `scripts/` directory. Assign your active Camera3D to `camera` and the object's root to `test_target`. Expand `highlight_style` to tune appearance, then run your own scene.

This optional host example is not a core dependency and adds no input, crosshair or settings panel. After initialization, call `show_target(node)` to switch selection and `clear_highlight()` to clear it. Do not select your entire world root.

## Write your own host script

The approach below does not use the quick-start helper and suits an existing interaction system.

Copy only the complete `addons/interaction_highlight/` directory into the same path in your Godot project. Keep its shaders, resources, scenes, license and `.uid` files. The root playground, tests and packaging tools are optional; no editor plugin activation, autoload or host assets are required.

Use Godot 4.7 Forward+, 1:1 3D rendering, TAA off and bilinear/nearest scaling without an upscaler. Start with MSAA disabled, matching the demo/QA baseline. The code is pure GDScript; the tested engine binary is Windows 4.7 stable Mono on RTX 5060 Laptop (Vulkan). Non-Mono binaries and other platforms/GPUs have not been separately validated.

Attach this script to a parent with children named `Camera3D` and `Target`. Defer binding until the parent's ready stack finishes: binding creates an auxiliary viewport under the camera's viewport.

```gdscript
extends Node3D
const Renderer = preload("res://addons/interaction_highlight/highlight_renderer.gd")
const Style = preload("res://addons/interaction_highlight/highlight_style.gd")

var highlighter: Node
var bound := false

func _ready() -> void:
    highlighter = Renderer.new()
    add_child(highlighter)
    call_deferred("_bind_highlighter")

func _bind_highlighter() -> void:
    if not is_inside_tree() or not $Camera3D.is_inside_tree():
        return
    highlighter.bind_camera($Camera3D)
    highlighter.apply_style(Style.new())
    highlighter.set_target($Target)
    bound = true

func replace_selection(next_target: Node3D) -> void:
    if bound:
        highlighter.set_target(next_target) # null also clears the selection

func use_explicit_meshes(meshes: Array[MeshInstance3D]) -> void:
    if bound:
        highlighter.set_meshes(meshes) # replaces the whole selection

func clear_selection() -> void:
    if bound:
        highlighter.clear_target()
```

The host supplies ray selection, input, range rules and menu policy. For a gameplay menu that disables interaction, call `clear_target()` when it opens and reacquire a target when it closes. A tuning panel may deliberately retain the selection, as the release playground does. Merely stopping ray queries leaves the last target selected.

To switch cameras, first put the new camera in the tree, make it current as appropriate, then call `bind_camera(new_camera)`. Use `bind_camera(null)` to release the runtime. Freeing the renderer also tears it down; target exit clears selection and camera exit clears selection and runtime. A new binding or resize can temporarily suppress the overlay while textures become ready; no exact recovery-frame guarantee is made.

The complete demo belongs to the repository root at `res://scene/interaction_highlight_demo.tscn`; it is not part of the copy-only addon. When integrating the addon, use the API above with your own input and selection logic.

See [API and defaults](api.md), [implementation](technical.md) and [support](support.md).
