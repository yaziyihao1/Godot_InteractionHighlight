extends Node3D
## Reusable arena, with no host scene or script dependency.
const Factory = preload("res://scripts/sample_factory.gd")
@export var animation_enabled := true
var _targets: Array[Node3D] = []
var _time := 0.0

func _ready() -> void:
	_build_ground()
	var positions := [Vector3(-2, 0, -2), Vector3(0, 0, -2), Vector3(2, 0, -2), Vector3(-2, 0, 2), Vector3(0, 0, 2), Vector3(2, 0, 2)]
	for i in range(Factory.KINDS.size()):
		var target: Node3D = Factory.create_sample(Factory.KINDS[i])
		target.position = positions[i]
		add_child(target)
		_targets.append(target)
	add_block("OcclusionWall", Vector3(1.5, 1.3, 0.25), Vector3(-2, 0.65, -0.85), Color(0.16, 0.18, 0.22))
	add_block("DarkBackground", Vector3(4, 2.5, 0.15), Vector3(-2, 1.25, -4.5), Color(0.025, 0.03, 0.045))
	add_block("LightBackground", Vector3(4, 2.5, 0.15), Vector3(2, 1.25, -4.5), Color(0.84, 0.85, 0.79))

func _process(delta: float) -> void:
	if animation_enabled:
		_time += delta
		update_animation_pose(_time)

func get_targets() -> Array[Node3D]:
	return _targets.duplicate()

func update_animation_pose(time_seconds: float) -> void:
	for target in _targets:
		Factory.update_animation_pose(target, time_seconds)

## Freeze first; optional deterministic pose applies to every animated sample.
func set_animation_enabled(enabled: bool) -> void:
	animation_enabled = enabled

func set_fixed_pose(tip_angle_radians: float, blend_weight: float = 0.0) -> void:
	animation_enabled = false
	for target in _targets:
		Factory.set_animation_pose(target, tip_angle_radians, blend_weight)

func _build_ground() -> void:
	add_block("Ground", Vector3(8, 0.15, 10), Vector3(0, -0.075, 0), Color(0.24, 0.27, 0.3))

func add_block(block_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = block_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	instance.material_override = material
	instance.position = pos
	add_child(instance)
	var body := StaticBody3D.new()
	instance.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return instance
