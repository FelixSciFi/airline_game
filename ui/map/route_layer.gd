extends Node2D
## 仅负责绘制航线：规划线（origin→selected）与 active_flights 的飞行线。
## 使用本地世界坐标绘制，由 world_map 通过 position/scale 对齐视图。

var _map_view: Node = null

func set_map_view(mv: Node) -> void:
	_map_view = mv

func _draw() -> void:
	if _map_view == null:
		return
	var wm: Node = get_parent()
	if wm == null or not wm.has_method("get_city_world_pos") or not wm.has_method("get_active_flights"):
		return
	var map_w: int = _map_view.get_map_width()
	var zoom: float = _map_view.get_zoom()
	var inv_zoom: float = 1.0 / zoom if zoom > 0.0001 else 1.0
	# 规划线：DESTINATION MODE 下 origin → selected（世界坐标 + 三副本）
	var selecting_destination: bool = wm.get("selecting_destination")
	var origin_city_id: String = wm.get("origin_city_id")
	var selected_city_id: String = wm.get("selected_city_id")
	if selecting_destination and origin_city_id != "" and selected_city_id != "":
		var origin_world: Vector2 = wm.get_city_world_pos(origin_city_id)
		var dest_world: Vector2 = wm.get_city_world_pos(selected_city_id)
		var dx_preview: float = dest_world.x - origin_world.x
		var dest_x_adj: float = dest_world.x
		if dx_preview > float(map_w) / 2.0:
			dest_x_adj -= float(map_w)
		elif dx_preview < -float(map_w) / 2.0:
			dest_x_adj += float(map_w)
		var adjusted_dest_world: Vector2 = Vector2(dest_x_adj, dest_world.y)
		var line_color := Color(1.0, 1.0, 0.0, 0.9)
		var line_offsets_x: Array = [0.0, -float(map_w), float(map_w)]
		for line_off in line_offsets_x:
			var o_off: Vector2 = origin_world + Vector2(line_off, 0.0)
			var d_off: Vector2 = adjusted_dest_world + Vector2(line_off, 0.0)
			var dir_world: Vector2 = (d_off - o_off).normalized()
			var perp_world: Vector2 = Vector2(-dir_world.y, dir_world.x) * inv_zoom
			draw_line(o_off + perp_world, d_off + perp_world, line_color)
			draw_line(o_off, d_off, line_color)
			draw_line(o_off - perp_world, d_off - perp_world, line_color)
	# active_flights 飞行线（世界坐标 + 三副本）
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
		var dest_x_line: float = dest_world_f.x
		var dx_line: float = dest_x_line - origin_world_f.x
		if dx_line > float(map_w) / 2.0:
			dest_x_line -= float(map_w)
		elif dx_line < -float(map_w) / 2.0:
			dest_x_line += float(map_w)
		var adjusted_dest_line: Vector2 = Vector2(dest_x_line, dest_world_f.y)
		var flight_line_offsets: Array = [0.0, -float(map_w), float(map_w)]
		for line_off in flight_line_offsets:
			var o_off: Vector2 = origin_world_f + Vector2(line_off, 0.0)
			var d_off: Vector2 = adjusted_dest_line + Vector2(line_off, 0.0)
			draw_line(o_off, d_off, Color(0.7, 0.8, 1.0, 0.9), 2.0)
