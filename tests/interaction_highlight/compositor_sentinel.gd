extends CompositorEffect
var callback_count := 0
var last_buffers: Dictionary = {}
var expected_target := RID()
func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
func _render_callback(_type: int, data: RenderData) -> void:
	callback_count += 1
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers != null:
		last_buffers = {"internal_size": str(buffers.get_internal_size()), "target_size": str(buffers.get_target_size()), "render_target": str(buffers.get_render_target()), "expected_target": str(expected_target), "frame": Engine.get_frames_drawn(), "taa": buffers.get_use_taa()}
