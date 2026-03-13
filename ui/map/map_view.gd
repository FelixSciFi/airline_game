extends Node

## 地图视图：世界尺寸、视角中心、拖动输入、world_to_screen 转换。
## 不处理边界/循环/缩放，仅平移。
## 初始状态：根据当前 viewport 尺寸计算，地图上下边不露出画框，水平与垂直居中（横屏/竖屏通用）。

signal view_changed

const MAP_WIDTH := 4000
const MAP_HEIGHT := 2000

var view_center: Vector2 = Vector2(500, 350)
var zoom: float = 1.0
var max_zoom: float = 5.0
var _dragging := false
# iOS pinch zoom: no MagnifyGesture, use two-finger distance
var _touch_points: Dictionary = {}  # int index -> Vector2 position
var _last_pinch_distance: float = -1.0
var _last_pinch_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	call_deferred("_apply_initial_state")

func _get_view_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280, 720)
	return vp.get_visible_rect().size

## 初始视角：中心在欧亚中段 (lon=75, lat=38)，zoom 为最远视野的 1.3 倍。
func _apply_initial_state() -> void:
	var view_size: Vector2 = _get_view_size()
	# 初始中心：欧亚大陆中段 lon=75, lat=38 -> 世界坐标
	view_center.x = (75.0 + 180.0) / 360.0 * float(MAP_WIDTH)
	view_center.y = (90.0 - 38.0) / 180.0 * float(MAP_HEIGHT)
	var min_allowed: float = _vertical_min_zoom(view_size)
	zoom = min_allowed * 1.3
	view_changed.emit()

func _map_top_y(center_y: float, z: float, view_size: Vector2) -> float:
	return view_size.y / 2.0 + (0.0 - center_y) * z

func _map_bottom_y(center_y: float, z: float, view_size: Vector2) -> float:
	return view_size.y / 2.0 + (float(MAP_HEIGHT) - center_y) * z

func _apply_view_center_bounds() -> void:
	var view_size: Vector2 = _get_view_size()
	var top_y: float = _map_top_y(view_center.y, zoom, view_size)
	var bottom_y: float = _map_bottom_y(view_center.y, zoom, view_size)
	if top_y > 0.0:
		view_center.y = view_size.y / (2.0 * zoom)
	elif bottom_y < view_size.y:
		view_center.y = float(MAP_HEIGHT) - view_size.y / (2.0 * zoom)
	while view_center.x < 0.0:
		view_center.x += float(MAP_WIDTH)
	while view_center.x >= float(MAP_WIDTH):
		view_center.x -= float(MAP_WIDTH)

func _has_multitouch() -> bool:
	return _touch_points.size() >= 2

## iOS: process screen touch (called from world_map when it receives ScreenTouch).
func process_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
	else:
		_touch_points.erase(event.index)
	if _touch_points.size() < 2:
		_last_pinch_distance = -1.0
		_last_pinch_center = Vector2.ZERO

## iOS: process screen drag，基于旧/新两指状态一次性更新 zoom 与 view_center。
func process_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_points[event.index] = event.position
	if _touch_points.size() == 2:
		var keys: Array = _touch_points.keys()
		var p1: Vector2 = _touch_points[keys[0]]
		var p2: Vector2 = _touch_points[keys[1]]
		var c2: Vector2 = (p1 + p2) / 2.0
		var d2: float = p1.distance_to(p2)
		# 第一帧：仅记录，不做缩放/平移
		if _last_pinch_distance <= 0.0:
			_last_pinch_distance = d2
			_last_pinch_center = c2
			return
		var c1: Vector2 = _last_pinch_center
		var d1: float = _last_pinch_distance
		# 计算锚点（旧视图下，c1 对应的世界坐标）
		var view_size: Vector2 = _get_view_size()
		var viewport_center: Vector2 = view_size / 2.0
		var anchor_world: Vector2 = view_center + (c1 - viewport_center) / zoom
		# 新 zoom：按距离比例缩放，并套用现有 zoom 边界（含 vertical min）
		var raw_factor: float = d2 / d1 if d1 != 0.0 else 1.0
		var target_zoom: float = zoom * raw_factor
		var min_allowed: float = _vertical_min_zoom(view_size)
		var zoom_new: float = clampf(target_zoom, min_allowed, max_zoom)
		# 新视图中心：保证 anchor_world 依然映射到新屏幕中点 c2
		var view_center_new: Vector2 = anchor_world - (c2 - viewport_center) / zoom_new
		zoom = zoom_new
		view_center = view_center_new
		_apply_view_center_bounds()
		_last_pinch_center = c2
		_last_pinch_distance = d2
		view_changed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
			else:
				_dragging = false
	if event is InputEventMouseMotion and _dragging:
		if _has_multitouch():
			return
		var mm: InputEventMouseMotion = event
		var view_size: Vector2 = _get_view_size()
		# Drag is in screen pixels; convert to world displacement so map follows finger 1:1
		var world_drag: Vector2 = mm.relative / zoom
		var new_center: Vector2 = view_center - world_drag
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

## Pan by screen-space delta (e.g. Mac PanGesture). Uses delta/zoom, applies vertical bounds and X wrap.
func pan_by_screen_delta(delta: Vector2) -> void:
	view_center -= delta / zoom
	_apply_view_center_bounds()
	view_changed.emit()

## 最小 zoom：横向最远只看到约 90°（世界 1/4 宽），且垂直不露黑边。
func _vertical_min_zoom(view_size: Vector2) -> float:
	var horizontal_min: float = view_size.x * 4.0 / float(MAP_WIDTH)
	var frame_half: float = view_size.y / 2.0
	var top_dist: float = maxf(view_center.y, 0.0001)
	var bottom_dist: float = maxf(float(MAP_HEIGHT) - view_center.y, 0.0001)
	var z_top: float = frame_half / top_dist
	var z_bottom: float = frame_half / bottom_dist
	var vertical_needed: float = maxf(z_top, z_bottom)
	return maxf(horizontal_min, vertical_needed)

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
