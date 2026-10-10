extends Node3D
## Standalone host: the frozen addon owns rendering; this scene owns input/UI.
const Factory = preload("res://scripts/sample_factory.gd")
const RendererScript = preload("res://addons/interaction_highlight/highlight_renderer.gd")
const StyleScript = preload("res://addons/interaction_highlight/highlight_style.gd")
const PanelScript = preload("res://scripts/interaction_highlight_panel.gd")
const SAMPLE_KINDS = ["box", "sphere", "handle", "thin", "rigid", "skinned", "blendshape"]
const EYE_HEIGHT := 1.65
const MOVE_SPEED := 4.0
const MOUSE_SENSITIVITY := 0.0025
const PITCH_LIMIT := deg_to_rad(85.0)
const RAY_DISTANCE := 24.0

@export var animate_samples := true
@export var capture_mouse_on_start := true
@export var ray_selection_enabled := true
var camera: Camera3D
var highlighter: Node
var style: Resource
var targets: Array[Node3D] = []
var panel: PanelContainer
## 0 = off, 1 = Coverage, 2 = Target Depth (diagnostics only).
var preview_mode := 0
var selected_target: Node3D
var binding_ready := false
var animation_time := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _hud: Label
var _crosshair: Label
var _ui_root: Control

func _ready() -> void:
	_build_world()
	style = StyleScript.new()
	style.outline_width_px = 2.5
	style.fill_color = Color.YELLOW
	highlighter = RendererScript.new()
	highlighter.name = "Highlighter"
	add_child(highlighter)
	_build_ui()
	# bind_camera adds a viewport sibling. The root must finish _ready first;
	# binding here synchronously causes "parent is busy setting up children".
	call_deferred("_bind_highlighter")
	if capture_mouse_on_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()

func _bind_highlighter() -> void:
	if not is_inside_tree() or not camera.is_inside_tree() or not highlighter.is_node_ready():
		return
	highlighter.bind_camera(camera)
	highlighter.apply_style(style)
	binding_ready = true
	if is_instance_valid(selected_target):
		highlighter.set_target(selected_target)

func _build_world() -> void:
	get_viewport().use_taa = false
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.11, 0.14, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 0.9
	light.shadow_enabled = true
	add_child(light)
	_add_solid("Ground", Vector3(26, 0.2, 22), Vector3(0, -0.1, 0), Color(0.24, 0.27, 0.3))
	for index in SAMPLE_KINDS.size():
		var target: Node3D = Factory.create_sample(SAMPLE_KINDS[index])
		target.position = Vector3((index - 3) * 2.4, 0, -2.0)
		add_child(target)
		target.add_to_group("playground_targets")
		targets.append(target)
		var caption := Label3D.new()
		caption.name = "Caption"
		caption.text = "%d  %s" % [index + 1, SAMPLE_KINDS[index].capitalize()]
		caption.position = Vector3(0, 1.65, 0)
		caption.font_size = 28
		caption.pixel_size = 0.008
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.modulate = Color(0.85, 0.88, 0.92)
		target.add_child(caption)
	# Blocks the sphere's lower-left silhouette but leaves a reachable exposed area.
	_add_solid("PartialOccluder", Vector3(0.65, 0.78, 0.4), Vector3(-5.13, 0.39, -1.3), Color(0.38, 0.39, 0.41))
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, EYE_HEIGHT, 8)
	camera.fov = 70
	camera.near = 0.05
	camera.far = 80
	add_child(camera)
	camera.look_at(Vector3(0, 0.65, -2))
	_pitch = camera.rotation.x
	_yaw = camera.rotation.y
	camera.make_current()

func _add_solid(node_name: String, dimensions: Vector3, location: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = location
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PlaygroundUI"
	canvas.layer = 10
	add_child(canvas)
	var root := Control.new()
	root.name = "UIRoot"
	_ui_root = root
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	# Keep the small UI readable in physical pixels despite the host project's
	# 1920px canvas stretch (including a 960x600 window).
	get_viewport().size_changed.connect(_resize_ui)
	_resize_ui()
	_hud = Label.new()
	_hud.name = "Help"
	_hud.position = Vector2(16, 12)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_font_size_override("font_size", 16)
	root.add_child(_hud)
	_crosshair = Label.new()
	_crosshair.name = "Crosshair"
	_crosshair.text = "+"
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -10
	_crosshair.offset_top = -12
	_crosshair.offset_right = 10
	_crosshair.offset_bottom = 12
	panel = PanelScript.new()
	panel.name = "TuningPanel"
	root.add_child(panel)
	panel.setup(style, highlighter, camera)
	panel.style_changed.connect(_apply_style)
	panel.preview_mode_changed.connect(func(value: int) -> void: preview_mode = value)
	panel.close_requested.connect(func() -> void: set_panel_open(false))
	panel.hide()

func _resize_ui() -> void:
	var stretch_scale := get_viewport().get_final_transform().get_scale()
	_ui_root.scale = Vector2.ONE / stretch_scale
	_ui_root.size = get_viewport().get_visible_rect().size * stretch_scale

func _apply_style() -> void:
	if binding_ready:
		highlighter.apply_style(style)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			set_panel_open(not panel.visible)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			set_panel_open(false, false)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and controls_active():
		_yaw = camera.rotation.y
		_pitch = camera.rotation.x
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		camera.rotation = Vector3(_pitch, _yaw, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not panel.visible or not panel.get_global_rect().has_point(event.position):
			set_panel_open(false, true)
			get_viewport().set_input_as_handled()

func controls_active() -> bool:
	return not panel.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func set_panel_open(open: bool, capture_on_close: bool = true) -> void:
	panel.visible = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open or not capture_on_close else Input.MOUSE_MODE_CAPTURED
	if open:
		# Selection and renderer remain active while the host's movement/ray pause.
		panel.controls["OutlineWidthSpinBox"].get_line_edit().grab_focus()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()
	_update_hud()

func _physics_process(delta: float) -> void:
	if not controls_active():
		return
	var axes := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	move_camera(axes, delta)
	if ray_selection_enabled and binding_ready:
		update_aim_selection()

## Flat, normalized FPS movement; pitch never adds vertical drift.
func move_camera(axes: Vector2, delta: float) -> void:
	if axes.is_zero_approx():
		return
	var yaw_basis := Basis(Vector3.UP, camera.rotation.y)
	var velocity := yaw_basis * Vector3(axes.x, 0, axes.y).limit_length()
	camera.position += velocity * MOVE_SPEED * delta
	camera.position.x = clampf(camera.position.x, -11, 11)
	camera.position.z = clampf(camera.position.z, -8, 10)

func update_aim_selection() -> void:
	if panel.visible or not binding_ready:
		return
	var center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_DISTANCE)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	select_target(target_from_collider(hit.get("collider")))

func target_from_collider(collider: Node) -> Node3D:
	var current := collider
	while is_instance_valid(current):
		if current is Node3D and targets.has(current):
			return current as Node3D
		current = current.get_parent()
	return null

func select_target(target: Node3D) -> void:
	if target != null and not targets.has(target):
		return
	if selected_target == target:
		return
	selected_target = target
	if binding_ready:
		if target == null:
			highlighter.clear_target()
		else:
			highlighter.set_target(target)
	_update_hud()

## QA can freeze a real bone + blend shape at a reproducible pose.
func set_sample_animation(enabled: bool, time_seconds: float = 0.0) -> void:
	animate_samples = enabled
	animation_time = time_seconds
	for target in targets:
		Factory.update_animation_pose(target, animation_time)

func set_preview_mode(value: int) -> void:
	panel.set_preview_mode(value)
	preview_mode = panel.preview_mode

func _process(delta: float) -> void:
	if animate_samples:
		animation_time += delta
		for target in targets:
			Factory.update_animation_pose(target, animation_time)
	if panel.visible:
		panel.update_diagnostics(selected_target)

func _update_hud() -> void:
	if _hud == null:
		return
	var selection: String = str(selected_target.name) if is_instance_valid(selected_target) else "None"
	_hud.text = "WASD Move   Mouse Look   E Settings   Esc Release\nTarget: %s" % selection
	if panel.visible:
		_hud.text += "\nSelection held for live tuning"
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_hud.text += "\nClick outside UI to capture mouse"
	_crosshair.visible = not panel.visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_hud()
