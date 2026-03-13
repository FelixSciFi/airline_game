extends Node2D
## 静态地图层：地图外浅灰、Ocean、Land、Lakes、Rivers。
## 刷新节奏与主地图一致，不做冻结优化。

var _map_view: Node = null

const OCEAN_COLOR := Color(0.28, 0.45, 0.58, 1.0)
const LAND_COLOR := Color(0.82, 0.78, 0.64, 1.0)
const LAKE_COLOR := Color(0.42, 0.62, 0.88, 1.0)
const RIVER_ZOOM_REGIONAL := 3.2
const RIVER_ZOOM_MINOR := 4.0

func set_map_view(mv: Node) -> void:
	_map_view = mv

func _get_view_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280, 720)
	return vp.get_visible_rect().size

func _draw() -> void:
	if _map_view == null:
		return
	var wm: Node = get_parent()
	if wm == null or not wm.has_method("get_land_polygons") or not wm.has_method("get_lake_polygons") or not wm.has_method("get_river_lines"):
		return
	var view_size: Vector2 = _get_view_size()
	var map_w: int = _map_view.get_map_width()
	var rect_screen := Rect2(Vector2.ZERO, view_size.round())
	draw_rect(rect_screen, Color(0.45, 0.45, 0.48, 1))
	draw_rect(rect_screen, OCEAN_COLOR)
	var zoom: float = _map_view.get_zoom()
	var view_center: Vector2 = _map_view.get_view_center()
	var visible_world_width: float = view_size.x / zoom
	var visible_world_height: float = view_size.y / zoom
	var world_rect: Rect2 = Rect2(
		Vector2(view_center.x - visible_world_width / 2.0, view_center.y - visible_world_height / 2.0),
		Vector2(visible_world_width, visible_world_height)
	)
	world_rect = world_rect.grow(150.0)
	var land_polygons: Array = wm.get_land_polygons()
	var lake_polygons: Array = wm.get_lake_polygons()
	var river_lines: Array = wm.get_river_lines()
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	for offset_x in offsets_x:
		for poly_world in land_polygons:
			var bbox: Rect2 = poly_world["bbox"]
			var shifted_bbox: Rect2 = Rect2(bbox.position + Vector2(offset_x, 0), bbox.size)
			if not shifted_bbox.intersects(world_rect):
				continue
			var land_screen: PackedVector2Array = []
			for p in poly_world["points"]:
				land_screen.append(_map_view.world_to_screen(Vector2(p.x + offset_x, p.y), view_size))
			if land_screen.size() >= 3:
				draw_colored_polygon(land_screen, LAND_COLOR)
		for poly_world in lake_polygons:
			var bbox_lake: Rect2 = poly_world["bbox"]
			var shifted_bbox_lake: Rect2 = Rect2(bbox_lake.position + Vector2(offset_x, 0), bbox_lake.size)
			if not shifted_bbox_lake.intersects(world_rect):
				continue
			var lake_screen: PackedVector2Array = []
			for p in poly_world["points"]:
				lake_screen.append(_map_view.world_to_screen(Vector2(p.x + offset_x, p.y), view_size))
			if lake_screen.size() >= 3:
				draw_colored_polygon(lake_screen, LAKE_COLOR)
		for river in river_lines:
			var bbox_river: Rect2 = river["bbox"]
			var shifted_bbox_river: Rect2 = Rect2(bbox_river.position + Vector2(offset_x, 0), bbox_river.size)
			if not shifted_bbox_river.intersects(world_rect):
				continue
			var zoom_river: float = _map_view.get_zoom()
			var sr: int = int(river.get("scalerank", 99))
			if sr <= 2:
				pass
			elif sr <= 4:
				if zoom_river < RIVER_ZOOM_REGIONAL:
					continue
			else:
				if zoom_river < RIVER_ZOOM_MINOR:
					continue
			var pts: PackedVector2Array = []
			for p in river["points"]:
				pts.append(_map_view.world_to_screen(Vector2(p.x + offset_x, p.y), view_size))
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.45, 0.65, 0.9), 1.5)
