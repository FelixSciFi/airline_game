extends Control

const AircraftDeploySystem = preload("res://systems/aircraft_deploy_system.gd")
const WORLD_MAP_TEXTURE := preload("res://assets/map/world_map_v1.png")
const DOT_SIZE := 16
const LABEL_OFFSET := Vector2(12, -6)
const AIRCRAFT_ICON_OFFSET := Vector2(-6, -6)
const CITY_BUTTON_SIZE := 44
const AIRCRAFT_STATUS_GROUNDED := "grounded"

var _cities_layer: Node2D
var _aircraft_layer: Node2D
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

func _get_active_flights() -> Array:
	var parent := get_parent()
	if parent == null:
		return []
	var gs: Node = parent.get_node_or_null("GameState")
	if gs == null:
		return []
	return gs.active_flights

func _ready() -> void:
	_cities_layer = $CitiesLayer
	_aircraft_layer = Node2D.new()
	_aircraft_layer.name = "AircraftLayer"
	add_child(_aircraft_layer)
	_map_view = preload("res://ui/map/map_view.gd").new()
	_map_view.name = "MapView"
	add_child(_map_view)
	_map_view.view_changed.connect(_on_map_view_changed)
	$ColorRect.visible = false
	queue_redraw()
	_deploy_hint_label = Label.new()
	_deploy_hint_label.name = "DeployHintLabel"
	_deploy_hint_label.add_theme_font_size_override("font_size", 36)
	_deploy_hint_label.visible = false
	add_child(_deploy_hint_label)
	_destination_hint_label = Label.new()
	_destination_hint_label.name = "DestinationHintLabel"
	_destination_hint_label.text = "选择目的地城市"
	_destination_hint_label.add_theme_font_size_override("font_size", 36)
	_destination_hint_label.visible = false
	add_child(_destination_hint_label)
	_destination_cancel_btn = Button.new()
	_destination_cancel_btn.name = "DestinationCancelButton"
	_destination_cancel_btn.text = "取消"
	_destination_cancel_btn.add_theme_font_size_override("font_size", 44)
	_destination_cancel_btn.visible = false
	_destination_cancel_btn.pressed.connect(_on_destination_cancel_pressed)
	add_child(_destination_cancel_btn)
	_start_flight_btn = Button.new()
	_start_flight_btn.name = "StartFlightButton"
	_start_flight_btn.text = "起飞"
	_start_flight_btn.add_theme_font_size_override("font_size", 44)
	_start_flight_btn.visible = false
	_start_flight_btn.pressed.connect(_on_start_pressed)
	add_child(_start_flight_btn)
	_ensure_game_state()
	# Ensure we fill the viewport when parent is Node2D（延后设置避免与 anchor 冲突）
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_apply_viewport_size")

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
	var flight: Dictionary = {
		"plane_id": selecting_plane_id,
		"origin": origin_city_id,
		"destination": selected_city_id,
		"start_time": Time.get_ticks_msec(),
		"duration": 120000
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
	_update_cities_screen_positions()
	queue_redraw()

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
	_update_cities_screen_positions()
	queue_redraw()
	_airport_panel.visible = true

func _on_aircraft_recalled() -> void:
	if _player_state != null:
		set_aircraft(_player_state.get_aircraft_instances())

func _on_request_deploy_mode(aircraft_id: String) -> void:
	_pending_deploy_aircraft_id = aircraft_id
	_hangar_panel.visible = false
	_main_menu_panel.visible = false
	if _deploy_hint_label != null:
		_deploy_hint_label.text = "请选择部署城市：%s" % aircraft_id
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
		_update_cities_screen_positions()
		queue_redraw()
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
	# Mac 触控板双指缩放手势
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		var factor: float = mg.factor
		_map_view.zoom_by_factor(factor)
		print("GESTURE ZOOM: factor=", factor, " zoom=", _map_view.get_zoom())

func _on_map_view_changed() -> void:
	_update_cities_screen_positions()
	_update_aircraft_screen_positions()
	queue_redraw()
	var z: float = _map_view.get_zoom() if _map_view != null else 1.0
	print("MAP REFRESH WITH ZOOM: ", z)

func _draw() -> void:
	if _map_view == null:
		return
	var view_size: Vector2 = _get_view_size()
	var map_w: int = _map_view.get_map_width()
	var map_h: int = _map_view.get_map_height()
	# 地图外部：整屏浅灰
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.45, 0.45, 0.48, 1))
	# 左右连续：三份副本 offset_x = -MAP_WIDTH, 0, +MAP_WIDTH
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	for offset_x in offsets_x:
		var corners: PackedVector2Array = [
			_map_view.world_to_screen(Vector2(offset_x, 0), view_size),
			_map_view.world_to_screen(Vector2(offset_x + map_w, 0), view_size),
			_map_view.world_to_screen(Vector2(offset_x + map_w, map_h), view_size),
			_map_view.world_to_screen(Vector2(offset_x, map_h), view_size)
		]
		# 地图内部：底图
		if WORLD_MAP_TEXTURE != null:
			var top_left: Vector2 = corners[0]
			var bottom_right: Vector2 = corners[2]
			draw_texture_rect(WORLD_MAP_TEXTURE, Rect2(top_left, bottom_right - top_left), false)
		else:
			draw_colored_polygon(corners, Color(0.35, 0.38, 0.42, 1))
		# 地图边界：清晰边框
		draw_polyline(corners, Color(1.0, 1.0, 1.0, 1.0))
		draw_line(corners[3], corners[0], Color(1.0, 1.0, 1.0, 1.0))
	# 航线预览线：DESTINATION MODE 下 origin → selected
	if selecting_destination and origin_city_id != "" and selected_city_id != "":
		var origin_world: Vector2 = _get_city_world_pos(origin_city_id)
		var dest_world: Vector2 = _get_city_world_pos(selected_city_id)
		var p1: Vector2 = _map_view.world_to_screen(origin_world, view_size)
		var p2: Vector2 = _map_view.world_to_screen(dest_world, view_size)
		var line_color := Color(1.0, 1.0, 0.0, 0.9)
		var dir: Vector2 = (p2 - p1).normalized()
		var perp := Vector2(-dir.y, dir.x)
		draw_line(p1 + perp, p2 + perp, line_color)
		draw_line(p1, p2, line_color)
		draw_line(p1 - perp, p2 - perp, line_color)
	# FlightManager：根据 GameState.active_flights 绘制飞行航线
	var flights: Array = _get_active_flights()
	var to_complete: Array = []
	if not flights.is_empty():
		var now: int = Time.get_ticks_msec()
		for flight in flights:
			var origin_id: String = str(flight.get("origin", ""))
			var dest_id: String = str(flight.get("destination", ""))
			if origin_id == "" or dest_id == "":
				continue
			var origin_world_f: Vector2 = _get_city_world_pos(origin_id)
			var dest_world_f: Vector2 = _get_city_world_pos(dest_id)
			var start_time: int = int(flight.get("start_time", 0))
			var duration: int = int(flight.get("duration", 1))
			if duration <= 0:
				continue
			var progress: float = float(now - start_time) / float(duration)
			progress = clampf(progress, 0.0, 1.0)
			if progress >= 1.0:
				to_complete.append(flight)
				continue
			var fp1: Vector2 = _map_view.world_to_screen(origin_world_f, view_size)
			var fp2: Vector2 = _map_view.world_to_screen(dest_world_f, view_size)
			draw_line(fp1, fp2, Color(0.7, 0.8, 1.0, 0.9), 2.0)

			var plane_world: Vector2 = origin_world_f.lerp(dest_world_f, progress)
			var plane_screen: Vector2 = _map_view.world_to_screen(plane_world, view_size)

			var dir_f: Vector2 = (dest_world_f - origin_world_f).normalized()
			if dir_f.length() == 0.0:
				continue
			var perp_f := Vector2(-dir_f.y, dir_f.x)
			var size: float = 6.0
			var nose: Vector2 = plane_screen + dir_f * size
			var left: Vector2 = plane_screen - dir_f * size * 0.3 + perp_f * size * 0.6
			var right: Vector2 = plane_screen - dir_f * size * 0.3 - perp_f * size * 0.6
			var tri := PackedVector2Array([nose, left, right])
			draw_colored_polygon(tri, Color(1, 1, 1, 1))
		for f in to_complete:
			_complete_flight(f)

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

func _process(_delta: float) -> void:
	queue_redraw()

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

func set_cities(cities: Array) -> void:
	_cities = cities
	for child in _cities_layer.get_children():
		child.queue_free()
	if _map_view == null:
		return
	var view_size := _get_view_size()
	var map_w: int = _map_view.get_map_width()
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	for city in cities:
		var wx: float = float(city.get("x", 0))
		var wy: float = float(city.get("y", 0))
		var name_str: String = str(city.get("name", ""))
		var city_id: String = str(city.get("id", ""))
		for offset_x in offsets_x:
			var world_pos := Vector2(wx + offset_x, wy)
			var screen: Vector2 = _map_view.world_to_screen(world_pos, view_size)
			var dot := ColorRect.new()
			dot.color = Color(0.9, 0.3, 0.2, 1)
			dot.set_position(Vector2(screen.x - DOT_SIZE / 2.0, screen.y - DOT_SIZE / 2.0))
			dot.set_size(Vector2(DOT_SIZE, DOT_SIZE))
			_cities_layer.add_child(dot)
			var label := Label.new()
			label.text = name_str
			label.add_theme_font_size_override("font_size", 36)
			label.set_position(screen + LABEL_OFFSET)
			_cities_layer.add_child(label)
			var btn := Button.new()
			btn.flat = true
			btn.set_position(Vector2(screen.x - CITY_BUTTON_SIZE / 2.0, screen.y - CITY_BUTTON_SIZE / 2.0))
			btn.set_size(Vector2(CITY_BUTTON_SIZE, CITY_BUTTON_SIZE))
			btn.pressed.connect(_on_city_pressed.bind(city_id))
			_cities_layer.add_child(btn)

func _update_cities_screen_positions() -> void:
	if _map_view == null or _cities.is_empty():
		return
	var view_size := _get_view_size()
	var map_w: int = _map_view.get_map_width()
	var offsets_x: Array = [0.0, -float(map_w), float(map_w)]
	var idx := 0
	for city in _cities:
		var wx: float = float(city.get("x", 0))
		var wy: float = float(city.get("y", 0))
		var city_id: String = str(city.get("id", ""))
		var dot_radius: float = DOT_SIZE / 2.0
		var dot_color := Color(0.9, 0.3, 0.2, 1)
		if selecting_destination:
			if city_id == selected_city_id:
				dot_radius = 8.0
				dot_color = Color.YELLOW
			else:
				dot_radius = 6.0
				dot_color = Color.RED
		var dot_size: float = dot_radius * 2.0
		for offset_x in offsets_x:
			var screen: Vector2 = _map_view.world_to_screen(Vector2(wx + offset_x, wy), view_size)
			var dot := _cities_layer.get_child(idx)
			var label := _cities_layer.get_child(idx + 1)
			var btn := _cities_layer.get_child(idx + 2)
			dot.color = dot_color
			dot.set_size(Vector2(dot_size, dot_size))
			dot.set_position(Vector2(screen.x - dot_radius, screen.y - dot_radius))
			label.set_position(screen + LABEL_OFFSET)
			btn.set_position(Vector2(screen.x - CITY_BUTTON_SIZE / 2.0, screen.y - CITY_BUTTON_SIZE / 2.0))
			btn.set_size(Vector2(CITY_BUTTON_SIZE, CITY_BUTTON_SIZE))
			idx += 3

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
		icon.add_theme_font_size_override("font_size", 36)
		icon.set_position(screen + AIRCRAFT_ICON_OFFSET)
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
		child.set_position(screen + AIRCRAFT_ICON_OFFSET)

func _find_city_by_id(city_id) -> Dictionary:
	for city in _cities:
		if str(city.get("id", "")) == str(city_id):
			return city
	return {}
