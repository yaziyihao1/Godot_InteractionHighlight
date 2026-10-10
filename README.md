# Godot Interaction Highlight

[简体中文](README.zh-CN.md) · v0.3.1 · [MIT](LICENSE)

Add **outline only** or **outline + translucent fill** to 3D objects without replacing their materials.

## 1. Try the complete demo

1. Extract the **GodotInteractionHighlight ZIP**. Do not open files inside the archive.
2. In the Godot 4.7 project manager, choose **Import**, select the extracted `project.godot`, and open the project.
3. Wait for import. Open `scene/interaction_highlight_demo.tscn` and press **F6**, or press **F5** for the default demo.
4. Move with WASD, look with the mouse, and aim at an object.
5. Press **E** to tune width, outline/fill colors and transparency. The selected object stays highlighted while movement and ray selection pause.
6. Press E again to resume. Esc closes the panel or releases the mouse; click the scene to recapture it.

Seven original procedural objects include holes, multiple meshes, bones and a BlendShape. Demo settings last only for the current run; they do not save or change any host-game settings.

![Actual GPU capture: independent outline and fill controls](docs/images/live-tuning.png)

## 2. Install in your own Godot project

Installing the module means **copying a folder**, not importing another project in the project manager.

### Copy the addon

Copy the complete extracted `addons/interaction_highlight` folder into **your project's root**, where your own `project.godot` lives:

```text
your-project/
├── project.godot                 ← keep your own file
└── addons/
    └── interaction_highlight/
        ├── highlight_renderer.gd
        ├── highlight_style.gd
        ├── ...
        └── examples/
            └── quick_start.gd
```

Keep all addon files, including `.uid` files. If you already have `addons`, put only `interaction_highlight` inside it. **Do not overwrite your project.godot or copy the release's root examples/tests. No editor-plugin activation is needed.**

### Check project requirements

- Godot **4.7, Forward+**, not Mobile or Compatibility.
- 3D render scale **1.0**, with TAA, FSR and XR disabled. Start with MSAA disabled.
- Initially test an ordinary opaque `MeshInstance3D` that your camera can see.

### Highlight one object without writing code

1. Open your own 3D scene.
2. Add a new **Node3D** under the scene root, named `HighlightController`. Do not replace existing world/player scripts.
3. Attach `res://scripts/quick_start.gd` to this new node. This is a host-side example from the repository; when copying into your own project, copy it into your own `scripts/`, or use the code below directly.
4. In its Inspector, assign:
   - **Camera / camera**: drag in the active `Camera3D`.
   - **Test Target / test_target**: drag in the object's root node.
   - **Highlight Style / highlight_style**: expand this resource to change appearance.
5. Run **your own scene**. The test object should show a continuous white outline.

The target may be a `MeshInstance3D` or a `Node3D` containing several meshes. **Do not select the entire world root**: its descendant meshes would all be included.

This is a fixed-target test. It does not install a crosshair, mouse controls or the E panel; those belong to the complete demo, not the rendering core.

## 3. Change width, color and fill

Select `HighlightController` and expand `highlight_style` in the Inspector.

| Change | Field | Value |
|---|---|---|
| Outline / filled outline | `mode` | `1` outline only; `2` outline + fill |
| Outline width | `outline_width_px` | 0.5–12 pixels, e.g. `5.0` |
| Outline color | `outline_color` | Use the color picker |
| Outline opacity | `outline_alpha` | 0–1; 1 is opaque |
| Glow strength | `glow_strength` | 0–1; 0 disables glow |
| Independent fill color | `fill_color` | Use the color picker |
| Fill opacity | `fill_alpha` | 0–1; `0.25` means **75% transparent** |

Changing fill color alone does not enable fill: set `mode = 2`. To disable the whole effect, clear the target; do not use mode 0.

Inspector settings are saved with the scene. You can also save the style as a reusable `.tres`. Controllers using the same resource share settings; create separate resources or make them unique for independent settings.

Core defaults are white **2px**, fill disabled. The full demo uses **2.5px** and a yellow fill preset. These are separate settings.

You may also change settings in code after initialization:

```gdscript
var controller = $HighlightController
controller.highlight_style.outline_width_px = 5.0
controller.highlight_style.outline_color = Color.RED
controller.highlight_style.mode = 2
controller.highlight_style.fill_color = Color.YELLOW
controller.highlight_style.fill_alpha = 0.25 # 75% transparent
controller.highlighter.apply_style(controller.highlight_style)
```

## 4. Connect your existing interaction system

Once the controller is initialized, your ray or interaction logic calls:

```gdscript
# Aim at an object: pass the root of that interactable.
$HighlightController.show_target(interactable_root)

# Calling show_target again replaces the previous target.
# Aim away, or open a menu that disables interaction:
$HighlightController.clear_highlight()
```

Use one controller for one selected target collection and one camera, not one controller per object. The addon draws highlights; **your game decides what is selected**.

For integration without `quick_start.gd`, explicit mesh collections, camera changes and lifecycle handling, see the [complete integration code](addons/interaction_highlight/docs/install.md).

## 5. Troubleshooting

1. Is the copied path exactly `res://addons/interaction_highlight/`?
2. Are both `camera` and `test_target` assigned, and is this your active camera?
3. Does the target contain a nonempty, visible `MeshInstance3D`, without complete opaque occlusion?
4. Are you using Forward+, scale 1.0 and no TAA/FSR/XR?
5. Is outline opacity above 0 and width between 0.5 and 12?
6. Check the Godot debugger. After initialization, print:
   ```gdscript
   print($HighlightController.highlighter.get_debug_state())
   ```

The complete demo's E panel has folded diagnostics for status/errors, coverage and linearized depth. [Diagnostic API](addons/interaction_highlight/docs/api.md).

## 6. Project layout

```text
scene/                         # directly runnable demo scenes
scripts/                       # demo, quick-start and host scripts
shader/                        # demo diagnostic preview shader
addons/interaction_highlight/  # portable runtime-only addon
tests/                         # GPU regression and package audits
docs/                          # technical, integration and verification docs
```

Import the whole repository when you want to run the demo. Copy only `addons/interaction_highlight/` when integrating the runtime into another game; do not copy `scene/`, `scripts/` or `tests/`.

## 7. Reference and development

These links are optional for basic use:

- [Installation and lifecycle](addons/interaction_highlight/docs/install.md)
- [All fields and public API](addons/interaction_highlight/docs/api.md)
- [Technical explanation: depth, occlusion, pixel contours, canvas blending](addons/interaction_highlight/docs/technical.md)
- [Support and limitations](addons/interaction_highlight/docs/support.md)
- [Complete demo guide](docs/playground.md)
- [Testing and packaging](docs/testing.md) · [Contributing/modification points](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)
- [v0.3 verification](docs/release-verification.md)

Actually tested: Windows, Godot 4.7 stable Mono, Vulkan Forward+, RTX 5060 Laptop. The code is pure GDScript, but non-Mono binaries and other platforms/GPUs have not been separately tested. Transparent occlusion, alpha cutout, custom vertex deformation and simultaneous multi-camera highlights are outside the contract.

MIT permits modification and redistribution; retain [LICENSE](LICENSE). No original host game, C#, MCP, personal saves or third-party models are included.
