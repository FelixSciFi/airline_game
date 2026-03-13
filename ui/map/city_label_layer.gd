extends Node2D
## 城市名称层：使用 screen-space 绘制，避免跟随 scale 导致 iOS 上发糊。
## 从 world_map 取 cities，用 map_view.world_to_screen 计算文字位置。

var _map_view: Node = null

const CITY_NAME_FONT_SIZE := 36
const CITY_NAME_ZOOM_MEDIUM := 1.5
const CITY_NAME_ZOOM_SMALL := 2.5
const CITY_ICON_RADIUS_CLAMP_MIN := 3.5
const CITY_ICON_RADIUS_CLAMP_MAX := 12.0

func set_map_view(mv: Node) -> void:
	_map_view = mv

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
	if wm == null or not wm.has_method("get_cities") or not wm.has_method("get_city_base_radius") or not wm.has_method("get_city_visual_scale"):
		return
	var cities: Array = wm.get_cities()
	if cities.is_empty():
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var map_w: int = _map_view.get_map_width()
	var zoom: float = _map_view.get_zoom()
	var font: Font = ThemeDB.fallback_font
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	for offset_x in offsets_x:
		for city in cities:
			var wx: float = float(city.get("x", 0))
			var wy: float = float(city.get("y", 0))
			var center_world: Vector2 = Vector2(wx + offset_x, wy)
			if not _should_show_city_name(city, zoom):
				continue
			var name_str: String = str(city.get("name", ""))
			if name_str.is_empty():
				continue
			var base_radius: float = wm.get_city_base_radius(city)
			var visual_scale: float = wm.get_city_visual_scale()
			var radius_screen: float = base_radius * visual_scale
			radius_screen = clampf(radius_screen, CITY_ICON_RADIUS_CLAMP_MIN, CITY_ICON_RADIUS_CLAMP_MAX)
			var screen_center: Vector2 = _map_view.world_to_screen(center_world, view_size)
			var text_offset: Vector2 = Vector2(radius_screen + 4, -radius_screen - 2)
			var text_pos: Vector2 = (screen_center + text_offset).round()
			draw_string(font, text_pos, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, CITY_NAME_FONT_SIZE)
