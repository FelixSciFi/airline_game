extends Control

const AircraftDeploySystem = preload("res://systems/aircraft_deploy_system.gd")
const LAND_GEOJSON_PATH := "res://data/map/ne_110m_land.json"
const LAKES_GEOJSON_PATH := "res://data/map/ne_110m_lakes.json"
const RIVERS_GEOJSON_PATH := "res://data/map/ne_50m_rivers_lake_centerlines.json"
const OCEAN_COLOR := Color(0.28, 0.45, 0.58, 1.0)
const LAND_COLOR := Color(0.82, 0.78, 0.64, 1.0)
const LAKE_COLOR := Color(0.42, 0.62, 0.88, 1.0)
const AIRCRAFT_ICON_OFFSET := Vector2(-6, -6)
const CITY_PICK_RADIUS_PADDING := 6.0
const CITY_PICK_RADIUS_MIN := 10.0
const AIRCRAFT_STATUS_GROUNDED := "grounded"
const DISTANCE_TIME_FACTOR := 1000.0
const CITY_ICON_FILL := Color(0.88, 0.38, 0.22, 1.0)
const CITY_ICON_STROKE := Color(1, 1, 1, 0.95)
const CITY_ICON_STROKE_WIDTH := 1.2
const CITY_ICON_RADIUS_CLAMP_MIN := 3.5
const CITY_ICON_RADIUS_CLAMP_MAX := 12.0
## 河流分级显示：zoom 低于阈值时不画该级。固定阈值（玩家 zoom 约 1.28～5.0）
const RIVER_ZOOM_REGIONAL := 3.2
const RIVER_ZOOM_MINOR := 4.0

var _cities_layer: Node2D
var _aircraft_layer: Node2D
var _route_layer: Node2D
var _flying_aircraft_layer: Node2D
var _city_layer: Node2D
var _static_map_layer: Node2D
var _cities: Array = []
var _map_view: Node = null
var _player_state: Node = null
var _main_menu_panel: Control
var _bill_panel: Control
var _shop_panel: Control
var _hangar_panel: Control
var _airport_panel: Control
var _pending_deploy_aircraft_id: String = ""
var _deploy_hint_label: Label = null
var selecting_destination := false
var selecting_plane_id: String = ""
var selected_city_id: String = ""
var origin_city_id: String = ""
var _destination_hint_label: Label = null
var _destination_cancel_btn: Button = null
var _start_flight_btn: Button = null
# Natural Earth 陆地缓存：每个元素为世界坐标下的一个 polygon（PackedVector2Array），只解析一次
var _land_polygons: Array = []
var _land_loaded: bool = false
# 50m 河流线缓存：每条为世界坐标点数组 PackedVector2Array，只解析一次
var _river_lines: Array = []
var _river_loaded: bool = false
# 湖泊 polygon 缓存：每个元素为世界坐标 PackedVector2Array，只解析一次
var _lake_polygons: Array = []
var _lake_loaded: bool = false

func _lon_lat_to_world(lon: float, lat: float, map_w: int, map_h: int) -> Vector2:
	var world_x: float = (lon + 180.0) / 360.0 * float(map_w)
	var world_y: float = (90.0 - lat) / 180.0 * float(map_h)
	return Vector2(world_x, world_y)

func _compute_bbox(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2(0, 0, 0, 0)
	var min_x: float = points[0].x
	var max_x: float = points[0].x
	var min_y: float = points[0].y
	var max_y: float = points[0].y
	for i in range(1, points.size()):
		min_x = minf(min_x, points[i].x)
		max_x = maxf(max_x, points[i].x)
		min_y = minf(min_y, points[i].y)
		max_y = maxf(max_y, points[i].y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _parse_ring_to_world(outer: Array, map_w: int, map_h: int) -> PackedVector2Array:
	var ring: PackedVector2Array = []
	for pt in outer:
		if typeof(pt) != TYPE_ARRAY or pt.size() < 2:
			continue
		var lon: float = float(pt[0])
		var lat: float = float(pt[1])
		ring.append(_lon_lat_to_world(lon, lat, map_w, map_h))
	return ring

## 只执行一次：读取 GeoJSON，解析为世界坐标 polygon 并存入 _land_polygons。
func _load_land_polygons() -> void:
	if _land_loaded:
		return
	_land_polygons.clear()
	if _map_view == null:
		return
	var map_w: int = _map_view.get_map_width()
	var map_h: int = _map_view.get_map_height()
	var file := FileAccess.open(LAND_GEOJSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("Land GeoJSON not found: " + LAND_GEOJSON_PATH)
		return
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_warning("Land GeoJSON parse error: " + json.get_error_message())
		return
	var data = json.get_data()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return
	var features = data.get("features", [])
	if typeof(features) != TYPE_ARRAY:
		return
	for feature in features:
		if typeof(feature) != TYPE_DICTIONARY:
			continue
		var geom = feature.get("geometry", null)
		if geom == null or typeof(geom) != TYPE_DICTIONARY:
			continue
		var gtype = geom.get("type", "")
		var coords = geom.get("coordinates", null)
		if coords == null or typeof(coords) != TYPE_ARRAY:
			continue
		if gtype == "Polygon":
			var outer_ring = coords[0]
			if typeof(outer_ring) != TYPE_ARRAY or outer_ring.is_empty():
				continue
			var ring: PackedVector2Array = _parse_ring_to_world(outer_ring, map_w, map_h)
			if ring.size() >= 3:
				_land_polygons.append({"points": ring, "bbox": _compute_bbox(ring)})
		elif gtype == "MultiPolygon":
			for poly in coords:
				if typeof(poly) != TYPE_ARRAY or poly.is_empty():
					continue
				var outer_ring = poly[0]
				if typeof(outer_ring) != TYPE_ARRAY or outer_ring.is_empty():
					continue
				var ring: PackedVector2Array = _parse_ring_to_world(outer_ring, map_w, map_h)
				if ring.size() >= 3:
					_land_polygons.append({"points": ring, "bbox": _compute_bbox(ring)})
	_land_loaded = true
	print("Land polygons cached: ", _land_polygons.size())

func _parse_line_to_world(pts: Array, map_w: int, map_h: int) -> PackedVector2Array:
	var line: PackedVector2Array = []
	for pt in pts:
		if typeof(pt) != TYPE_ARRAY or pt.size() < 2:
			continue
		var lon: float = float(pt[0])
		var lat: float = float(pt[1])
		line.append(_lon_lat_to_world(lon, lat, map_w, map_h))
	return line

## 只执行一次：读取河流 GeoJSON，解析为世界坐标线并存入 _river_lines。支持 LineString / MultiLineString。
func _load_river_lines() -> void:
	if _river_loaded:
		return
	_river_lines.clear()
	if _map_view == null:
		return
	var map_w: int = _map_view.get_map_width()
	var map_h: int = _map_view.get_map_height()
	var file := FileAccess.open(RIVERS_GEOJSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("Rivers GeoJSON not found: " + RIVERS_GEOJSON_PATH)
		return
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_warning("Rivers GeoJSON parse error: " + json.get_error_message())
		return
	var data = json.get_data()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return
	var features = data.get("features", [])
	if typeof(features) != TYPE_ARRAY:
		return
	for feature in features:
		if typeof(feature) != TYPE_DICTIONARY:
			continue
		var props = feature.get("properties", null)
		if typeof(props) != TYPE_DICTIONARY:
			continue
		var featurecla_val: String = str(props.get("featurecla", ""))
		if featurecla_val != "River":
			continue
		var geom = feature.get("geometry", null)
		if geom == null or typeof(geom) != TYPE_DICTIONARY:
			continue
		var gtype = geom.get("type", "")
		var coords = geom.get("coordinates", null)
		if coords == null or typeof(coords) != TYPE_ARRAY:
			continue
		var scalerank_val = props.get("scalerank", 6)
		var scalerank: int = int(scalerank_val) if scalerank_val != null else 6
		if gtype == "LineString":
			var line_pts: PackedVector2Array = _parse_line_to_world(coords, map_w, map_h)
			if line_pts.size() >= 2:
				_river_lines.append({"points": line_pts, "bbox": _compute_bbox(line_pts), "scalerank": scalerank, "featurecla": "River"})
		elif gtype == "MultiLineString":
			for segment in coords:
				if typeof(segment) != TYPE_ARRAY or segment.size() < 2:
					continue
				var line_pts: PackedVector2Array = _parse_line_to_world(segment, map_w, map_h)
				if line_pts.size() >= 2:
					_river_lines.append({"points": line_pts, "bbox": _compute_bbox(line_pts), "scalerank": scalerank, "featurecla": "River"})
	_river_loaded = true
	print("River lines cached: ", _river_lines.size())

## 只执行一次：读取湖泊 GeoJSON，解析为世界坐标 polygon 并存入 _lake_polygons。支持 Polygon / MultiPolygon。
func _load_lake_polygons() -> void:
	if _lake_loaded:
		return
	_lake_polygons.clear()
	if _map_view == null:
		return
	var map_w: int = _map_view.get_map_width()
	var map_h: int = _map_view.get_map_height()
	var file := FileAccess.open(LAKES_GEOJSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("Lakes GeoJSON not found: " + LAKES_GEOJSON_PATH)
		return
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_warning("Lakes GeoJSON parse error: " + json.get_error_message())
		return
	var data = json.get_data()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return
	var features = data.get("features", [])
	if typeof(features) != TYPE_ARRAY:
		return
	for feature in features:
		if typeof(feature) != TYPE_DICTIONARY:
			continue
		var geom = feature.get("geometry", null)
		if geom == null or typeof(geom) != TYPE_DICTIONARY:
			continue
		var gtype = geom.get("type", "")
		var coords = geom.get("coordinates", null)
		if coords == null or typeof(coords) != TYPE_ARRAY:
			continue
		if gtype == "Polygon":
			var outer_ring = coords[0]
			if typeof(outer_ring) != TYPE_ARRAY or outer_ring.is_empty():
				continue
			var ring: PackedVector2Array = _parse_ring_to_world(outer_ring, map_w, map_h)
			if ring.size() >= 3:
				_lake_polygons.append({"points": ring, "bbox": _compute_bbox(ring)})
		elif gtype == "MultiPolygon":
			for poly in coords:
				if typeof(poly) != TYPE_ARRAY or poly.is_empty():
					continue
				var outer_ring = poly[0]
				if typeof(outer_ring) != TYPE_ARRAY or outer_ring.is_empty():
					continue
				var ring: PackedVector2Array = _parse_ring_to_world(outer_ring, map_w, map_h)
				if ring.size() >= 3:
					_lake_polygons.append({"points": ring, "bbox": _compute_bbox(ring)})
	_lake_loaded = true
	print("Lake polygons cached: ", _lake_polygons.size())

func _get_active_flights() -> Array:
	var parent := get_parent()
	if parent == null:
		return []
	var gs: Node = parent.get_node_or_null("GameState")
	if gs == null:
		return []
	return gs.active_flights

func get_active_flights() -> Array:
	return _get_active_flights()

func get_city_world_pos(city_id: String) -> Vector2:
	return _get_city_world_pos(city_id)

func get_cities() -> Array:
	return _cities

func get_city_base_radius(city: Dictionary) -> float:
	return _get_city_base_radius(city)

func get_city_visual_scale() -> float:
	return _get_city_visual_scale()

func get_land_polygons() -> Array:
	return _land_polygons

func get_lake_polygons() -> Array:
	return _lake_polygons

func get_river_lines() -> Array:
	return _river_lines

func _ready() -> void:
	_cities_layer = $CitiesLayer
	_static_map_layer = preload("res://ui/map/static_map_layer.gd").new()
	_static_map_layer.name = "StaticMapLayer"
	add_child(_static_map_layer)
	_aircraft_layer = Node2D.new()
	_aircraft_layer.name = "AircraftLayer"
	add_child(_aircraft_layer)
	_route_layer = preload("res://ui/map/route_layer.gd").new()
	_route_layer.name = "RouteLayer"
	add_child(_route_layer)
	_flying_aircraft_layer = preload("res://ui/map/aircraft_layer.gd").new()
	_flying_aircraft_layer.name = "FlyingAircraftLayer"
	add_child(_flying_aircraft_layer)
	_city_layer = preload("res://ui/map/city_layer.gd").new()
	_city_layer.name = "CityLayer"
	add_child(_city_layer)
	_map_view = preload("res://ui/map/map_view.gd").new()
	_map_view.name = "MapView"
	add_child(_map_view)
	_route_layer.set_map_view(_map_view)
	_flying_aircraft_layer.set_map_view(_map_view)
	_city_layer.set_map_view(_map_view)
	_static_map_layer.set_map_view(_map_view)
	move_child(_static_map_layer, 0)
	_map_view.view_changed.connect(_on_map_view_changed)
	_sync_route_layer_transform()
	_sync_aircraft_layer_transform()
	_sync_city_layer_transform()
	$ColorRect.visible = false
	queue_redraw()
	if _static_map_layer != null:
		_static_map_layer.queue_redraw()
	_deploy_hint_label = Label.new()
	_deploy_hint_label.name = "DeployHintLabel"
	_deploy_hint_label.add_theme_font_size_override("font_size", 36)
	_deploy_hint_label.visible = false
	add_child(_deploy_hint_label)
	_destination_hint_label = Label.new()
	_destination_hint_label.name = "DestinationHintLabel"
	_destination_hint_label.text = "Select Destination City"
	_destination_hint_label.add_theme_font_size_override("font_size", 36)
	_destination_hint_label.visible = false
	add_child(_destination_hint_label)
	_destination_cancel_btn = Button.new()
	_destination_cancel_btn.name = "DestinationCancelButton"
	_destination_cancel_btn.text = "Cancel"
	_destination_cancel_btn.add_theme_font_size_override("font_size", 44)
	_destination_cancel_btn.visible = false
	_destination_cancel_btn.pressed.connect(_on_destination_cancel_pressed)
	add_child(_destination_cancel_btn)
	_start_flight_btn = Button.new()
	_start_flight_btn.name = "StartFlightButton"
	_start_flight_btn.text = "Depart"
	_start_flight_btn.add_theme_font_size_override("font_size", 44)
	_start_flight_btn.visible = false
	_start_flight_btn.pressed.connect(_on_start_pressed)
	add_child(_start_flight_btn)
	_ensure_game_state()
	# Ensure we fill the viewport when parent is Node2D（延后设置避免与 anchor 冲突）
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_apply_viewport_size")
	_load_land_polygons()
	_load_lake_polygons()
	_load_river_lines()

func _apply_viewport_size() -> void:
	var rect := get_viewport().get_visible_rect()
	set_deferred("size", rect.size)
	set_deferred("position", Vector2.ZERO)

	_player_state = get_parent().get_node_or_null("PlayerState")
	var player_state: Node = _player_state

	_main_menu_panel = preload("res://ui/main_menu/main_menu_panel.tscn").instantiate()
	if player_state != null:
		_main_menu_panel.set_player_state(player_state)
	add_child(_main_menu_panel)
	_main_menu_panel.visible = false
	_main_menu_panel.open_bills.connect(_on_open_bills)
	_main_menu_panel.open_shop.connect(_on_open_shop)
	_main_menu_panel.open_hangar.connect(_on_open_hangar)
	_main_menu_panel.close_menu.connect(_on_close_menu)

	_bill_panel = preload("res://ui/finance/bill_panel.tscn").instantiate()
	if player_state != null:
		_bill_panel.set_player_state(player_state)
	add_child(_bill_panel)
	_bill_panel.visible = false
	_bill_panel.back_to_menu.connect(_on_bill_back_to_menu)

	_shop_panel = preload("res://ui/shop/shop_panel.tscn").instantiate()
	if player_state != null:
		_shop_panel.set_player_state(player_state)
	add_child(_shop_panel)
	_shop_panel.visible = false
	_shop_panel.back_to_menu.connect(_on_shop_back_to_menu)

	_hangar_panel = preload("res://ui/hangar/hangar_panel.tscn").instantiate()
	if player_state != null:
		_hangar_panel.set_player_state(player_state)
	var game_world: Node = get_parent()
	if game_world != null:
		_hangar_panel.set_game_world(game_world)
	add_child(_hangar_panel)
	_hangar_panel.visible = false
	_hangar_panel.back_to_menu.connect(_on_hangar_back_to_menu)
	_hangar_panel.request_deploy_mode.connect(_on_request_deploy_mode)

	_airport_panel = preload("res://ui/airport/airport_panel.tscn").instantiate()
	if game_world != null:
		_airport_panel.set_game_world(game_world)
	add_child(_airport_panel)
	_airport_panel.visible = false
	_airport_panel.back_to_map.connect(_on_airport_back_to_map)
	_airport_panel.aircraft_recalled.connect(_on_aircraft_recalled)

	$MenuButton.pressed.connect(_on_menu_pressed)

func _ensure_game_state() -> void:
	var parent := get_parent()
	if parent.get_node_or_null("GameState") == null:
		var ScriptClass: GDScript = load("res://core/game_state.gd") as GDScript
		var gs: Node = ScriptClass.new()
		gs.name = "GameState"
		parent.add_child.call_deferred(gs)

func _on_start_pressed() -> void:
	if selected_city_id == "":
		return
	var plane = _get_plane_by_id(selecting_plane_id)
	if plane == null:
		return
	if str(plane.get("status", "")) == "flying":
		print("PLANE ALREADY IN FLIGHT:", selecting_plane_id)
		return
	var gs: Node = get_parent().get_node_or_null("GameState")
	if gs == null:
		return
	var model_id: String = str(plane.get("model_id", ""))
	var speed: int = _player_state.get_model_speed(model_id) if _player_state else 6
	speed = maxi(speed, 1)
	var origin_world: Vector2 = _get_city_world_pos(origin_city_id)
	var dest_world: Vector2 = _get_city_world_pos(selected_city_id)
	var map_w_dur: int = _map_view.get_map_width()
	var dx: float = dest_world.x - origin_world.x
	if dx > float(map_w_dur) / 2.0:
		dx -= float(map_w_dur)
	elif dx < -float(map_w_dur) / 2.0:
		dx += float(map_w_dur)
	var dy: float = dest_world.y - origin_world.y
	var distance: float = sqrt(dx * dx + dy * dy)
	var duration_ms: int = int(distance / float(speed) * DISTANCE_TIME_FACTOR)
	duration_ms = maxi(duration_ms, 1000)
	var flight: Dictionary = {
		"plane_id": selecting_plane_id,
		"origin": origin_city_id,
		"destination": selected_city_id,
		"start_time": Time.get_ticks_msec(),
		"duration": duration_ms
	}
	gs.active_flights.append(flight)
	print("FLIGHT CREATED:", selecting_plane_id, " ", origin_city_id, " → ", selected_city_id)
	plane = _get_plane_by_id(selecting_plane_id)
	if plane != null:
		plane["status"] = "flying"
		plane["current_city_id"] = ""
	selecting_destination = false
	selected_city_id = ""
	origin_city_id = ""
	if _destination_hint_label != null:
		_destination_hint_label.visible = false
	if _destination_cancel_btn != null:
		_destination_cancel_btn.visible = false
	if _start_flight_btn != null:
		_start_flight_btn.visible = false
	queue_redraw()
	if _static_map_layer != null:
		_static_map_layer.queue_redraw()
	if _route_layer != null:
		_route_layer.queue_redraw()
	if _flying_aircraft_layer != null:
		_flying_aircraft_layer.queue_redraw()
	if _city_layer != null:
		_city_layer.queue_redraw()

func _on_menu_pressed() -> void:
	_pending_deploy_aircraft_id = ""
	if _deploy_hint_label != null:
		_deploy_hint_label.visible = false
	_main_menu_panel.visible = true

func _on_open_bills() -> void:
	_main_menu_panel.visible = false
	_bill_panel.visible = true

func _on_open_shop() -> void:
	_main_menu_panel.visible = false
	_shop_panel.visible = true

func _on_open_hangar() -> void:
	_main_menu_panel.visible = false
	_hangar_panel.visible = true

func _on_close_menu() -> void:
	_main_menu_panel.visible = false

func _on_bill_back_to_menu() -> void:
	_bill_panel.visible = false
	_main_menu_panel.visible = true

func _on_shop_back_to_menu() -> void:
	_shop_panel.visible = false
	_main_menu_panel.visible = true

func _on_hangar_back_to_menu() -> void:
	_hangar_panel.visible = false
	_main_menu_panel.visible = true

func _on_airport_back_to_map() -> void:
	_airport_panel.visible = false

func enter_destination_select_mode(plane_id: String) -> void:
	selecting_destination = true
	selecting_plane_id = plane_id
	selected_city_id = ""
	origin_city_id = ""
	if _player_state != null:
		for ac in _player_state.get_aircraft_instances():
			if str(ac.get("id", "")) == plane_id:
				origin_city_id = str(ac.get("current_city_id", ""))
				break
	print("DESTINATION MODE: plane=", plane_id)
	queue_redraw()
	if _static_map_layer != null:
		_static_map_layer.queue_redraw()
	if _route_layer != null:
		_route_layer.queue_redraw()
	if _flying_aircraft_layer != null:
		_flying_aircraft_layer.queue_redraw()
	if _city_layer != null:
		_city_layer.queue_redraw()
	if _destination_hint_label != null:
		_destination_hint_label.visible = true
		_destination_hint_label.position = Vector2(20, 70)
	if _destination_cancel_btn != null:
		_destination_cancel_btn.visible = true
		_destination_cancel_btn.position = Vector2(20, 116)
		_destination_cancel_btn.size = Vector2(120, 56)
	if _start_flight_btn != null:
		_start_flight_btn.visible = true
		_start_flight_btn.position = Vector2(150, 116)
		_start_flight_btn.size = Vector2(120, 56)

func _on_destination_cancel_pressed() -> void:
	selecting_destination = false
	selecting_plane_id = ""
	selected_city_id = ""
	origin_city_id = ""
	if _destination_hint_label != null:
		_destination_hint_label.visible = false
	if _destination_cancel_btn != null:
		_destination_cancel_btn.visible = false
	if _start_flight_btn != null:
		_start_flight_btn.visible = false
	queue_redraw()
	if _static_map_layer != null:
		_static_map_layer.queue_redraw()
	if _route_layer != null:
		_route_layer.queue_redraw()
	if _flying_aircraft_layer != null:
		_flying_aircraft_layer.queue_redraw()
	if _city_layer != null:
		_city_layer.queue_redraw()
	_airport_panel.visible = true

func _on_aircraft_recalled() -> void:
	if _player_state != null:
		set_aircraft(_player_state.get_aircraft_instances())

func _on_request_deploy_mode(aircraft_id: String) -> void:
	_pending_deploy_aircraft_id = aircraft_id
	_hangar_panel.visible = false
	_main_menu_panel.visible = false
	if _deploy_hint_label != null:
		_deploy_hint_label.text = "Select city to deploy: %s" % aircraft_id
		_deploy_hint_label.visible = true
		_deploy_hint_label.position = Vector2(20, 16)

func _on_city_pressed(city_id: String) -> void:
	var game_world: Node = get_parent()
	if game_world == null:
		return
	if selecting_destination:
		if selected_city_id == city_id:
			selected_city_id = ""
			print("DESTINATION UNSELECTED:", city_id)
		else:
			selected_city_id = city_id
			print("DESTINATION SELECTED:", city_id)
		queue_redraw()
		if _static_map_layer != null:
			_static_map_layer.queue_redraw()
		if _route_layer != null:
			_route_layer.queue_redraw()
		if _flying_aircraft_layer != null:
			_flying_aircraft_layer.queue_redraw()
		if _city_layer != null:
			_city_layer.queue_redraw()
		return
	if not _pending_deploy_aircraft_id.is_empty():
		# 部署模式：完成部署后自动打开该城市机场界面
		if AircraftDeploySystem.deploy_aircraft(game_world, _pending_deploy_aircraft_id, city_id):
			_pending_deploy_aircraft_id = ""
			if _deploy_hint_label != null:
				_deploy_hint_label.visible = false
			if _player_state != null:
				set_aircraft(_player_state.get_aircraft_instances())
			_airport_panel.set_airport_city(city_id)
			_airport_panel.visible = true
		return
	# 正常模式：打开该城市机场界面
	_airport_panel.set_airport_city(city_id)
	_airport_panel.visible = true

func _input(event: InputEvent) -> void:
	# iOS: forward screen touch/drag to map_view for two-finger pinch zoom
	if _map_view != null:
		if event is InputEventScreenTouch:
			_map_view.process_screen_touch(event)
		elif event is InputEventScreenDrag:
			_map_view.process_screen_drag(event)
	if _map_view == null:
		return
	# 鼠标滚轮
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_map_view.zoom_in()
				print("WHEEL ZOOM: zoom=", _map_view.get_zoom())
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_map_view.zoom_out()
				print("WHEEL ZOOM: zoom=", _map_view.get_zoom())
	# Mac 触控板双指缩放（独立分支，与 Pan 不互斥）
	if event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		var factor: float = mg.factor
		_map_view.zoom_by_factor(factor)
		print("GESTURE ZOOM: factor=", factor, " zoom=", _map_view.get_zoom())
	# Mac 触控板双指平移（独立分支；取反方向，倍率 2.0）
	if event is InputEventPanGesture:
		var pg: InputEventPanGesture = event
		_map_view.pan_by_screen_delta(Vector2(-pg.delta.x, -pg.delta.y) * 2.0)
	# 单指抬起时做城市命中检测（tap）
	if event is InputEventScreenTouch and not event.pressed:
		var hit_city_id: String = _pick_city_at_screen_pos(event.position)
		if hit_city_id != "":
			_on_city_pressed(hit_city_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit_city_id: String = _pick_city_at_screen_pos(mb.position)
			if hit_city_id != "":
				_on_city_pressed(hit_city_id)

func _sync_route_layer_transform() -> void:
	if _route_layer == null or _map_view == null:
		return
	var view_size: Vector2 = _get_view_size()
	var viewport_center: Vector2 = view_size / 2.0
	var view_center: Vector2 = _map_view.get_view_center()
	var z: float = _map_view.get_zoom()
	_route_layer.position = viewport_center - view_center * z
	_route_layer.scale = Vector2(z, z)

func _sync_aircraft_layer_transform() -> void:
	if _flying_aircraft_layer == null or _map_view == null:
		return
	var view_size: Vector2 = _get_view_size()
	var viewport_center: Vector2 = view_size / 2.0
	var view_center: Vector2 = _map_view.get_view_center()
	var z: float = _map_view.get_zoom()
	_flying_aircraft_layer.position = viewport_center - view_center * z
	_flying_aircraft_layer.scale = Vector2(z, z)

func _sync_city_layer_transform() -> void:
	if _city_layer == null or _map_view == null:
		return
	var view_size: Vector2 = _get_view_size()
	var viewport_center: Vector2 = view_size / 2.0
	var view_center: Vector2 = _map_view.get_view_center()
	var z: float = _map_view.get_zoom()
	_city_layer.position = viewport_center - view_center * z
	_city_layer.scale = Vector2(z, z)

func _on_map_view_changed() -> void:
	_sync_route_layer_transform()
	_sync_aircraft_layer_transform()
	_sync_city_layer_transform()
	_update_aircraft_screen_positions()
	queue_redraw()
	if _static_map_layer != null:
		_static_map_layer.queue_redraw()
	if _route_layer != null:
		_route_layer.queue_redraw()
	if _flying_aircraft_layer != null:
		_flying_aircraft_layer.queue_redraw()
	if _city_layer != null:
		_city_layer.queue_redraw()
	var z: float = _map_view.get_zoom() if _map_view != null else 1.0
	print("MAP REFRESH WITH ZOOM: ", z)

func _draw() -> void:
	pass

func _complete_flight(flight: Dictionary) -> void:
	var dest: String = str(flight.get("destination", ""))
	var plane_id: String = str(flight.get("plane_id", ""))
	print("FLIGHT ARRIVED:", plane_id, " → ", dest)
	var gs: Node = get_parent().get_node_or_null("GameState")
	if gs != null:
		gs.active_flights.erase(flight)
	var plane = _get_plane_by_id(plane_id)
	if plane != null:
		plane["status"] = "grounded"
		plane["current_city_id"] = dest
	if _player_state != null:
		set_aircraft(_player_state.get_aircraft_instances())
	queue_redraw()
	if _static_map_layer != null:
		_static_map_layer.queue_redraw()
	if _route_layer != null:
		_route_layer.queue_redraw()
	if _flying_aircraft_layer != null:
		_flying_aircraft_layer.queue_redraw()
	if _city_layer != null:
		_city_layer.queue_redraw()

func _process(_delta: float) -> void:
	var flights: Array = _get_active_flights()
	var to_complete: Array = []
	var now: int = Time.get_ticks_msec()
	for flight in flights:
		var origin_id: String = str(flight.get("origin", ""))
		var dest_id: String = str(flight.get("destination", ""))
		if origin_id == "" or dest_id == "":
			continue
		var start_time: int = int(flight.get("start_time", 0))
		var duration: int = int(flight.get("duration", 1))
		if duration <= 0:
			continue
		var progress: float = float(now - start_time) / float(duration)
		if progress >= 1.0:
			to_complete.append(flight)
	for f in to_complete:
		_complete_flight(f)
	if _map_view != null and not _map_view.is_dragging():
		queue_redraw()
		if _static_map_layer != null:
			_static_map_layer.queue_redraw()
		if _route_layer != null:
			_route_layer.queue_redraw()
		if _flying_aircraft_layer != null:
			_flying_aircraft_layer.queue_redraw()
		if _city_layer != null:
			_city_layer.queue_redraw()

func _get_plane_by_id(plane_id: String):
	if _player_state == null:
		return null
	for ac in _player_state.get_aircraft_instances():
		if str(ac.get("id", "")) == plane_id:
			return ac
	return null

func _get_city_world_pos(city_id: String) -> Vector2:
	for c in _cities:
		if str(c.get("id", "")) == city_id:
			return Vector2(float(c.get("x", 0)), float(c.get("y", 0)))
	return Vector2.ZERO

func _get_view_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _get_city_visual_scale() -> float:
	if _map_view == null:
		return 1.0
	return clampf(0.7 + 0.18 * _map_view.get_zoom(), 0.75, 1.6)

func _get_city_base_radius(city: Dictionary) -> float:
	var level: String = str(city.get("airport_level", city.get("base_level", "small")))
	match level:
		"huge":
			return 7.0
		"large":
			return 6.0
		"medium":
			return 5.0
		_:
			return 4.0

func set_cities(cities: Array) -> void:
	_cities = cities

func _pick_city_at_screen_pos(screen_pos: Vector2) -> String:
	if _map_view == null or _cities.is_empty():
		return ""
	var view_size: Vector2 = _get_view_size()
	var map_w: int = _map_view.get_map_width()
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	var best_id: String = ""
	var best_dist: float = 1e30
	for city in _cities:
		var wx: float = float(city.get("x", 0))
		var wy: float = float(city.get("y", 0))
		var city_id: String = str(city.get("id", ""))
		for offset_x in offsets_x:
			var center_screen: Vector2 = _map_view.world_to_screen(Vector2(wx + offset_x, wy), view_size)
			var base_radius: float = _get_city_base_radius(city)
			var visual_scale: float = _get_city_visual_scale()
			var radius: float = base_radius * visual_scale
			radius = clampf(radius, CITY_ICON_RADIUS_CLAMP_MIN, CITY_ICON_RADIUS_CLAMP_MAX)
			var pick_radius: float = maxf(radius + CITY_PICK_RADIUS_PADDING, CITY_PICK_RADIUS_MIN)
			var d: float = screen_pos.distance_to(center_screen)
			if d <= pick_radius and d < best_dist:
				best_dist = d
				best_id = city_id
	return best_id

func set_aircraft(aircraft_instances: Array) -> void:
	for child in _aircraft_layer.get_children():
		child.queue_free()
	if _map_view == null:
		return
	var view_size := _get_view_size()
	for ac in aircraft_instances:
		if str(ac.get("status", "")) != AIRCRAFT_STATUS_GROUNDED:
			continue
		var city_id = ac.get("current_city_id")
		if city_id == null or (city_id is String and city_id.is_empty()):
			continue
		var city := _find_city_by_id(city_id)
		if city.is_empty():
			continue
		var wx: float = float(city.get("x", 0))
		var wy: float = float(city.get("y", 0))
		var screen: Vector2 = _map_view.world_to_screen(Vector2(wx, wy), view_size)
		var icon := Label.new()
		icon.text = "✈"
		icon.add_theme_font_size_override("font_size", 72)
		icon.set_position((screen + AIRCRAFT_ICON_OFFSET).round())
		icon.set_meta("city_id", city_id)
		_aircraft_layer.add_child(icon)

func _update_aircraft_screen_positions() -> void:
	if _map_view == null or _player_state == null:
		return
	var view_size := _get_view_size()
	for child in _aircraft_layer.get_children():
		var city_id = child.get_meta("city_id", null)
		if city_id == null:
			continue
		var city := _find_city_by_id(city_id)
		if city.is_empty():
			continue
		var wx: float = float(city.get("x", 0))
		var wy: float = float(city.get("y", 0))
		var screen: Vector2 = _map_view.world_to_screen(Vector2(wx, wy), view_size)
		child.set_position((screen + AIRCRAFT_ICON_OFFSET).round())

func _find_city_by_id(city_id) -> Dictionary:
	for city in _cities:
		if str(city.get("id", "")) == str(city_id):
			return city
	return {}
