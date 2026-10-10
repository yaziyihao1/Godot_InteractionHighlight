extends Node3D
## Optional host example: attach to a new Node3D, assign camera and test target.
## Selection/input/UI remain the host's responsibility, not part of the core.
const Renderer = preload("res://addons/interaction_highlight/highlight_renderer.gd")
const Style = preload("res://addons/interaction_highlight/highlight_style.gd")

@export var camera: Camera3D
@export var test_target: Node3D
@export var highlight_style: Style = Style.new()

var highlighter: Node
var _bound := false

func _ready() -> void:
	highlighter = Renderer.new()
	add_child(highlighter)
	call_deferred("_setup")

func _setup() -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		push_error("Highlight quick start: assign your active Camera3D to camera.")
		return
	if highlight_style == null:
		highlight_style = Style.new()
	highlighter.bind_camera(camera)
	highlighter.apply_style(highlight_style)
	_bound = true
	show_target(test_target)

func show_target(target: Node3D) -> void:
	if _bound:
		highlighter.set_target(target)

func clear_highlight() -> void:
	if is_instance_valid(highlighter):
		highlighter.clear_target()
