extends Node

## 地图视图：世界尺寸、视角中心、拖动输入、world_to_screen 转换。
## 不处理边界/循环/缩放，仅平移。
## 初始状态：竖直方向盖住屏幕且垂直居中。

signal view_changed

const MAP_WIDTH := 4000
const MAP_HEIGHT := 2000

var view_center: Vector2 = Vector2(500, 350)
var zoom: float = 1.0
var min_zoom: float = 0.5
var max_zoom: float = 5.0
var _dragging := false

func _ready() -> void:
	call_deferred("_apply_initial_state")

func _get_view_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280, 720)
	return vp.get_visible_rect().size

## 仅设定初始视角：zoom 足够大以盖住屏幕高度，view_center 水平与垂直居中。不限制后续拖动/缩放。
func _apply_initial_state() -> void:
	var view_size: Vector2 = _get_view_size()
	var min_zoom_to_cover: float = view_size.y / float(MAP_HEIGHT)
	if zoom < min_zoom_to_cover:
		zoom = min_zoom_to_cover
	view_center.x = float(MAP_WIDTH) / 2.0
	view_center.y = float(MAP_HEIGHT) / 2.0
	view_changed.emit()

func _map_top_y(center_y: float, z: float, view_size: Vector2) -> float:
	return view_size.y / 2.0 + (0.0 - center_y) * z

func _map_bottom_y(center_y: float, z: float, view_size: Vector2) -> float:
	return view_size.y / 2.0 + (float(MAP_HEIGHT) - center_y) * z

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
		var view_size: Vector2 = _get_view_size()
		var new_center: Vector2 = view_center - mm.relative
		var top_y: float = _map_top_y(new_center.y, zoom, view_size)
		var bottom_y: float = _map_bottom_y(new_center.y, zoom, view_size)
		var frame_top_y: float = 0.0
		var frame_bottom_y: float = view_size.y
		if top_y > frame_top_y:
			new_center.y = view_size.y / (2.0 * zoom)
		elif bottom_y < frame_bottom_y:
			new_center.y = float(MAP_HEIGHT) - view_size.y / (2.0 * zoom)
		view_center = new_center
		# X 方向 wrap：视角中心保持在 [0, MAP_WIDTH)
		while view_center.x < 0.0:
			view_center.x += float(MAP_WIDTH)
		while view_center.x >= float(MAP_WIDTH):
			view_center.x -= float(MAP_WIDTH)
		view_changed.emit()

func world_to_screen(world_pos: Vector2, view_size: Vector2) -> Vector2:
	var viewport_center: Vector2 = view_size / 2.0
	return viewport_center + (world_pos - view_center) * zoom

func get_view_center() -> Vector2:
	return view_center

func get_map_width() -> int:
	return MAP_WIDTH

func get_map_height() -> int:
	return MAP_HEIGHT

func get_zoom() -> float:
	return zoom

func _vertical_min_zoom(view_size: Vector2) -> float:
	var frame_half: float = view_size.y / 2.0
	var top_dist: float = maxf(view_center.y, 0.0001)
	var bottom_dist: float = maxf(float(MAP_HEIGHT) - view_center.y, 0.0001)
	var z_top: float = frame_half / top_dist
	var z_bottom: float = frame_half / bottom_dist
	var needed: float = maxf(z_top, z_bottom)
	return maxf(min_zoom, needed)

func zoom_in() -> void:
	var view_size: Vector2 = _get_view_size()
	var target_zoom: float = zoom * 1.1
	var min_allowed: float = _vertical_min_zoom(view_size)
	zoom = clampf(target_zoom, min_allowed, max_zoom)
	view_changed.emit()

func zoom_out() -> void:
	var view_size: Vector2 = _get_view_size()
	var target_zoom: float = zoom * 0.9
	var min_allowed: float = _vertical_min_zoom(view_size)
	zoom = clampf(target_zoom, min_allowed, max_zoom)
	view_changed.emit()

func zoom_by_factor(factor: float) -> void:
	var view_size: Vector2 = _get_view_size()
	var target_zoom: float = zoom * factor
	var min_allowed: float = _vertical_min_zoom(view_size)
	zoom = clampf(target_zoom, min_allowed, max_zoom)
	view_changed.emit()
