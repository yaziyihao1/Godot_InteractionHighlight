extends PanelContainer
## Controls are public and named identically to their dictionary keys for QA.
signal style_changed
signal preview_mode_changed(value: int)
signal close_requested

const PreviewShader = preload("res://shader/debug_preview.gdshader")
const COLOR_HEX = ["FFFFFF", "FF0000", "FF8000", "FFFF00", "00FF00", "00FFFF", "0000FF", "8000FF"]
const COLOR_NAMES = ["White", "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Violet"]
const COLOR_LETTERS = ["W", "R", "O", "Y", "G", "C", "B", "V"]
var controls: Dictionary = {}
var style: Resource
var highlighter: Node
var camera: Camera3D
var preview_mode := 0
var diagnostics_open := false
var depth_range_m := Vector2(1, 10)
var _content: VBoxContainer
var _diagnostics: VBoxContainer
var _preview_material: ShaderMaterial
var _preview_aspect: AspectRatioContainer
var _last_preview_mode := 1

func setup(value: Resource, renderer: Node, view_camera: Camera3D) -> void:
	style = value
	highlighter = renderer
	camera = view_camera
	add_theme_font_size_override("font_size", 15)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.085, 0.1, 0.13, 0.98)
	box.border_color = Color(0.3, 0.35, 0.42)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", box)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _label("Highlight settings")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	_register(close, "CloseButton", "Close settings (E); Escape also releases mouse")
	header.add_child(close)
	close.pressed.connect(func() -> void: close_requested.emit())
	var scroll := ScrollContainer.new()
	_register(scroll, "SettingsScroll", "Scrollable highlight settings")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_content)
	_add_number("OutlineWidth", "Outline width (px)", 0.5, 12.0, 0.1, 2.5, _set_width)
	_add_palette("Outline", "Outline color")
	_add_number("OutlineOpacity", "Outline opacity", 0, 1, 0.01, 1, _set_opacity)
	_add_number("Glow", "Glow strength", 0, 1, 0.01, 0.12, _set_glow)
	var fill := CheckButton.new()
	fill.text = "Enable fill"
	_register(fill, "FillToggle", "Enable fill; outline remains enabled")
	_content.add_child(fill)
	fill.toggled.connect(func(enabled: bool) -> void:
		style.mode = 2 if enabled else 1
		style_changed.emit())
	_add_palette("Fill", "Fill color (independent)")
	_add_number("FillTransparency", "Fill transparency (%)", 0, 100, 1, 75, _set_transparency)
	var reset := Button.new()
	reset.text = "Reset defaults"
	_register(reset, "ResetButton", "Reset all settings to demo defaults")
	_content.add_child(reset)
	reset.pressed.connect(reset_defaults)
	var diagnostics := CheckButton.new()
	diagnostics.text = "Diagnostics"
	_register(diagnostics, "DiagnosticsToggle", "Expand renderer diagnostics and texture preview")
	_content.add_child(diagnostics)
	diagnostics.toggled.connect(set_diagnostics_open)
	_diagnostics = VBoxContainer.new()
	_diagnostics.name = "DiagnosticsContent"
	_diagnostics.add_theme_constant_override("separation", 6)
	_content.add_child(_diagnostics)
	var mode := OptionButton.new()
	mode.add_item("Coverage (RGBA16F)", 1)
	mode.add_item("Target Depth (meters)", 2)
	_register(mode, "PreviewMode", "Diagnostic preview mode")
	_diagnostics.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void: set_preview_mode(mode.get_item_id(index)))
	var status := _label("")
	_register(status, "DebugStatus", "Renderer ready, freshness, frame ages and errors")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostics.add_child(status)
	_preview_aspect = AspectRatioContainer.new()
	_preview_aspect.ratio = 1.6
	_preview_aspect.custom_minimum_size.y = 160
	_preview_aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagnostics.add_child(_preview_aspect)
	var preview := ColorRect.new()
	_register(preview, "DebugPreview", "Read-only diagnostic texture preview")
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_material = ShaderMaterial.new()
	_preview_material.shader = PreviewShader
	preview.material = _preview_material
	_preview_aspect.add_child(preview)
	var legend := _label("R outline · G fill · B glow\nA stores full target projection")
	_register(legend, "PreviewLegend", "Coverage channel or linear depth range legend")
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostics.add_child(legend)
	_sync_controls()
	set_diagnostics_open(false)
	get_parent().resized.connect(_resize_panel)
	_resize_panel()

func _register(control: Control, key: String, description: String) -> void:
	control.name = key
	control.tooltip_text = description
	# Godot versions exposing accessibility_name receive a descriptive name.
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", description)
			break
	controls[key] = control

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _resize_panel() -> void:
	var available: Vector2 = get_parent().size
	var width := minf(340.0, maxf(260, available.x - 32))
	offset_left = -width - 16
	offset_right = -16
	offset_top = 16
	offset_bottom = 16 + minf(540, maxf(120, available.y - 32))

func _add_number(key: String, label_text: String, low: float, high: float, step: float, initial: float, setter: Callable) -> void:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 2)
	_content.add_child(field)
	field.add_child(_label(label_text))
	var row := HBoxContainer.new()
	field.add_child(row)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 140
	_register(slider, key + "Slider", label_text)
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = initial
	spin.custom_minimum_size.x = 84
	_register(spin, key + "SpinBox", label_text + " numeric value")
	row.add_child(spin)
	slider.value_changed.connect(func(number: float) -> void:
		spin.set_value_no_signal(number)
		setter.call(number)
		style_changed.emit())
	spin.value_changed.connect(func(number: float) -> void:
		slider.set_value_no_signal(number)
		setter.call(number)
		style_changed.emit())
	if key == "FillTransparency":
		var hint := _label("0% opaque · 100% transparent")
		hint.add_theme_font_size_override("font_size", 12)
		field.add_child(hint)

func _add_palette(prefix: String, label_text: String) -> void:
	_content.add_child(_label(label_text))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_content.add_child(row)
	var group := ButtonGroup.new()
	for index in COLOR_HEX.size():
		var color := Color.html(COLOR_HEX[index])
		var button := Button.new()
		button.text = COLOR_LETTERS[index]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(30, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_register(button, prefix + "Color" + COLOR_HEX[index], "%s: %s (#%s)" % [label_text, COLOR_NAMES[index], COLOR_HEX[index]])
		var normal := StyleBoxFlat.new()
		normal.bg_color = color
		normal.set_corner_radius_all(3)
		normal.set_border_width_all(1)
		normal.border_color = Color(0.2, 0.22, 0.26)
		button.add_theme_stylebox_override("normal", normal)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.set_border_width_all(3)
		pressed.border_color = Color(0.55, 0.62, 0.72)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover", pressed)
		button.add_theme_stylebox_override("hover_pressed", pressed)
		var text_color := Color.BLACK if index in [0, 2, 3, 4, 5] else Color.WHITE
		for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, text_color)
		row.add_child(button)
		button.toggled.connect(func(enabled: bool) -> void:
			if enabled:
				if prefix == "Outline":
					style.outline_color = color
				else:
					style.fill_color = color
				style_changed.emit())

func _set_width(value: float) -> void:
	style.outline_width_px = value

func _set_opacity(value: float) -> void:
	style.outline_alpha = value

func _set_glow(value: float) -> void:
	style.glow_strength = value

func _set_transparency(value: float) -> void:
	style.fill_alpha = 1.0 - value / 100.0

func reset_defaults() -> void:
	style.mode = 1
	style.outline_width_px = 2.5
	style.outline_color = Color.WHITE
	style.outline_alpha = 1.0
	style.glow_strength = 0.12
	style.glow_width_px = 3.0
	style.fill_color = Color.YELLOW
	style.fill_alpha = 0.25
	style.depth_bias_m = 0.002
	_sync_controls()
	_last_preview_mode = 1
	set_diagnostics_open(false)
	style_changed.emit()

func _sync_controls() -> void:
	for key in ["OutlineWidth", "OutlineOpacity", "Glow", "FillTransparency"]:
		var number: float = {"OutlineWidth": style.outline_width_px, "OutlineOpacity": style.outline_alpha, "Glow": style.glow_strength, "FillTransparency": (1.0 - style.fill_alpha) * 100.0}[key]
		controls[key + "Slider"].set_value_no_signal(number)
		controls[key + "SpinBox"].set_value_no_signal(number)
	controls["FillToggle"].set_pressed_no_signal(style.mode == 2)
	for index in COLOR_HEX.size():
		var color := Color.html(COLOR_HEX[index])
		controls["OutlineColor" + COLOR_HEX[index]].set_pressed_no_signal(style.outline_color.is_equal_approx(color))
		controls["FillColor" + COLOR_HEX[index]].set_pressed_no_signal(style.fill_color.is_equal_approx(color))

func set_diagnostics_open(open: bool) -> void:
	diagnostics_open = open
	controls["DiagnosticsToggle"].set_pressed_no_signal(open)
	_diagnostics.visible = open
	preview_mode = _last_preview_mode if open else 0
	_preview_material.set_shader_parameter("preview_mode", preview_mode)
	if not open:
		_preview_material.set_shader_parameter("texture_ready", false)
		_preview_material.set_shader_parameter("debug_texture", null)
	preview_mode_changed.emit(preview_mode)

func set_preview_mode(value: int) -> void:
	value = clampi(value, 0, 2)
	if value == 0:
		set_diagnostics_open(false)
		return
	_last_preview_mode = value
	controls["PreviewMode"].select(value - 1)
	set_diagnostics_open(true)

## Raw reverse-Z -> positive view-space meters. Mirrors debug_preview shader.
func linearize_target_depth(raw_depth: float, uv: Vector2 = Vector2(0.5, 0.5)) -> float:
	var ndc := Vector4(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, 1.0 - 2.0 * raw_depth, 1)
	var position: Vector4 = camera.get_camera_projection().inverse() * ndc
	return -position.z / position.w

func update_diagnostics(target: Node3D = null) -> void:
	if not diagnostics_open:
		return
	var state: Dictionary = highlighter.get_debug_state()
	var errors: Array[String] = []
	for key in ["support_error", "error", "transient_error"]:
		var message := str(state.get(key, ""))
		if not message.is_empty():
			errors.append(message)
	controls["DebugStatus"].text = "Ready: %s   Overlay: %s   Fresh: %s\nFrame age: depth %s / coverage %s\nError: %s" % [state.get("ready", false), state.get("overlay_ready", false), state.get("fresh", false), state.get("capture_age_frames", "n/a"), state.get("coverage_age_frames", "n/a"), "None" if errors.is_empty() else "; ".join(errors)]
	var texture: Texture2DRD = highlighter.get_debug_coverage_texture() if preview_mode == 1 else highlighter.get_debug_depth_texture()
	var usable: bool = bool(state.get("ready", false)) and bool(state.get("fresh", false)) and texture != null
	if usable:
		usable = texture.texture_rd_rid.is_valid() and Vector2i(texture.get_size()) == state.get("size", Vector2i.ZERO)
	_preview_material.set_shader_parameter("texture_ready", usable)
	# Refresh the cached RS sampler as the public Texture2DRD gets reattached.
	_preview_material.set_shader_parameter("debug_texture", texture if usable else null)
	_preview_material.set_shader_parameter("camera_inverse_projection", camera.get_camera_projection().inverse())
	var viewport_size := camera.get_viewport().get_visible_rect().size
	_preview_aspect.ratio = viewport_size.x / maxf(1, viewport_size.y)
	if preview_mode == 1:
		controls["PreviewLegend"].text = "RGBA16F: R outline · G fill · B glow\nA stores full target projection"
	else:
		var center_depth := 5.0
		if is_instance_valid(target):
			center_depth = -(camera.get_camera_transform().affine_inverse() * (target.global_position + Vector3(0, 0.6, 0))).z
		depth_range_m = Vector2(maxf(camera.near, center_depth - 2.0), maxf(camera.near + 4.0, center_depth + 2.0))
		_preview_material.set_shader_parameter("depth_range_m", depth_range_m)
		controls["PreviewLegend"].text = "Linear depth: cyan %.2f m → orange %.2f m\nDark = no target. Range follows selected target." % [depth_range_m.x, depth_range_m.y]
