extends Node2D
## 负责绘制城市图标（圆点 + 白描边）与城市名称，三副本 offset_x。
## 城市点击按钮仍由 world_map 的 _cities_layer 管理。

var _map_view: Node = null

const CITY_ICON_FILL := Color(0.88, 0.38, 0.22, 1.0)
const CITY_ICON_STROKE := Color(1, 1, 1, 0.95)
const CITY_ICON_STROKE_WIDTH := 1.2
const CITY_ICON_RADIUS_CLAMP_MIN := 3.5
const CITY_ICON_RADIUS_CLAMP_MAX := 12.0
## 与项目现有 Label 一致
const CITY_NAME_FONT_SIZE := 36
## 中景 / 近景：沿用项目已定分级，不新写字号规则
const CITY_NAME_ZOOM_MEDIUM := 1.5
const CITY_NAME_ZOOM_SMALL := 2.5

func set_map_view(mv: Node) -> void:
	_map_view = mv

func _get_view_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280, 720)
	return vp.get_visible_rect().size

func _should_show_city_name(city: Dictionary, zoom: float) -> bool:
	var level: String = str(city.get("airport_level", city.get("base_level", "small")))
	match level:
		"huge", "large":
			return true
		"medium":
			return zoom >= CITY_NAME_ZOOM_MEDIUM
		_:
			return zoom >= CITY_NAME_ZOOM_SMALL

func _draw() -> void:
	if _map_view == null:
		return
	var wm: Node = get_parent()
	if wm == null or not wm.has_method("get_cities"):
		return
	var cities: Array = wm.get_cities()
	if cities.is_empty():
		return
	var view_size: Vector2 = _get_view_size()
	var map_w: int = _map_view.get_map_width()
	var zoom: float = _map_view.get_zoom()
	var font: Font = ThemeDB.fallback_font
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	for offset_x in offsets_x:
		for city in cities:
			var wx: float = float(city.get("x", 0))
			var wy: float = float(city.get("y", 0))
			var screen_pos: Vector2 = _map_view.world_to_screen(Vector2(wx + offset_x, wy), view_size)
			var base_radius: float = wm.get_city_base_radius(city)
			var visual_scale: float = wm.get_city_visual_scale()
			var radius: float = base_radius * visual_scale
			radius = clampf(radius, CITY_ICON_RADIUS_CLAMP_MIN, CITY_ICON_RADIUS_CLAMP_MAX)
			draw_circle(screen_pos, radius + CITY_ICON_STROKE_WIDTH, CITY_ICON_STROKE)
			draw_circle(screen_pos, radius, CITY_ICON_FILL)
			if _should_show_city_name(city, zoom):
				var name_str: String = str(city.get("name", ""))
				if name_str.is_empty():
					continue
				var text_offset: Vector2 = Vector2(radius + 4, -radius - 2)
				var text_pos: Vector2 = (screen_pos + text_offset).round()
				draw_string(font, text_pos, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, CITY_NAME_FONT_SIZE)
