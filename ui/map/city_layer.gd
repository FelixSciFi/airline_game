extends Node2D
## 负责绘制城市图标（圆点 + 白描边），三副本 offset_x。城市名称由 CityLabelLayer 绘制。
## 使用本地世界坐标绘制，由 world_map 通过 position/scale 对齐视图。

var _map_view: Node = null

const CITY_ICON_FILL := Color(0.88, 0.38, 0.22, 1.0)
const CITY_ICON_STROKE := Color(1, 1, 1, 0.95)
const CITY_ICON_STROKE_WIDTH := 1.2
const CITY_ICON_RADIUS_CLAMP_MIN := 3.5
const CITY_ICON_RADIUS_CLAMP_MAX := 12.0

func set_map_view(mv: Node) -> void:
	_map_view = mv

func _draw() -> void:
	if _map_view == null:
		return
	var wm: Node = get_parent()
	if wm == null or not wm.has_method("get_cities"):
		return
	var cities: Array = wm.get_cities()
	if cities.is_empty():
		return
	var map_w: int = _map_view.get_map_width()
	var zoom: float = _map_view.get_zoom()
	var inv_zoom: float = 1.0 / zoom if zoom > 0.0001 else 1.0
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	for offset_x in offsets_x:
		for city in cities:
			var wx: float = float(city.get("x", 0))
			var wy: float = float(city.get("y", 0))
			var center_world: Vector2 = Vector2(wx + offset_x, wy)
			var base_radius: float = wm.get_city_base_radius(city)
			var visual_scale: float = wm.get_city_visual_scale()
			var radius_screen: float = base_radius * visual_scale
			radius_screen = clampf(radius_screen, CITY_ICON_RADIUS_CLAMP_MIN, CITY_ICON_RADIUS_CLAMP_MAX)
			var radius_world: float = radius_screen * inv_zoom
			var stroke_world: float = CITY_ICON_STROKE_WIDTH * inv_zoom
			draw_circle(center_world, radius_world + stroke_world, CITY_ICON_STROKE)
			draw_circle(center_world, radius_world, CITY_ICON_FILL)
