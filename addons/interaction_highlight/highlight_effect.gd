extends CompositorEffect

const GPUState = preload("res://addons/interaction_highlight/gpu_state.gd")
var shared_state: GPUState
var capture_pass := false
var viewport_rid := RID()


func setup(state: GPUState, is_capture: bool, viewport: RID) -> void:
	shared_state = state
	capture_pass = is_capture
	viewport_rid = viewport
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE if capture_pass else EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != effect_callback_type or shared_state == null:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null or buffers.get_render_target() != RenderingServer.viewport_get_render_target(viewport_rid):
		return
	if capture_pass:
		shared_state.capture(buffers)
	else:
		shared_state.compose(buffers, render_data.get_render_scene_data().get_cam_projection())
