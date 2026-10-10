extends Resource
class_name HighlightStyle

@export_enum("Outline:1", "Fill and outline:2") var mode: int = 1
@export var outline_color: Color = Color.WHITE
@export_range(0.5, 12.0, 0.1) var outline_width_px: float = 2.0
@export_range(0.0, 1.0, 0.01) var outline_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01) var glow_strength: float = 0.12
@export_range(0.0, 16.0, 0.1) var glow_width_px: float = 3.0
@export var fill_color: Color = Color(1.0, 0.85, 0.4, 1.0)
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.25
@export_range(0.0, 0.05, 0.0001) var depth_bias_m: float = 0.002
