extends Node2D
## 仅负责绘制飞行中的飞机图标（三角形）。
## 使用本地世界坐标绘制，由 world_map 通过 position/scale 对齐视图。

var _map_view: Node = null

func set_map_view(mv: Node) -> void:
	_map_view = mv

func _process(_delta: float) -> void:
	if _map_view == null:
		return
	if _map_view.is_dragging():
		return
	var wm: Node = get_parent()
	if wm == null or not wm.has_method("get_active_flights"):
		return
	var flights: Array = wm.get_active_flights()
	if flights != null and flights.size() > 0:
		queue_redraw()

func _draw() -> void:
	if _map_view == null:
		return
	var wm: Node = get_parent()
	if wm == null or not wm.has_method("get_city_world_pos") or not wm.has_method("get_active_flights"):
		return
	var map_w: int = _map_view.get_map_width()
	var zoom: float = _map_view.get_zoom()
	var size_world: float = 36.0 / zoom if zoom > 0.0001 else 36.0
	var flights: Array = wm.get_active_flights()
	for flight in flights:
		var origin_id: String = str(flight.get("origin", ""))
		var dest_id: String = str(flight.get("destination", ""))
		if origin_id == "" or dest_id == "":
			continue
		var origin_world_f: Vector2 = wm.get_city_world_pos(origin_id)
		var dest_world_f: Vector2 = wm.get_city_world_pos(dest_id)
		var start_time: int = int(flight.get("start_time", 0))
		var duration: int = int(flight.get("duration", 1))
		if duration <= 0:
			continue
		var now: int = Time.get_ticks_msec()
		var progress: float = float(now - start_time) / float(duration)
		progress = clampf(progress, 0.0, 1.0)
		if progress >= 1.0:
			continue
		var origin_x: float = origin_world_f.x
		var origin_y: float = origin_world_f.y
		var dest_x: float = dest_world_f.x
		var dest_y: float = dest_world_f.y
		var dx: float = dest_x - origin_x
		if dx > float(map_w) / 2.0:
			dest_x -= float(map_w)
		elif dx < -float(map_w) / 2.0:
			dest_x += float(map_w)
		var plane_x: float = lerpf(origin_x, dest_x, progress)
		var plane_y: float = lerpf(origin_y, dest_y, progress)
		if plane_x < 0.0:
			plane_x += float(map_w)
		if plane_x >= float(map_w):
			plane_x -= float(map_w)
		var dest_adj_world: Vector2 = Vector2(dest_x, dest_y)
		var plane_center_world: Vector2 = Vector2(plane_x, plane_y)
		var dir_f: Vector2 = (dest_adj_world - plane_center_world).normalized()
		if dir_f.length() < 0.0001:
			dir_f = Vector2(1, 0)
		var perp_f := Vector2(-dir_f.y, dir_f.x)
		var plane_offsets_x: Array = [0.0, -float(map_w), float(map_w)]
		for offset_x in plane_offsets_x:
			var center_world: Vector2 = Vector2(plane_x + offset_x, plane_y)
			var nose: Vector2 = center_world + dir_f * size_world
			var left: Vector2 = center_world - dir_f * size_world * 0.3 + perp_f * size_world * 0.6
			var right: Vector2 = center_world - dir_f * size_world * 0.3 - perp_f * size_world * 0.6
			var tri := PackedVector2Array([nose, left, right])
			draw_colored_polygon(tri, Color(1, 1, 1, 0.95))
