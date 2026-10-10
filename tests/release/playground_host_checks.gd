extends SceneTree
## Short host/control checks. No GPU acceptance, readbacks, or save files.
const Scene = preload("res://scene/interaction_highlight_demo.tscn")
var failures: Array[String] = []
var checks := 0
var demo: Node3D

func _init() -> void:
	call_deferred("run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func run() -> void:
	demo = Scene.instantiate()
	demo.capture_mouse_on_start = false
	demo.ray_selection_enabled = false
	demo.animate_samples = false
	root.add_child(demo)
	await process_frame
	await process_frame
	await physics_frame
	verify(demo.binding_ready, "Deferred highlighter binding completes")
	verify(demo.targets.size() == 7, "Seven authored procedural targets")
	verify(demo.targets[5].get_meta("sample_skeleton").get_bone_count() == 2, "Real two-bone sample")
	verify(demo.targets[6].get_meta("sample_blendmesh").mesh.get_blend_shape_count() == 1, "Real blendshape sample")
	verify(not demo.panel.visible and demo.preview_mode == 0, "Panel and diagnostics off by default")
	verify(demo.style.outline_width_px == 2.5 and demo.style.outline_color == Color.WHITE, "White 2.5px outline default")
	verify(demo.style.mode == 1 and demo.style.fill_color == Color.YELLOW and demo.style.fill_alpha == 0.25, "Fill off, yellow, 75 percent transparency default")
	var controls: Dictionary = demo.panel.controls
	controls["OutlineWidthSlider"].value = 7.3
	verify(is_equal_approx(demo.style.outline_width_px, 7.3) and is_equal_approx(controls["OutlineWidthSpinBox"].value, 7.3), "Width slider updates style and SpinBox")
	controls["OutlineWidthSpinBox"].value = 0.5
	verify(demo.style.outline_width_px == 0.5 and controls["OutlineWidthSlider"].value == 0.5, "Width SpinBox updates style and slider")
	controls["OutlineWidthSpinBox"].value = 99
	verify(demo.style.outline_width_px == 12.0, "Width upper limit is 12")
	controls["OutlineOpacitySlider"].value = 0
	verify(demo.style.outline_alpha == 0, "Opacity zero is exact")
	controls["OutlineOpacitySpinBox"].value = 1
	verify(demo.style.outline_alpha == 1, "Opacity one is exact")
	controls["GlowSpinBox"].value = 1
	verify(demo.style.glow_strength == 1 and controls["GlowSlider"].value == 1, "Glow synchronized")
	for hex in demo.panel.COLOR_HEX:
		controls["OutlineColor" + hex].button_pressed = true
		verify(demo.style.outline_color == Color.html(hex), "Exact outline color " + hex)
		verify(demo.style.fill_color == Color.YELLOW, "Outline palette leaves fill independent " + hex)
	controls["FillToggle"].button_pressed = true
	verify(demo.style.mode == 2, "Fill toggle enables fill plus outline")
	for hex in demo.panel.COLOR_HEX:
		controls["FillColor" + hex].button_pressed = true
		verify(demo.style.fill_color == Color.html(hex), "Exact fill color " + hex)
	controls["FillTransparencySpinBox"].value = 100
	verify(demo.style.fill_alpha == 0, "100 percent transparency means zero alpha")
	controls["FillTransparencySlider"].value = 0
	verify(demo.style.fill_alpha == 1, "Zero transparency means full alpha")
	controls["ResetButton"].pressed.emit()
	verify(demo.style.outline_width_px == 2.5 and demo.style.mode == 1 and demo.style.outline_color == Color.WHITE and demo.style.fill_color == Color.YELLOW and demo.style.fill_alpha == 0.25 and demo.style.outline_alpha == 1 and is_equal_approx(demo.style.glow_strength, 0.12), "Reset restores every demo default")
	verify(controls["OutlineColorFFFFFF"].button_pressed and controls["FillColorFFFF00"].button_pressed and controls["FillTransparencySlider"].value == 75, "Reset synchronizes palettes and transparency control")
	var handle: Node3D = demo.targets[2]
	verify(demo.target_from_collider(handle.get_node("Collision")) == handle, "Collider climbs to compound root")
	demo.camera.position = handle.position + Vector3(0, 1.35, 3)
	demo.camera.look_at(handle.position + Vector3(-0.48, 0.65, 0))
	demo.update_aim_selection()
	verify(demo.selected_target == handle, "Actual center ray selects handle solid bar")
	demo.set_panel_open(true)
	var before: Transform3D = demo.camera.transform
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(100, 100)
	demo._input(mouse)
	demo._physics_process(0.5)
	verify(demo.camera.transform == before and not demo.controls_active(), "Panel pauses movement and mouse look")
	demo.camera.look_at(demo.camera.position + Vector3(0, 3, 0.001))
	demo.update_aim_selection()
	verify(demo.selected_target == handle, "Panel retains selection while aim changes")
	controls["OutlineWidthSpinBox"].value = 4.2
	verify(is_equal_approx(demo.style.outline_width_px, 4.2) and demo.highlighter.get_debug_state().get("target_id") == handle.get_instance_id(), "Live tuning retains bound renderer target")
	demo.panel.set_diagnostics_open(true)
	verify(demo.preview_mode == 1, "Diagnostics expands with Coverage")
	demo.set_preview_mode(2)
	demo.panel.update_diagnostics(handle)
	verify(demo.preview_mode == 2 and demo.panel.diagnostics_open, "Target Depth mode is independently switchable")
	for distance in [demo.camera.near, 0.5, 4.0, 10.0, 50.0]:
		var clip: Vector4 = demo.camera.get_camera_projection() * Vector4(0, 0, -distance, 1)
		var raw_depth := (1.0 - clip.z / clip.w) * 0.5
		var reconstructed: float = demo.panel.linearize_target_depth(raw_depth)
		verify(absf(reconstructed - distance) < maxf(0.002, distance * 0.001), "Reverse-Z inverse projection reconstructs %.2fm" % distance)
	demo.set_preview_mode(0)
	verify(demo.preview_mode == 0 and not demo.panel.diagnostics_open, "Diagnostics collapses without scene mutation")
	demo.set_panel_open(false, false)
	demo.update_aim_selection()
	verify(demo.selected_target == null and demo.highlighter.get_debug_state().get("target_id") == 0, "Aim away clears actual renderer target")
	demo.camera.rotation.x = deg_to_rad(80)
	var height: float = demo.camera.position.y
	demo.move_camera(Vector2(0, -1), 0.1)
	verify(demo.camera.position.y == height, "Pitched FPS movement has no vertical drift")
	demo.set_sample_animation(false, 1.0)
	var frozen_time: float = demo.animation_time
	demo._process(0.5)
	verify(demo.animation_time == frozen_time, "Animation freeze helper remains frozen")
	print("PLAYGROUND_HOST_CHECKS checks=%d failures=%d" % [checks, failures.size()])
	demo.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
