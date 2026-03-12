extends Node

## 地图视图：世界尺寸、视角中心、拖动输入、world_to_screen 转换。
## 不处理边界/循环/缩放，仅平移。

signal view_changed

const MAP_WIDTH := 4000
const MAP_HEIGHT := 2000

var view_center: Vector2 = Vector2(500, 350)
var zoom: float = 1.0
var min_zoom: float = 0.5
var max_zoom: float = 2.5
var _dragging := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
			else:
				_dragging = false
	if event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		view_center -= mm.relative
		view_changed.emit()

func world_to_screen(world_pos: Vector2, view_size: Vector2) -> Vector2:
	var viewport_center: Vector2 = view_size / 2.0
	return viewport_center + (world_pos - view_center) * zoom

func get_view_center() -> Vector2:
	return view_center

func get_zoom() -> float:
	return zoom

func zoom_in() -> void:
	zoom *= 1.1
	zoom = clamp(zoom, min_zoom, max_zoom)
	view_changed.emit()

func zoom_out() -> void:
	zoom *= 0.9
	zoom = clamp(zoom, min_zoom, max_zoom)
	view_changed.emit()

func zoom_by_factor(factor: float) -> void:
	zoom *= factor
	zoom = clamp(zoom, min_zoom, max_zoom)
	view_changed.emit()
