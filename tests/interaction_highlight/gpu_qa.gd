extends "res://scripts/legacy_demo.gd"
const Sentinel = preload("res://tests/interaction_highlight/compositor_sentinel.gd")
var output := OS.get_user_data_dir().path_join("gpu_qa")
var matrix := false
var focus := false
var records: Array[Dictionary] = []
var sentinel: CompositorEffect
var original_compositor: Compositor
var original_materials: Array[Dictionary] = []
var material_failures: Array[String] = []
var material_check_count := 0
var compositor_restored := false
var fixture_checks: Array[Dictionary] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--matrix":
			matrix = true
		if arg == "--focus":
			focus = true
	if DisplayServer.get_name() == "headless":
		push_error("GPU visual QA refuses headless execution")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	await get_tree().process_frame
	animate_samples = false
	build_demo()
	ui.hide()
	area.set_fixed_pose(0.0)
	for target in targets:
		var meshes := Factory.get_meshes(target)
		fixture_checks.append({"kind": target.get_meta("sample_kind"), "plain_root": target.get_script() == null, "static_body": target.get_node_or_null("Collision") is StaticBody3D, "meshes": meshes.size(), "bones": (target.get_meta("sample_skeleton") as Skeleton3D).get_bone_count() if target.has_meta("sample_skeleton") else 0})
	highlighter.bind_camera(null)
	sentinel = Sentinel.new()
	sentinel.expected_target = RenderingServer.viewport_get_render_target(get_viewport().get_viewport_rid())
	original_compositor = Compositor.new()
	original_compositor.compositor_effects = [sentinel]
	camera.compositor = original_compositor
	highlighter.bind_camera(camera)
	selected = 2
	camera.position = Vector3(2.8, 2.0, 4.5)
	camera.look_at(targets[selected].global_position + Vector3(0, 0.6, 0))
	await capture_case("smoke_handle", true)
	if focus:
		await run_focus()
	if matrix:
		await run_matrix()
	check_materials()
	var report := {"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(), "headless": false, "matrix": matrix, "taa": get_viewport().use_taa, "scaling": get_viewport().scaling_3d_scale, "captures": records, "fixtures": fixture_checks, "material_checks": {"checked": material_check_count, "failures": material_failures}, "compositor_retained": camera.compositor != null and camera.compositor.compositor_effects.has(sentinel), "compositor_restored_on_rebind": compositor_restored, "sentinel_callbacks": sentinel.callback_count}
	var canvas_size := get_tree().root.content_scale_size
	report["logical_canvas"] = [canvas_size.x, canvas_size.y]
	report["canvas_items"] = get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if FileAccess.file_exists("res://stage_core_manifest.json"):
		report["core_stage"] = JSON.parse_string(FileAccess.get_file_as_string("res://stage_core_manifest.json").trim_prefix("\ufeff"))
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	print("GPU_QA_ARTIFACTS: ", output, " capture_count=", records.size())
	get_tree().quit()

func run_focus() -> void:
	for index in [3, 5]:
		selected = index
		camera.position = targets[index].global_position + Vector3(1.8, 1.8, 4.4)
		camera.look_at(targets[index].global_position + Vector3(0, 0.6, 0))
		await capture_case("type_" + Factory.KINDS[index])
		if index == 5:
			for angle in [0.65, -0.65]:
				area.set_fixed_pose(angle)
				await capture_case("skinned_pose_1" if angle > 0 else "skinned_pose_2")
			area.set_fixed_pose(0.0)

func settle(frame_count: int = 10) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func save_capture(case_name: String, phase: String, settle_frames: int = 10) -> void:
	await settle(settle_frames)
	var img := get_viewport().get_texture().get_image()
	var path := output.path_join(case_name + "_" + phase + ".png")
	var err := img.save_png(path)
	if err != OK:
		push_error("Cannot save GPU image: " + path)
		get_tree().quit(3)
	var debug: Dictionary = highlighter.get_debug_state()
	debug.erase("coverage_rid")
	debug.erase("depth_rid")
	var record := {"case": case_name, "phase": phase, "path": path, "width": img.get_width(), "height": img.get_height(), "visible_rect": str(get_viewport().get_visible_rect()), "window_size": str(DisplayServer.window_get_size()), "debug": debug, "target": targets[selected].name if is_instance_valid(targets[selected]) else "freed"}
	if is_instance_valid(targets[selected]):
		var target_transform: Transform3D = targets[selected].global_transform
		var transform_columns: Array = []
		for column in [target_transform.basis.x, target_transform.basis.y, target_transform.basis.z, target_transform.origin]:
			transform_columns.append([column.x, column.y, column.z])
		record["target_transform"] = transform_columns
	record["frame_drawn"] = Engine.get_frames_drawn()
	var logical_size := get_viewport().get_visible_rect().size
	var inverse := camera.get_camera_projection().inverse()
	var inverse_columns: Array = []
	for column in [inverse.x, inverse.y, inverse.z, inverse.w]:
		inverse_columns.append([column.x, column.y, column.z, column.w])
	var rays: Array = []
	for point in [Vector2.ZERO, Vector2(logical_size.x, 0), Vector2(0, logical_size.y)]:
		var world_point: Vector3 = camera.project_position(point, 1.0)
		rays.append([world_point.x, world_point.y, world_point.z])
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	record["camera_oracle"] = {"origin": [origin.x, origin.y, origin.z], "forward": [forward.x, forward.y, forward.z], "depth1_corner_world": rays, "inverse_projection_columns": inverse_columns, "near": camera.near, "far": camera.far, "ground_y": area.global_position.y}
	record["main_buffers"] = sentinel.last_buffers.duplicate()
	record["installed_effects"] = camera.compositor.compositor_effects.size() if camera.compositor != null else 0
	var wrapper: Texture2DRD = highlighter.get_debug_coverage_texture()
	if wrapper != null:
		record["texture_wrapper"] = {"rd_rid": str(wrapper.texture_rd_rid), "render_rid": str(wrapper.get_rid()), "size": str(wrapper.get_size())}
	if phase in ["outline", "fill"]:
		for kind in (["coverage", "depth"] if phase == "outline" else ["coverage"]):
			var pending := {"done": false, "payload": {}}
			highlighter.request_debug_readback(kind, func(payload: Dictionary) -> void:
				pending.payload = payload
				pending.done = true)
			for _frame in range(120):
				if pending.done:
					break
				await get_tree().process_frame
			if pending.done:
				var payload: Dictionary = pending.payload
				var binary_path := output.path_join(case_name + "_" + phase + "_" + kind + ".bin")
				var binary := FileAccess.open(binary_path, FileAccess.WRITE)
				if binary:
					binary.store_buffer(payload.data)
				record[kind] = {"path": binary_path, "size": [payload.size.x, payload.size.y], "format": payload.get("format", ""), "bytes": payload.data.size(), "error": payload.get("error", "")}
			else:
				record[kind] = {"error": "Readback timeout"}
	records.append(record)

func remember_materials() -> void:
	original_materials.clear()
	for mesh in find_children("*", "MeshInstance3D", true, false):
		original_materials.append({"mesh": mesh, "overlay": mesh.material_overlay, "override": mesh.material_override, "resource": mesh.mesh, "surfaces": _surface_materials(mesh), "fingerprint": _material_fingerprint(mesh)})

func _resource_fingerprint(resource: Resource) -> String:
	if resource == null:
		return "null"
	var fields: Array[String] = []
	for property in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			fields.append(str(property.name) + "=" + var_to_str(resource.get(property.name)))
	if resource is ShaderMaterial and resource.shader != null:
		fields.append(resource.shader.code)
	return "\n".join(fields)

func _material_fingerprint(mesh: MeshInstance3D) -> String:
	var fields: Array[String] = [_resource_fingerprint(mesh.material_override), _resource_fingerprint(mesh.material_overlay)]
	for i in range(mesh.mesh.get_surface_count()):
		fields.append(_resource_fingerprint(mesh.mesh.surface_get_material(i)))
		fields.append(_resource_fingerprint(mesh.get_surface_override_material(i)))
	return "\n".join(fields)

func _surface_materials(mesh: MeshInstance3D) -> Array:
	var result: Array = []
	for i in range(mesh.mesh.get_surface_count()):
		result.append([mesh.mesh.surface_get_material(i), mesh.get_surface_override_material(i)])
	return result

func check_materials() -> Dictionary:
	var failures: Array[String] = []
	for entry in original_materials:
		if not is_instance_valid(entry.mesh):
			continue
		material_check_count += 1
		if entry.mesh.material_overlay != entry.overlay or entry.mesh.material_override != entry.override or entry.mesh.mesh != entry.resource or _surface_materials(entry.mesh) != entry.surfaces or _material_fingerprint(entry.mesh) != entry.fingerprint:
			failures.append(str(entry.mesh.get_path()))
			material_failures.append(str(entry.mesh.get_path()))
	return {"checked": original_materials.size(), "failures": failures}

func capture_case(case_name: String, references: bool = true, use_meshes: bool = false) -> void:
	remember_materials()
	highlighter.clear_target()
	await save_capture(case_name, "off")
	style.mode = 1
	highlighter.apply_style(style)
	if use_meshes:
		highlighter.set_meshes(Factory.get_meshes(targets[selected]))
	else:
		highlighter.set_target(targets[selected])
	await save_capture(case_name, "outline")
	style.mode = 2
	highlighter.apply_style(style)
	await save_capture(case_name, "fill")
	var checks := check_materials()
	if not checks.failures.is_empty():
		push_error("Material mutation: " + str(checks.failures))
	if references:
		await capture_reference(case_name, false)
		await capture_reference(case_name, true)
		if case_name.begins_with("occlusion_"):
			await capture_reference(case_name, false, true)

## Independent geometry oracle: opaque unshaded white target / black surroundings.
## Reference images are captured only after the three unchanged art screenshots.
func capture_reference(case_name: String, full_projection: bool, wall_oracle: bool = false) -> void:
	highlighter.clear_target()
	var selected_meshes: Array[MeshInstance3D] = Factory.get_meshes(targets[selected])
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	var visibility: Array[Dictionary] = []
	for entry in original_materials:
		var mesh: MeshInstance3D = entry.mesh
		if not is_instance_valid(mesh):
			continue
		visibility.append({"mesh": mesh, "visible": mesh.visible})
		mesh.material_overlay = null
		var is_white := mesh.name == "OcclusionWall" if wall_oracle else selected_meshes.has(mesh)
		mesh.material_override = white if is_white else black
		if full_projection and not selected_meshes.has(mesh):
			mesh.hide()
	var environment: Environment = null
	for child in get_children():
		if child is WorldEnvironment:
			environment = child.environment
	var background: Color = environment.background_color
	environment.background_color = Color.BLACK
	await save_capture(case_name, "wall" if wall_oracle else ("projection" if full_projection else "visible"))
	environment.background_color = background
	for entry in original_materials:
		if is_instance_valid(entry.mesh):
			entry.mesh.material_override = entry.override
			entry.mesh.material_overlay = entry.overlay
	for entry in visibility:
		entry.mesh.visible = entry.visible

func run_matrix() -> void:
	for index in range(targets.size()):
		selected = index
		camera.position = targets[index].global_position + Vector3(1.8, 1.8, 4.4)
		camera.look_at(targets[index].global_position + Vector3(0, 0.6, 0))
		await capture_case("type_" + Factory.KINDS[index])
		if index == 5:
			area.set_fixed_pose(0.65)
			await capture_case("skinned_pose_1")
			area.set_fixed_pose(-0.65)
			await capture_case("skinned_pose_2")
			area.set_fixed_pose(0.0)
	var morph := Factory.create_sample("blendshape")
	targets[5].hide()
	area.add_child(morph)
	morph.position = Vector3(2, 0, 2)
	targets.append(morph)
	selected = targets.size() - 1
	for weight in [0.0, 1.0]:
		Factory.set_animation_pose(morph, 0.0, weight)
		await capture_case("blendshape_%d" % int(weight))
	morph.hide()
	targets[5].show()
	selected = 2
	var target := targets[selected]
	var occluder: MeshInstance3D = area.get_node("OcclusionWall")
	var wall_position := occluder.position
	var wall_scale := occluder.scale
	var target_position := target.position
	var occlusion_sample_visibility: Array[Dictionary] = []
	for sample in targets:
		occlusion_sample_visibility.append({"sample": sample, "visible": sample.visible})
		if sample != target:
			sample.hide()
	camera.position = Vector3(2, 1.1, 5)
	camera.look_at(Vector3(2, 0.6, -2))
	occluder.position = Vector3(2, 0.65, 0)
	occluder.scale = Vector3(2, 2, 1)
	await capture_case("occlusion_full")
	occluder.position.x = 2.6
	occluder.scale = Vector3.ONE
	await capture_case("occlusion_partial")
	occluder.position = wall_position
	occluder.scale = wall_scale
	for entry in occlusion_sample_visibility:
		entry.sample.visible = entry.visible
	for distance in [2.5, 8.0, 14.0]:
		for angle in [-0.6, 0.0, 0.7]:
			camera.position = target.global_position + Vector3(sin(angle) * distance, 1.7, cos(angle) * distance)
			camera.look_at(target.global_position + Vector3(0, 0.6, 0))
			await capture_case("range_%.1f_angle_%.1f" % [distance, angle])
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1440, 1080)]:
		style.mode = 2
		highlighter.apply_style(style)
		highlighter.set_target(target)
		await settle()
		DisplayServer.window_set_size(size)
		var case_name := "resolution_%dx%d" % [size.x, size.y]
		var frame_number := 0
		for interval in [1, 1, 1, 2, 5]:
			frame_number += interval
			await save_capture(case_name, "resize_frame_%d" % frame_number, interval)
		await capture_case(case_name)
	# Sharing both surface and overlay resources must affect only the selected instance.
	var twin := Factory.create_sample("rigid")
	area.add_child(twin)
	twin.position = Vector3(0.2, 0, -2)
	var original_meshes := Factory.get_meshes(targets[4])
	var twin_meshes := Factory.get_meshes(twin)
	for i in range(original_meshes.size()):
		twin_meshes[i].mesh = original_meshes[i].mesh
		twin_meshes[i].material_override = original_meshes[i].material_override
		twin_meshes[i].material_overlay = original_meshes[i].material_overlay
	targets[4].position = Vector3(2, 0, -2)
	selected = 4
	camera.position = Vector3(1.1, 2.0, 4)
	camera.look_at(Vector3(1.1, 0.6, -2))
	await capture_case("shared_material_overlay")
	await lifecycle_checks()
	target.position = target_position
	await transformation_checks()

func lifecycle_checks() -> void:
	var target: Node3D = targets[selected]
	var pos := target.position
	highlighter.set_target(target)
	await settle()
	target.position.x += 0.7
	await save_capture("target_moved", "live")
	await capture_case("target_moved")
	target.position = pos
	highlighter.clear_target()
	await save_capture("lifecycle", "clear_off")
	highlighter.set_target(target)
	await settle()
	highlighter.clear_target()
	await save_capture("lifecycle", "clear")
	highlighter.set_target(target)
	target.hide()
	await save_capture("lifecycle", "hidden")
	highlighter.clear_target()
	await save_capture("lifecycle", "hidden_off")
	target.show()
	var original_parent := target.get_parent()
	var outer_ancestor := Node3D.new()
	outer_ancestor.name = "QAOuterAncestor"
	area.add_child(outer_ancestor)
	var inner_parent := Node3D.new()
	inner_parent.name = "QAInnerParent"
	outer_ancestor.add_child(inner_parent)
	target.reparent(inner_parent, true)
	highlighter.set_target(target)
	await settle()
	outer_ancestor.hide()
	await save_capture("lifecycle", "ancestor_hidden")
	highlighter.clear_target()
	await save_capture("lifecycle", "ancestor_hidden_off")
	outer_ancestor.show()
	highlighter.set_target(target)
	await save_capture("ancestor_restored", "live")
	await capture_case("ancestor_restored")
	target.reparent(original_parent, true)
	outer_ancestor.queue_free()
	highlighter.set_target(target)
	await settle()
	highlighter.set_target(targets[0])
	selected = 0
	await save_capture("target_switched", "live")
	await capture_case("target_switched")
	var temporary := Factory.create_sample("box")
	area.add_child(temporary)
	temporary.position = Vector3(1, 0, 1)
	highlighter.set_target(temporary)
	await settle()
	temporary.queue_free()
	await save_capture("lifecycle", "freed")
	highlighter.clear_target()
	await save_capture("lifecycle", "freed_off")
	var new_camera := Camera3D.new()
	new_camera.transform = camera.transform
	new_camera.fov = camera.fov
	new_camera.compositor = original_compositor
	add_child(new_camera)
	new_camera.make_current()
	var old_camera := camera
	highlighter.set_target(targets[selected])
	await settle()
	highlighter.bind_camera(new_camera)
	compositor_restored = old_camera.compositor == original_compositor
	camera = new_camera
	await save_capture("camera_rebound", "live")
	await capture_case("camera_rebound")
	await capture_case("explicit_meshes", true, true)
	highlighter.clear_target()
	selected = 2
	camera.position = targets[selected].global_position + Vector3(1.8, 1.8, 4.4)
	camera.look_at(targets[selected].global_position + Vector3(0, 0.6, 0))
	style.mode = 2
	highlighter.apply_style(style)
	highlighter.set_target(targets[0])
	await settle()
	var burst_start_frame := Engine.get_frames_drawn()
	highlighter.set_target(targets[1])
	highlighter.clear_target()
	highlighter.set_target(targets[5])
	highlighter.set_target(targets[4])
	highlighter.clear_target()
	highlighter.set_target(targets[0])
	highlighter.clear_target()
	highlighter.set_target(targets[selected])
	var burst_end_frame := Engine.get_frames_drawn()
	await save_capture("target_burst_switched", "burst_frame_1", 1)
	await save_capture("target_burst_switched", "live")
	records.back()["burst"] = {"start_frame": burst_start_frame, "end_frame": burst_end_frame, "operation_count": 8, "final_target_id": targets[selected].get_instance_id(), "final_target_name": targets[selected].name}
	await capture_case("target_burst_switched")
	highlighter.clear_target()

func transformation_checks() -> void:
	selected = 2
	var target: Node3D = targets[selected]
	var original_transform := target.transform
	target.position.y += 0.25
	camera.position = target.global_position + Vector3(1.8, 1.8, 4.4)
	camera.look_at(target.global_position + Vector3(0, 0.6, 0))
	await capture_case("root_transform_baseline")
	highlighter.set_target(target)
	await settle()
	target.rotation = Vector3(0.1, 0.62, 0.12)
	await save_capture("target_root_rotated", "live")
	await capture_case("target_root_rotated")
	highlighter.set_target(target)
	await settle()
	target.scale = Vector3(1.4, 0.7, 0.55)
	await save_capture("target_root_nonuniform_scaled", "live")
	await capture_case("target_root_nonuniform_scaled")
	target.transform = original_transform
	highlighter.clear_target()
