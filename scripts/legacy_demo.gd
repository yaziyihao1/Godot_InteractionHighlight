extends Node3D
const Factory = preload("res://scripts/sample_factory.gd")
const AreaScene = preload("res://scene/demo_arena.tscn")
const RendererScript = preload("res://addons/interaction_highlight/highlight_renderer.gd")
const StyleScript = preload("res://addons/interaction_highlight/highlight_style.gd")
@export var fixed_camera := true
@export var animate_samples := true
var camera: Camera3D
var area: Node3D
var highlighter: Node
var style: Resource
var targets: Array[Node3D] = []
var selected := 2
var mode := 1
var ui: Label

func _ready() -> void:
	await get_tree().process_frame
	build_demo()
	_update_target()

func build_demo() -> void:
	get_viewport().use_taa = false
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = env
	add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.0
	light.shadow_enabled = false
	add_child(light)
	area = AreaScene.instantiate()
	area.animation_enabled = animate_samples
	add_child(area)
	targets = area.get_targets()
	camera = Camera3D.new()
	camera.name = "DemoCamera"
	camera.position = Vector3(6.5, 5, 9)
	camera.fov = 52
	camera.near = 0.05
	add_child(camera)
	camera.look_at(Vector3(0, 0.65, 0))
	camera.make_current()
	highlighter = RendererScript.new()
	add_child(highlighter)
	style = StyleScript.new()
	highlighter.bind_camera(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Label.new()
	ui.position = Vector2(18, 18)
	ui.add_theme_font_size_override("font_size", 20)
	canvas.add_child(ui)
	_update_label()

func _update_target() -> void:
	style.mode = mode
	highlighter.apply_style(style)
	if mode == 0:
		highlighter.clear_target()
	else:
		highlighter.set_target(targets[selected])
	_update_label()

func _update_label() -> void:
	if is_instance_valid(ui):
		ui.text = "1 Outline   2 Fill   0 Off   Tab Next   C Fixed/Free   WASD/QE Move\n%s | %s" % [targets[selected].name, "Fixed" if fixed_camera else "Free"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: mode = 1
		KEY_2: mode = 2
		KEY_0: mode = 0
		KEY_TAB: selected = (selected + 1) % targets.size()
		KEY_C: fixed_camera = not fixed_camera
	_update_target()

func _process(delta: float) -> void:
	if fixed_camera or not is_instance_valid(camera):
		return
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	camera.position += camera.basis * direction * delta * 4.0
	var yaw := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
	var pitch := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	camera.rotate_y(yaw * delta)
	camera.rotate_object_local(Vector3.RIGHT, pitch * delta)
