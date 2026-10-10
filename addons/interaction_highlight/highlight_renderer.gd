extends Node
class_name InteractionHighlighter

const StyleResource = preload("res://addons/interaction_highlight/highlight_style.gd")
const GPUState = preload("res://addons/interaction_highlight/gpu_state.gd")
const Effect = preload("res://addons/interaction_highlight/highlight_effect.gd")
const DEPTH_SHADER = preload("res://addons/interaction_highlight/depth_proxy.gdshader")
const OVERLAY_SHADER = preload("res://addons/interaction_highlight/overlay.gdshader")

@export var style: StyleResource = StyleResource.new()
@export var overlay_layer: int = 1

var _camera: Camera3D
var _target: Node3D
var _meshes: Array[MeshInstance3D] = []
var _viewport: Viewport
var _mask_viewport: SubViewport
var _mask_camera: Camera3D
var _proxy_root: Node3D
var _canvas: CanvasLayer
var _rect: ColorRect
var _overlay_material: ShaderMaterial
var _depth_material: ShaderMaterial
var _gpu: GPUState
var _capture_effect: Effect
var _main_effect: Effect
var _original_compositor: Compositor
var _installed_compositor: Compositor
var _coverage_texture: Texture2DRD
var _depth_texture: Texture2DRD
var _pairs: Array[Dictionary] = []
var _skeleton_pairs: Array[Dictionary] = []
var _support_error := ""
var _last_reported_error := ""
var _pose_sync_count := 0


func _ready() -> void:
	process_priority = 100
	if style == null:
		style = StyleResource.new()
	if is_instance_valid(_camera):
		_create_runtime()


func bind_camera(camera: Camera3D) -> void:
	if _camera == camera and is_instance_valid(_mask_viewport):
		return
	_destroy_runtime()
	_camera = camera
	if is_inside_tree() and is_instance_valid(camera) and camera.is_inside_tree():
		_create_runtime()


func set_target(target: Node3D) -> void:
	if _target == target and is_instance_valid(target):
		return
	_disconnect_target()
	_target = target
	var sources: Array[MeshInstance3D] = []
	if is_instance_valid(target):
		if target is MeshInstance3D:
			sources.append(target)
		for child in target.find_children("*", "MeshInstance3D", true, false):
			sources.append(child as MeshInstance3D)
		target.tree_exiting.connect(_on_target_exiting, CONNECT_ONE_SHOT)
	_set_sources(sources)


func set_meshes(meshes: Array[MeshInstance3D]) -> void:
	_disconnect_target()
	_target = null
	_set_sources(meshes)


func apply_style(value: StyleResource) -> void:
	style = value if value != null else StyleResource.new()
	_update_style()


func clear_target() -> void:
	_disconnect_target()
	_target = null
	_meshes.clear()
	_free_proxies()
	if _gpu != null:
		_gpu.configure(_viewport_size(), false, style.outline_width_px, style.glow_width_px, style.depth_bias_m)
		_gpu.invalidate()
	if is_instance_valid(_rect):
		_rect.visible = false
		_overlay_material.set_shader_parameter("ready", false)


func _set_sources(sources: Array[MeshInstance3D]) -> void:
	_meshes.clear()
	for source in sources:
		if is_instance_valid(source) and source.mesh != null and not _meshes.has(source):
			_meshes.append(source)
	_free_proxies()
	if _gpu != null:
		_gpu.invalidate()
	if is_instance_valid(_proxy_root):
		_create_proxies()
	if is_instance_valid(_rect):
		_rect.visible = false
		_overlay_material.set_shader_parameter("ready", false)


func _create_runtime() -> void:
	_viewport = _camera.get_viewport()
	_gpu = GPUState.new()
	_mask_viewport = SubViewport.new()
	_mask_viewport.name = "InteractionHighlightDepth"
	_mask_viewport.world_3d = World3D.new()
	_mask_viewport.size = _viewport_size()
	_mask_viewport.handle_input_locally = false
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mask_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_mask_viewport.use_taa = false
	_mask_viewport.scaling_3d_scale = 1.0
	# Child viewports draw before their parent; required for same-frame RD data.
	_viewport.add_child(_mask_viewport)
	_proxy_root = Node3D.new()
	_proxy_root.name = "PrivateDepthGeometry"
	_mask_viewport.add_child(_proxy_root)
	_mask_camera = Camera3D.new()
	_mask_camera.name = "PrivateDepthCamera"
	_mask_camera.cull_mask = 1
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = false
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	_mask_camera.environment = environment
	_mask_viewport.add_child(_mask_camera)
	_mask_camera.current = true
	_depth_material = ShaderMaterial.new()
	_depth_material.shader = DEPTH_SHADER
	_capture_effect = Effect.new()
	_capture_effect.setup(_gpu, true, _mask_viewport.get_viewport_rid())
	var mask_compositor := Compositor.new()
	mask_compositor.compositor_effects = [_capture_effect]
	_mask_camera.compositor = mask_compositor
	_original_compositor = _camera.compositor
	_installed_compositor = Compositor.new()
	var effects: Array[CompositorEffect] = []
	var effective_compositor := _original_compositor
	if effective_compositor == null:
		# World3D's compositor accessor is internal, not script-bound in 4.7.
		# WorldEnvironment uses this scenario-scoped group to select its compositor.
		var group_name := "_world_compositor_" + str(_viewport.find_world_3d().scenario.get_id())
		var world_environment := get_tree().get_first_node_in_group(group_name) as WorldEnvironment
		if world_environment != null:
			effective_compositor = world_environment.compositor
	if effective_compositor != null:
		effects.assign(effective_compositor.compositor_effects)
	_main_effect = Effect.new()
	_main_effect.setup(_gpu, false, _viewport.get_viewport_rid())
	# The native property getter returns a copy. Assign the completed array back.
	effects.append(_main_effect)
	_installed_compositor.compositor_effects = effects
	_camera.compositor = _installed_compositor
	_canvas = CanvasLayer.new()
	_canvas.name = "InteractionHighlightOverlay"
	_canvas.layer = overlay_layer
	_canvas.custom_viewport = _viewport
	add_child(_canvas)
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = OVERLAY_SHADER
	_rect = ColorRect.new()
	_rect.name = "HighlightCoverage"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _overlay_material
	_rect.size = Vector2(_viewport_size())
	_rect.visible = false
	_canvas.add_child(_rect)
	_coverage_texture = Texture2DRD.new()
	_depth_texture = Texture2DRD.new()
	_overlay_material.set_shader_parameter("coverage_texture", _coverage_texture)
	RenderingServer.frame_pre_draw.connect(_sync_before_draw)
	_camera.tree_exiting.connect(_on_camera_exiting, CONNECT_ONE_SHOT)
	_update_style()
	_create_proxies()
	_sync_before_draw()


func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		if _gpu != null:
			_destroy_runtime()
		return
	if not is_instance_valid(_mask_viewport):
		if _camera.is_inside_tree():
			_create_runtime()
		return
	_update_style()
	var snapshot := _gpu.snapshot()
	var depth: RID = snapshot["depth_rid"]
	var coverage: RID = snapshot["coverage_rid"]
	# Never reattach an old snapshot while the auxiliary viewport is resizing.
	var raster_ready: bool = bool(snapshot["ready"]) and _callbacks_available() \
		and snapshot["size"] == _mask_viewport.size \
		and snapshot["requested_size"] == _mask_viewport.size \
		and snapshot["main_internal_size"] == _mask_viewport.size \
		and snapshot["main_target_size"] == _mask_viewport.size
	if raster_ready:
		if _coverage_texture.texture_rd_rid != coverage:
			_coverage_texture.texture_rd_rid = coverage
			# ShaderMaterial caches a RenderingServer RID, not a live resource link.
			_overlay_material.set_shader_parameter("coverage_texture", _coverage_texture)
		if _depth_texture.texture_rd_rid != depth:
			_depth_texture.texture_rd_rid = depth
	# Texture2DRD attaches asynchronously on the render thread. Data readiness
	# alone must not expose an unbound/placeholder sampler for even one frame.
	var wrapper_ready := coverage.is_valid() and _coverage_texture.texture_rd_rid == coverage \
		and Vector2i(_coverage_texture.get_size()) == _mask_viewport.size
	var ready: bool = raster_ready and wrapper_ready and not _meshes.is_empty() and _support_error.is_empty()
	_overlay_material.set_shader_parameter("ready", ready)
	_rect.visible = ready
	var message: String = snapshot["error"] if not str(snapshot["error"]).is_empty() else _support_error
	if message.is_empty():
		message = snapshot["transient_error"]
	if not message.is_empty() and message != _last_reported_error:
		_last_reported_error = message
		push_warning("InteractionHighlighter: " + message)


func _sync_before_draw() -> void:
	if not is_instance_valid(_mask_camera) or not is_instance_valid(_camera):
		return
	var desired := _viewport_size()
	if _mask_viewport.size != desired:
		_overlay_material.set_shader_parameter("ready", false)
		_rect.visible = false
		# A null RD assignment frees the wrapper's RS RID but leaves its RD
		# getter unchanged in Godot 4.7. Reusing it leaves ShaderMaterial's cached
		# sampler pointing at a freed RS texture. Fresh wrappers + explicit
		# rebinding keep the new placeholder RS RID stable through attachment.
		_overlay_material.set_shader_parameter("coverage_texture", null)
		_coverage_texture.texture_rd_rid = RID()
		_depth_texture.texture_rd_rid = RID()
		_coverage_texture = Texture2DRD.new()
		_depth_texture = Texture2DRD.new()
		_overlay_material.set_shader_parameter("coverage_texture", _coverage_texture)
		_mask_viewport.size = desired
	_rect.size = _viewport.get_visible_rect().size
	_mask_camera.global_transform = _camera.get_camera_transform()
	_mask_camera.projection = _camera.projection
	_mask_camera.fov = _camera.fov
	_mask_camera.size = _camera.size
	_mask_camera.near = _camera.near
	_mask_camera.far = _camera.far
	_mask_camera.keep_aspect = _camera.keep_aspect
	_mask_camera.frustum_offset = _camera.frustum_offset
	# get_camera_transform already contains source h_offset/v_offset.
	_mask_camera.h_offset = 0.0
	_mask_camera.v_offset = 0.0
	var valid_count := 0
	for pair in _pairs:
		var source := pair["source"] as MeshInstance3D
		var proxy := pair["proxy"] as MeshInstance3D
		if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion():
			proxy.visible = false
			continue
		valid_count += 1
		proxy.global_transform = source.global_transform
		proxy.visible = source.is_visible_in_tree() and (source.layers & _camera.cull_mask) != 0
		if proxy.mesh != source.mesh:
			proxy.mesh = source.mesh
		for index in mini(source.get_blend_shape_count(), proxy.get_blend_shape_count()):
			proxy.set_blend_shape_value(index, source.get_blend_shape_value(index))
	for pair in _skeleton_pairs:
		var source := pair["source"] as Skeleton3D
		if is_instance_valid(source):
			(pair["proxy"] as Skeleton3D).global_transform = source.global_transform
	_support_error = _check_support()
	if not _support_error.is_empty() or not _callbacks_available() or not bool(_gpu.snapshot()["ready"]):
		_rect.visible = false
		_overlay_material.set_shader_parameter("ready", false)
	_gpu.configure(desired, valid_count > 0 and _support_error.is_empty(), style.outline_width_px,
		style.glow_width_px if style.glow_strength > 0.0 else 0.0, style.depth_bias_m)
	if valid_count == 0 and not _meshes.is_empty():
		clear_target()


func _check_support() -> String:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return "Godot 4.7 Forward+ is required."
	if _viewport.use_taa or not is_equal_approx(_viewport.scaling_3d_scale, 1.0):
		return "Only 1:1 rendering without TAA/FSR is supported."
	if _viewport.scaling_3d_mode not in [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_NEAREST]:
		return "Temporal/spatial upscalers are outside this renderer's support contract."
	if _viewport.use_xr:
		return "XR/multiview is outside this renderer's support contract."
	return ""


func _viewport_size() -> Vector2i:
	if not is_instance_valid(_viewport):
		return Vector2i(2, 2)
	# In canvas_items/disabled stretch, the native window size is the upcoming
	# physical raster. RD's observation is still from the previous frame when
	# the OS window has just resized; using it would stretch old coverage once.
	var window := _viewport as Window
	if window != null and window.content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
		var physical := window.size
		if not window.is_embedded() and window.get_window_id() >= 0:
			physical = DisplayServer.window_get_size(window.get_window_id())
		return Vector2i(maxi(2, physical.x), maxi(2, physical.y))
	# RD is authoritative: ViewportTexture metadata can report the stretched
	# logical size (or a scaled placeholder) rather than the 3D raster size.
	if _gpu != null:
		var observed: Vector2i = _gpu.snapshot()["main_target_size"]
		if observed.x > 1 and observed.y > 1:
			return observed
	if _viewport is Window:
		return Vector2i(maxi(2, _viewport.size.x), maxi(2, _viewport.size.y))
	var raster := _viewport.get_texture().get_size()
	return Vector2i(maxi(2, roundi(raster.x)), maxi(2, roundi(raster.y)))


func _callbacks_available() -> bool:
	return _capture_effect != null and _capture_effect.enabled \
		and _main_effect != null and _main_effect.enabled \
		and is_instance_valid(_mask_viewport) \
		and _mask_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED


func _create_proxies() -> void:
	for source in _meshes:
		if not is_instance_valid(source) or source.mesh == null or not source.is_inside_tree():
			continue
		var proxy := MeshInstance3D.new()
		proxy.name = "Depth_" + source.name
		proxy.mesh = source.mesh
		proxy.material_override = _depth_material
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		proxy.layers = 1
		proxy.extra_cull_margin = source.extra_cull_margin
		_proxy_root.add_child(proxy)
		proxy.global_transform = source.global_transform
		var source_skeleton := source.get_node_or_null(source.skeleton) as Skeleton3D if not source.skeleton.is_empty() else null
		if source_skeleton != null:
			var skeleton_proxy := _get_skeleton_proxy(source_skeleton)
			proxy.skin = source.skin
			proxy.skeleton = proxy.get_path_to(skeleton_proxy)
		_pairs.append({"source": source, "proxy": proxy})
	_sync_before_draw()


func _get_skeleton_proxy(source: Skeleton3D) -> Skeleton3D:
	for pair in _skeleton_pairs:
		if pair["source"] == source:
			return pair["proxy"] as Skeleton3D
	var proxy := Skeleton3D.new()
	proxy.name = "Skeleton_" + source.name
	_proxy_root.add_child(proxy)
	proxy.global_transform = source.global_transform
	for index in source.get_bone_count():
		proxy.add_bone(source.get_bone_name(index))
	for index in source.get_bone_count():
		proxy.set_bone_parent(index, source.get_bone_parent(index))
		proxy.set_bone_rest(index, source.get_bone_rest(index))
	var sync := _copy_final_pose.bind(source, proxy)
	source.skeleton_updated.connect(sync)
	_skeleton_pairs.append({"source": source, "proxy": proxy, "callback": sync})
	_copy_final_pose(source, proxy)
	return proxy


func _copy_final_pose(source: Skeleton3D, proxy: Skeleton3D) -> void:
	if not is_instance_valid(source) or not is_instance_valid(proxy):
		return
	if source.get_bone_count() != proxy.get_bone_count():
		# Rebuilds are deferred rather than mutating a source skeleton's signal stack.
		call_deferred("_rebuild_proxies")
		return
	proxy.global_transform = source.global_transform
	var globals: Array[Transform3D] = []
	for index in source.get_bone_count():
		globals.append(source.get_bone_global_pose(index))
	for index in globals.size():
		var parent := source.get_bone_parent(index)
		var local_pose := globals[parent].affine_inverse() * globals[index] if parent >= 0 else globals[index]
		proxy.set_bone_enabled(index, true)
		proxy.set_bone_rest(index, source.get_bone_rest(index))
		proxy.set_bone_pose(index, local_pose)
	# Flush this private skeleton's skin upload in the same final-pose callback.
	proxy.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	_pose_sync_count += 1


func _rebuild_proxies() -> void:
	if is_instance_valid(_proxy_root):
		_free_proxies()
		_create_proxies()


func _free_proxies() -> void:
	for pair in _skeleton_pairs:
		var source := pair["source"] as Skeleton3D
		var callback: Callable = pair["callback"]
		if is_instance_valid(source) and source.skeleton_updated.is_connected(callback):
			source.skeleton_updated.disconnect(callback)
	_skeleton_pairs.clear()
	_pairs.clear()
	if is_instance_valid(_proxy_root):
		for child in _proxy_root.get_children():
			# Hide immediately on target switches. Synchronous remove_child is
			# illegal during ancestor teardown; hidden proxies cannot draw meanwhile.
			if child is Node3D:
				child.visible = false
			child.queue_free()


func _update_style() -> void:
	if style == null:
		style = StyleResource.new()
	if is_instance_valid(_overlay_material):
		_overlay_material.set_shader_parameter("mode", style.mode)
		_overlay_material.set_shader_parameter("outline_color", style.outline_color)
		_overlay_material.set_shader_parameter("outline_alpha", clampf(style.outline_alpha, 0.0, 1.0))
		_overlay_material.set_shader_parameter("fill_color", style.fill_color)
		_overlay_material.set_shader_parameter("fill_alpha", clampf(style.fill_alpha, 0.0, 1.0))
		_overlay_material.set_shader_parameter("glow_strength", clampf(style.glow_strength, 0.0, 1.0))


func _disconnect_target() -> void:
	if is_instance_valid(_target) and _target.tree_exiting.is_connected(_on_target_exiting):
		_target.tree_exiting.disconnect(_on_target_exiting)


func _on_target_exiting() -> void:
	clear_target()


func _on_camera_exiting() -> void:
	clear_target()
	_destroy_runtime()
	_camera = null


func _destroy_runtime() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_before_draw):
		RenderingServer.frame_pre_draw.disconnect(_sync_before_draw)
	if is_instance_valid(_camera):
		if _camera.tree_exiting.is_connected(_on_camera_exiting):
			_camera.tree_exiting.disconnect(_on_camera_exiting)
		# Restore only if our compositor is still installed; preserve later host changes.
		if _camera.compositor == _installed_compositor:
			_camera.compositor = _original_compositor
	if _capture_effect != null:
		_capture_effect.enabled = false
	if _main_effect != null:
		_main_effect.enabled = false
	if is_instance_valid(_rect):
		_rect.visible = false
	if is_instance_valid(_mask_viewport):
		_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _coverage_texture != null:
		_coverage_texture.texture_rd_rid = RID()
	if _depth_texture != null:
		_depth_texture.texture_rd_rid = RID()
	if _gpu != null:
		_gpu.dispose()
	_free_proxies()
	for node in [_canvas, _mask_viewport]:
		if is_instance_valid(node):
			node.queue_free()
	_canvas = null
	_rect = null
	_mask_viewport = null
	_mask_camera = null
	_proxy_root = null
	_overlay_material = null
	_gpu = null
	_capture_effect = null
	_main_effect = null
	_installed_compositor = null
	_original_compositor = null
	_coverage_texture = null
	_depth_texture = null
	_support_error = ""
	_last_reported_error = ""


func _exit_tree() -> void:
	_disconnect_target()
	_destroy_runtime()


# QA API: getters never read back GPU memory. Readbacks are explicit and deferred.
func get_debug_state() -> Dictionary:
	var result := _gpu.snapshot() if _gpu != null else {"active": false, "ready": false}
	result["support_error"] = _support_error
	result["proxy_count"] = _pairs.size()
	result["skeleton_count"] = _skeleton_pairs.size()
	result["pose_sync_count"] = _pose_sync_count
	result["overlay_ready"] = is_instance_valid(_rect) and _rect.visible
	result["callbacks_available"] = _callbacks_available()
	result["target_id"] = _target.get_instance_id() if is_instance_valid(_target) else 0
	result["private_world"] = is_instance_valid(_mask_viewport) and is_instance_valid(_viewport) and _mask_viewport.world_3d != _viewport.find_world_3d()
	result["channels"] = "R:outline G:visible_fill B:glow A:complete_projection"
	return result


func get_debug_coverage_texture() -> Texture2DRD:
	return _coverage_texture


func get_debug_depth_texture() -> Texture2DRD:
	return _depth_texture


func request_debug_readback(kind: String, callback: Callable) -> void:
	if _gpu != null and kind in ["depth", "scene_depth", "coverage"]:
		_gpu.request_readback(kind, callback)
	else:
		callback.call_deferred({"kind": kind, "size": Vector2i.ZERO, "data": PackedByteArray(), "error": "Renderer is not bound or kind is invalid."})
