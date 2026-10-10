extends RefCounted

# Embedded source is included in exports and does not depend on .glsl imports.
const CAPTURE_SOURCE := """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0, binding=0) uniform sampler2D source_depth;
layout(r32f, set=0, binding=1) uniform writeonly image2D target_depth;
layout(push_constant, std430) uniform Params { ivec4 raster; } params;
void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(p, params.raster.xy))) return;
    float z = params.raster.z != 0 ? texelFetch(source_depth, p, 0).r : 0.0;
    imageStore(target_depth, p, vec4(z));
}
"""

const PROXIMITY_SOURCE := """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0, binding=0) uniform sampler2D target_depth;
layout(r32f, set=0, binding=1) uniform writeonly image2D horizontal_support;
layout(push_constant, std430) uniform Params { ivec4 raster; } params;
void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(p, params.raster.xy))) return;
    float support = 0.0;
    for (int x=-params.raster.z; x<=params.raster.z; ++x) {
        ivec2 q = p + ivec2(x, 0);
        if (q.x>=0 && q.x<params.raster.x) support = max(support, texelFetch(target_depth,q,0).r);
    }
    imageStore(horizontal_support,p,vec4(support));
}
"""

const COVERAGE_SOURCE := """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0, binding=0) uniform sampler2D target_depth;
layout(set=0, binding=1) uniform sampler2D scene_depth;
layout(set=0, binding=2) uniform sampler2D horizontal_support;
layout(rgba16f, set=0, binding=3) uniform writeonly image2D coverage_image;
layout(push_constant, std430) uniform Params {
    mat4 inverse_projection;
    vec4 shape; // outline radius, glow width, bias in metres, active
    ivec4 raster;
} params;

float metres(ivec2 p, float z) {
    if (z<=0.0) return 1e30;
    vec2 uv = (vec2(p)+vec2(0.5))/vec2(params.raster.xy);
    vec4 view = params.inverse_projection * vec4(uv*2.0-1.0,z,1.0);
    return -view.z/view.w;
}

void main() {
    ivec2 p=ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(p,params.raster.xy))) return;
    if (params.shape.w<0.5) { imageStore(coverage_image,p,vec4(0.0)); return; }
    float tz=texelFetch(target_depth,p,0).r;
    float scene_m=metres(p,texelFetch(scene_depth,p,0).r);
    // Full projection T, not the visible mask, suppresses occlusion-cut edges.
    if (tz>0.0) {
        float visible=metres(p,tz)<=scene_m+params.shape.z ? 1.0:0.0;
        imageStore(coverage_image,p,vec4(0.0,visible,0.0,1.0));
        return;
    }
    int radius=int(ceil(params.shape.x+params.shape.y+0.5));
    bool supported=false;
    for (int y=-radius;y<=radius;++y) {
        int yy=p.y+y;
        if (yy>=0 && yy<params.raster.y && texelFetch(horizontal_support,ivec2(p.x,yy),0).r>0.0) {
            supported=true; break;
        }
    }
    if (!supported) { imageStore(coverage_image,p,vec4(0.0)); return; }
    float line=0.0;
    float glow=0.0;
    for (int y=-radius;y<=radius;++y) for (int x=-radius;x<=radius;++x) {
        float distance_px=length(vec2(x,y));
        if (distance_px>params.shape.x+params.shape.y+0.5) continue;
        ivec2 q=p+ivec2(x,y);
        if (any(lessThan(q,ivec2(0))) || any(greaterThanEqual(q,params.raster.xy))) continue;
        float candidate_z=texelFetch(target_depth,q,0).r;
        if (candidate_z<=0.0) continue;
        float candidate_m=metres(q,candidate_z);
        // Check both the source seed q and destination p against occluders.
        if (candidate_m>scene_m+params.shape.z) continue;
        if (candidate_m>metres(q,texelFetch(scene_depth,q,0).r)+params.shape.z) continue;
        line=max(line,clamp(params.shape.x+0.5-distance_px,0.0,1.0));
        if (params.shape.y>0.0) {
            float falloff=max(0.0,distance_px-params.shape.x)/params.shape.y;
            glow=max(glow,pow(max(0.0,1.0-falloff),2.0));
        }
    }
    imageStore(coverage_image,p,vec4(line,0.0,glow,0.0));
}
"""

var mutex := Mutex.new()
var active := false
var disposed := false
var requested_size := Vector2i.ZERO
var size := Vector2i.ZERO
var main_internal_size := Vector2i.ZERO
var main_target_size := Vector2i.ZERO
var outline_width := 2.0
var glow_width := 3.0
var depth_bias := 0.002
var generation := 0
var captured_generation := -1
var capture_frame := -1
var coverage_frame := -1
var capture_count := 0
var coverage_count := 0
var error := ""
var transient_error := ""
var rd: RenderingDevice
var depth_rid := RID()
var scene_depth_rid := RID()
var support_rid := RID()
var coverage_rid := RID()
var sampler := RID()
var shaders: Array[RID] = []
var pipelines: Array[RID] = []
var capture_set := RID()
var proximity_set := RID()
var coverage_set := RID()
var scene_capture_set := RID()
var capture_source := RID()
var coverage_source := RID()


func configure(new_size: Vector2i, enabled: bool, width: float, glow: float, bias: float) -> void:
	mutex.lock()
	if active != enabled or requested_size != new_size:
		generation += 1
	active = enabled
	requested_size = new_size
	outline_width = clampf(width, 0.5, 12.0)
	glow_width = clampf(glow, 0.0, 16.0)
	depth_bias = maxf(bias, 0.0)
	mutex.unlock()


func invalidate() -> void:
	mutex.lock()
	generation += 1
	captured_generation = -1
	mutex.unlock()


func snapshot() -> Dictionary:
	mutex.lock()
	var sampled_frame := Engine.get_frames_drawn()
	var capture_age := sampled_frame - capture_frame
	var coverage_age := sampled_frame - coverage_frame
	# Main-thread setup runs before this frame's render callbacks. The previous
	# completed frame is valid, but an equal pair of stopped callbacks is not.
	var fresh := capture_frame >= 0 and coverage_frame >= 0 \
		and capture_age >= 0 and capture_age <= 1 \
		and coverage_age >= 0 and coverage_age <= 1
	var result := {
		"active": active, "disposed": disposed, "size": size,
		"requested_size": requested_size, "error": error,
		"main_internal_size": main_internal_size, "main_target_size": main_target_size,
		"transient_error": transient_error,
		"depth_rid": depth_rid, "coverage_rid": coverage_rid,
		"scene_depth_rid": scene_depth_rid,
		"generation": generation, "captured_generation": captured_generation,
		"capture_frame": capture_frame, "coverage_frame": coverage_frame,
		"sampled_frame": sampled_frame, "capture_age_frames": capture_age,
		"coverage_age_frames": coverage_age, "fresh": fresh,
		"capture_count": capture_count, "coverage_count": coverage_count,
		"ready": not disposed and fresh and error.is_empty() and transient_error.is_empty() and coverage_rid.is_valid() and captured_generation == generation and coverage_frame == capture_frame,
	}
	mutex.unlock()
	return result


func capture(buffers: RenderSceneBuffersRD) -> void:
	mutex.lock()
	if disposed or not _ensure_resources():
		mutex.unlock()
		return
	if buffers.get_internal_size() != requested_size:
		transient_error = "Capture raster %s differs from requested %s." % [buffers.get_internal_size(), requested_size]
		mutex.unlock()
		return
	var source := buffers.get_depth_layer(0)
	if source != capture_source or not rd.uniform_set_is_valid(capture_set):
		_free_set(capture_set)
		capture_source = source
		capture_set = rd.uniform_set_create([_sample_uniform(0, source), _image_uniform(1, depth_rid)], shaders[0], 0)
	var push := PackedInt32Array([size.x, size.y, int(active), 0]).to_byte_array()
	_dispatch(0, capture_set, push)
	captured_generation = generation
	capture_frame = Engine.get_frames_drawn()
	capture_count += 1
	mutex.unlock()


func compose(buffers: RenderSceneBuffersRD, projection: Projection) -> void:
	mutex.lock()
	main_internal_size = buffers.get_internal_size()
	main_target_size = buffers.get_target_size()
	if disposed or not _ensure_resources():
		mutex.unlock()
		return
	if buffers.get_internal_size() != size or buffers.get_target_size() != size or buffers.get_use_taa():
		transient_error = "Main internal %s / target %s differs from requested %s, or TAA is enabled." % [buffers.get_internal_size(), buffers.get_target_size(), size]
		mutex.unlock()
		return
	transient_error = ""
	if captured_generation != generation or capture_frame != Engine.get_frames_drawn():
		mutex.unlock()
		return
	var source := buffers.get_depth_layer(0)
	if source != coverage_source or not rd.uniform_set_is_valid(coverage_set):
		_free_set(coverage_set)
		_free_set(scene_capture_set)
		coverage_source = source
		scene_capture_set = rd.uniform_set_create([_sample_uniform(0, source), _image_uniform(1, scene_depth_rid)], shaders[0], 0)
		coverage_set = rd.uniform_set_create([
			_sample_uniform(0, depth_rid), _sample_uniform(1, source),
			_sample_uniform(2, support_rid), _image_uniform(3, coverage_rid),
		], shaders[2], 0)
	var radius := ceili(outline_width + glow_width + 0.5)
	# Copy main depth for exact pose/occlusion QA, avoiding platform-specific D32/S8 readback.
	_dispatch(0, scene_capture_set, PackedInt32Array([size.x, size.y, 1, 0]).to_byte_array())
	_dispatch(1, proximity_set, PackedInt32Array([size.x, size.y, radius, 0]).to_byte_array())
	var inverse := projection.inverse()
	var push := PackedFloat32Array([
		inverse.x.x, inverse.x.y, inverse.x.z, inverse.x.w,
		inverse.y.x, inverse.y.y, inverse.y.z, inverse.y.w,
		inverse.z.x, inverse.z.y, inverse.z.z, inverse.z.w,
		inverse.w.x, inverse.w.y, inverse.w.z, inverse.w.w,
		outline_width, glow_width, depth_bias, float(active),
	]).to_byte_array()
	push.append_array(PackedInt32Array([size.x, size.y, 0, 0]).to_byte_array())
	_dispatch(2, coverage_set, push)
	coverage_frame = capture_frame
	coverage_count += 1
	mutex.unlock()


func _ensure_resources() -> bool:
	if not error.is_empty() or requested_size.x < 2 or requested_size.y < 2:
		return false
	if rd == null:
		rd = RenderingServer.get_rendering_device()
		if rd == null:
			error = "Forward+ RenderingDevice is required."
			return false
		for source_code: String in [CAPTURE_SOURCE, PROXIMITY_SOURCE, COVERAGE_SOURCE]:
			var source := RDShaderSource.new()
			source.source_compute = source_code
			var spirv := rd.shader_compile_spirv_from_source(source)
			var compile_error := spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
			if not compile_error.is_empty():
				error = compile_error
				push_error("Interaction highlight compute shader: " + error)
				return false
			var shader := rd.shader_create_from_spirv(spirv)
			shaders.append(shader)
			pipelines.append(rd.compute_pipeline_create(shader))
		var sampler_state := RDSamplerState.new()
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		sampler = rd.sampler_create(sampler_state)
	if size != requested_size:
		_free_buffers()
		size = requested_size
		depth_rid = _texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT)
		scene_depth_rid = _texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT)
		support_rid = _texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT)
		coverage_rid = _texture(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		if not depth_rid.is_valid() or not scene_depth_rid.is_valid() or not support_rid.is_valid() or not coverage_rid.is_valid():
			error = "GPU does not support the required numeric storage textures."
			return false
		proximity_set = rd.uniform_set_create([_sample_uniform(0, depth_rid), _image_uniform(1, support_rid)], shaders[1], 0)
	return true


func _texture(format_id: int) -> RID:
	var format := RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = format_id
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	if not rd.texture_is_format_supported_for_usage(format_id, format.usage_bits):
		return RID()
	return rd.texture_create(format, RDTextureView.new())


func _sample_uniform(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform


func _image_uniform(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform


func _dispatch(index: int, uniform_set: RID, push: PackedByteArray) -> void:
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipelines[index])
	rd.compute_list_bind_uniform_set(list, uniform_set, 0)
	rd.compute_list_set_push_constant(list, push, push.size())
	rd.compute_list_dispatch(list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	rd.compute_list_end()


func _free_set(value: RID) -> void:
	if value.is_valid() and rd.uniform_set_is_valid(value):
		rd.free_rid(value)


func _free_buffers() -> void:
	_free_set(capture_set)
	_free_set(proximity_set)
	_free_set(coverage_set)
	_free_set(scene_capture_set)
	capture_set = RID()
	proximity_set = RID()
	coverage_set = RID()
	scene_capture_set = RID()
	capture_source = RID()
	coverage_source = RID()
	for texture in [depth_rid, scene_depth_rid, support_rid, coverage_rid]:
		if texture.is_valid() and rd.texture_is_valid(texture):
			rd.free_rid(texture)
	depth_rid = RID()
	scene_depth_rid = RID()
	support_rid = RID()
	coverage_rid = RID()
	captured_generation = -1
	coverage_frame = -1


func dispose() -> void:
	mutex.lock()
	disposed = true
	active = false
	mutex.unlock()
	RenderingServer.call_on_render_thread(release)


func release() -> void:
	mutex.lock()
	if rd != null:
		_free_buffers()
		for shader in shaders:
			if shader.is_valid():
				rd.free_rid(shader) # Pipelines depend on shaders and are freed with them.
		shaders.clear()
		pipelines.clear()
		if sampler.is_valid():
			rd.free_rid(sampler)
		sampler = RID()
	mutex.unlock()


func request_readback(kind: String, callback: Callable) -> void:
	RenderingServer.call_on_render_thread(_readback.bind(kind, callback))


func _readback(kind: String, callback: Callable) -> void:
	mutex.lock()
	var texture := coverage_rid if kind == "coverage" else (scene_depth_rid if kind == "scene_depth" else depth_rid)
	var payload := {"kind": kind, "size": size, "format": "RGBA16F" if kind == "coverage" else "R32F", "data": PackedByteArray()}
	if not disposed and rd != null and texture.is_valid() and rd.texture_is_valid(texture):
		payload["data"] = rd.texture_get_data(texture, 0)
	mutex.unlock()
	callback.call_deferred(payload)
