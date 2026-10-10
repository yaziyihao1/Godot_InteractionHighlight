extends RefCounted
## All returned roots are unattached, script-free Node3D instances.
const KINDS = ["box", "sphere", "handle", "thin", "rigid", "skinned"]

static func create_sample(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	root.set_meta("sample_kind", kind)
	var body := StaticBody3D.new()
	body.name = "Collision"
	root.add_child(body)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.58, 0.72)
	material.roughness = 0.68
	match kind:
		"box":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.15, 1.15, 1.15)
			material.albedo_texture = checker_texture()
			_add_mesh(root, body, mesh, material, Vector3(0, 0.575, 0))
		"sphere":
			var mesh := SphereMesh.new()
			mesh.radius = 0.6
			mesh.height = 1.2
			_add_mesh(root, body, mesh, material, Vector3(0, 0.6, 0))
		"handle":
			# A real through-hole, with four separate solid pieces.
			for part in [Vector4(-0.48, 0.65, 0.22, 1.1), Vector4(0.48, 0.65, 0.22, 1.1), Vector4(0, 0.2, 1.18, 0.2), Vector4(0, 1.1, 1.18, 0.2)]:
				var mesh := BoxMesh.new()
				mesh.size = Vector3(part.z, part.w, 0.25)
				_add_mesh(root, body, mesh, material, Vector3(part.x, part.y, 0))
		"thin":
			var rod := CylinderMesh.new()
			rod.top_radius = 0.025
			rod.bottom_radius = 0.025
			rod.height = 1.2
			_add_mesh(root, body, rod, material, Vector3(-0.25, 0.6, 0))
			var panel := BoxMesh.new()
			panel.size = Vector3(0.62, 0.82, 0.018)
			_add_mesh(root, body, panel, material, Vector3(0.19, 0.65, 0))
		"rigid":
			for part in [Vector4(-0.32, 0.4, 0.48, 0.65), Vector4(0.32, 0.55, 0.48, 0.9), Vector4(0, 1.07, 1.15, 0.22)]:
				var mesh := BoxMesh.new()
				mesh.size = Vector3(part.z, part.w, 0.5)
				var instance := _add_mesh(root, body, mesh, material.duplicate(), Vector3(part.x, part.y, 0))
				var overlay := StandardMaterial3D.new()
				overlay.albedo_texture = checker_texture()
				overlay.albedo_color = Color(0.72, 0.38, 0.2)
				overlay.roughness = 0.8
				instance.material_overlay = overlay
		"skinned":
			_create_skinned(root, body, material)
		"blendshape":
			_create_blendshape(root, body, material)
		_:
			root.free()
			push_error("Unknown sample kind: " + kind)
			return null
	return root

static func checker_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			img.set_pixel(x, y, Color(0.88, 0.75, 0.4) if (x / 8 + y / 8) % 2 == 0 else Color(0.18, 0.3, 0.42))
	return ImageTexture.create_from_image(img)

static func _add_mesh(root: Node3D, body: StaticBody3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Mesh%d" % root.get_child_count()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	root.add_child(instance)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape()
	collision.position = pos
	body.add_child(collision)
	return instance

static func _create_skinned(root: Node3D, body: StaticBody3D, material: Material) -> void:
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	root.add_child(skeleton)
	skeleton.add_bone("base")
	skeleton.add_bone("tip")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
	skeleton.reset_bone_poses()
	var source := CylinderMesh.new()
	source.height = 1.2
	source.top_radius = 0.22
	source.bottom_radius = 0.22
	source.radial_segments = 24
	source.rings = 12
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for i in range(vertices.size()):
		vertices[i].y += 0.6
		var tip_weight := smoothstep(0.4, 0.8, vertices[i].y)
		bones.append_array(PackedInt32Array([0, 1, 0, 0]))
		weights.append_array(PackedFloat32Array([1.0 - tip_weight, tip_weight, 0, 0]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := _add_mesh(root, body, mesh, material, Vector3.ZERO)
	instance.skeleton = NodePath("../Skeleton")
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	skin.add_bind(1, Transform3D(Basis.IDENTITY, Vector3(0, -0.6, 0)))
	instance.skin = skin
	root.set_meta("sample_skeleton", skeleton)

static func _create_blendshape(root: Node3D, body: StaticBody3D, material: Material) -> void:
	var source := SphereMesh.new()
	source.radius = 0.45
	source.height = 1.2
	var arrays := source.get_mesh_arrays()
	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
	for i in range(vertices.size()):
		vertices[i].x *= 1.3
		vertices[i].y *= 0.75
		vertices[i].z *= 0.7
		normals[i] = Vector3(normals[i].x / 1.3, normals[i].y / 0.75, normals[i].z / 0.7).normalized()
	shape[Mesh.ARRAY_VERTEX] = vertices
	shape[Mesh.ARRAY_NORMAL] = normals
	shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT].duplicate()
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	mesh.add_blend_shape("Squash")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
	var instance := _add_mesh(root, body, mesh, material, Vector3(0, 0.6, 0))
	root.set_meta("sample_blendmesh", instance)

## Host API: call with elapsed seconds, or use set_animation_pose for fixed QA.
static func update_animation_pose(root: Node3D, time_seconds: float) -> void:
	set_animation_pose(root, sin(time_seconds * 1.5) * 0.6, (sin(time_seconds) + 1.0) * 0.5)

## Deterministic pose; tip_angle_radians rotates the real second bone.
static func set_animation_pose(root: Node3D, tip_angle_radians: float, blend_weight: float = 0.0) -> void:
	if root.has_meta("sample_skeleton"):
		var skeleton: Skeleton3D = root.get_meta("sample_skeleton")
		skeleton.set_bone_pose_rotation(1, Quaternion(Vector3.FORWARD, tip_angle_radians))
	if root.has_meta("sample_blendmesh"):
		var instance: MeshInstance3D = root.get_meta("sample_blendmesh")
		instance.set_blend_shape_value(0, clampf(blend_weight, 0.0, 1.0))

static func get_meshes(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		result.append(child)
	return result
