extends SceneTree
## Real-window QA of the standalone host, separate from rendering-core matrix.
var output := OS.get_user_data_dir().path_join("playground_qa")
var demo: Node3D
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks.append({"passed": condition, "check": label})
	if not condition:
		failures.append(label)
		push_error(label)

func settle(frames: int = 12) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	var image := root.get_texture().get_image()
	check(image.save_png(output.path_join(label + ".png")) == OK, "Save " + label)
	captures.append({"case": label, "size": [image.get_width(), image.get_height()], "panel": demo.panel.visible,
		"selection": demo.selected_target.name if is_instance_valid(demo.selected_target) else "none",
		"width": demo.style.outline_width_px, "mode": demo.style.mode, "preview": demo.preview_mode,
		"preview_rect": preview_rect_pixels(image)})

func preview_rect_pixels(image: Image) -> Array:
	var bounds: Rect2 = demo.panel.controls["DebugPreview"].get_global_rect()
	var ratio: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	return [bounds.position.x * ratio.x, bounds.position.y * ratio.y,
		bounds.size.x * ratio.x, bounds.size.y * ratio.y]

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Standalone visual acceptance needs a real GPU window")
		quit(2)
		return
	change_scene_to_file("res://scene/interaction_highlight_demo.tscn")
	await scene_changed
	await settle(20)
	demo = current_scene as Node3D
	demo.ray_selection_enabled = false
	demo.set_sample_animation(false, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(demo.targets.size() == 7, "Seven simple-to-complex samples")
	check(demo.targets[5].get_meta("sample_skeleton").get_bone_count() == 2, "Actual two-bone model")
	check(demo.targets[6].get_meta("sample_blendmesh").mesh.get_blend_shape_count() == 1, "Actual BlendShape model")
	check(not demo.panel.visible and demo.preview_mode == 0, "Small panel and diagnostics initially hidden")
	check(is_equal_approx(float(demo.style.outline_width_px), 2.5) and demo.style.outline_color == Color.WHITE and demo.style.mode == 1, "Demo defaults distinct from core defaults")
	await capture("initial_playground")
	for index in range(demo.targets.size()):
		var target: Node3D = demo.targets[index]
		demo.camera.position = target.position + Vector3(0, 1.35, 3.0)
		demo.camera.look_at(target.position + Vector3(0, .65, 0))
		demo.select_target(null)
		await capture("sample_%d_off" % index)
		demo.style.mode = 1
		demo.select_target(target)
		await capture("sample_%d_outline" % index)
		demo.style.mode = 2
		demo.highlighter.apply_style(demo.style)
		await capture("sample_%d_fill" % index)
		demo.select_target(null)
		await capture("sample_%d_clear" % index)
	# Aim at the real handle's left solid bar, not its hole.
	var handle: Node3D = demo.targets[2]
	demo.camera.position = handle.position + Vector3(0, 1.35, 3)
	demo.camera.look_at(handle.position + Vector3(-.48, .65, 0))
	await physics_frame
	demo.update_aim_selection()
	check(demo.selected_target == handle, "Actual center ray finds compound target")
	demo.style.mode = 1
	demo.set_panel_open(false)
	await press_key(KEY_E)
	check(demo.panel.visible and not demo.controls_active() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E opens panel and pauses camera controls")
	var held: Node3D = demo.selected_target
	var position_before: Vector3 = demo.camera.position
	var rotation_before: Vector3 = demo.camera.rotation
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, 30)
	Input.parse_input_event(motion)
	demo.camera.look_at(demo.camera.position + Vector3(0, 3, .001))
	demo.update_aim_selection()
	check(demo.selected_target == held, "Panel preserves selection despite changed aim")
	demo.camera.rotation = rotation_before
	check(demo.camera.position == position_before, "Panel does not move camera")
	await test_panel_controls()
	await capture("panel_live_tuning")
	var focused := root.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	demo.panel.set_diagnostics_open(true)
	demo.set_preview_mode(1)
	await settle()
	demo.panel.controls["SettingsScroll"].ensure_control_visible(demo.panel.controls["DebugPreview"])
	await settle()
	check(demo.panel.controls["SettingsScroll"].get_global_rect().encloses(demo.panel.controls["DebugPreview"].get_global_rect()), "Diagnostic preview is actually inside the scroll window")
	await capture("diagnostic_coverage")
	demo.set_preview_mode(2)
	await capture("diagnostic_depth")
	var pending := {"done": false, "payload": {}}
	demo.highlighter.request_debug_readback("depth", func(payload: Dictionary) -> void:
		pending.payload = payload
		pending.done = true)
	for i in range(120):
		if pending.done:
			break
		await process_frame
	check(pending.done, "Explicit depth readback remains available")
	if pending.done:
		var payload: Dictionary = pending.payload
		var data: PackedByteArray = payload.data
		var image_size: Vector2i = payload.size
		var raw: float = data.decode_float((int(image_size.y / 2) * image_size.x + int(image_size.x / 2)) * 4)
		var meters: float = demo.panel.linearize_target_depth(raw)
		check(raw > 0 and meters > 2.5 and meters < 3.8, "Preview linearizes real target depth to meters")
	demo.set_preview_mode(0)
	DisplayServer.window_set_size(Vector2i(960, 600))
	await capture("panel_960x600")
	var bounds: Rect2 = demo.panel.get_global_rect()
	check(root.get_visible_rect().encloses(bounds), "Panel stays in viewport after resize")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await press_key(KEY_E)
	check(not demo.panel.visible and demo.controls_active(), "E closes panel and resumes controls")
	demo.camera.look_at(demo.camera.position + Vector3(0, 3, .001))
	demo.update_aim_selection()
	check(demo.selected_target == null, "Aiming away clears highlighter")
	await capture("cleared_after_panel")
	await press_key(KEY_ESCAPE)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not demo.panel.visible, "Esc releases pointer")
	var report := {"engine": Engine.get_version_info(), "adapter": RenderingServer.get_video_adapter_name(), "checks": checks,
		"failures": failures, "captures": captures, "headless": false}
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PLAYGROUND_QA_COMPLETE captures=", captures.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 3)

func test_panel_controls() -> void:
	var controls: Dictionary = demo.panel.controls
	controls["OutlineWidthSpinBox"].value = 8.0
	check(controls["OutlineWidthSlider"].value == 8.0 and demo.style.outline_width_px == 8.0, "Width numeric input changes slider and style")
	controls["OutlineWidthSlider"].value = 5.0
	check(controls["OutlineWidthSpinBox"].value == 5.0 and demo.style.outline_width_px == 5.0, "Width slider changes numeric input and style")
	controls["OutlineColor8000FF"].button_pressed = true
	controls["FillColor00FFFF"].button_pressed = true
	check(demo.style.outline_color == Color.html("8000FF") and demo.style.fill_color == Color.CYAN, "Independent edge and fill palettes")
	controls["FillToggle"].button_pressed = true
	controls["FillTransparencySpinBox"].value = 37.0
	check(demo.style.mode == 2 and is_equal_approx(float(demo.style.fill_alpha), .63) and controls["FillTransparencySlider"].value == 37.0, "Fill switch and inverse transparency")
	controls["OutlineOpacitySlider"].value = .85
	controls["GlowSpinBox"].value = .2
	check(is_equal_approx(float(demo.style.outline_alpha), .85) and is_equal_approx(float(demo.style.glow_strength), .2), "Opacity and glow live tuning")
	await capture("panel_custom_values")
	controls["ResetButton"].pressed.emit()
	check(demo.style.mode == 1 and demo.style.outline_width_px == 2.5 and demo.style.outline_color == Color.WHITE and demo.style.fill_color == Color.YELLOW and demo.style.fill_alpha == .25 and demo.preview_mode == 0, "Reset restores demo defaults and disables diagnostics")
