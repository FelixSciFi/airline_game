extends Node2D

const CITIES_PATH := "res://data/cities.json"

var _cities: Array = []

@onready var _world_map: Control = $WorldMap

func _ready() -> void:
	_cities = _load_cities()
	_world_map.set_cities(_cities)
	_world_map.set_aircraft(get_player_state().get_aircraft_instances())
	call_deferred("load_game")

func load_game() -> void:
	var data: Dictionary = SaveSystem.load_game()
	if data.is_empty():
		return
	apply_save_data(data)

func get_cities() -> Array:
	return _cities

func get_player_state() -> Node:
	return get_node_or_null("PlayerState")

func build_save_data() -> Dictionary:
	var data: Dictionary = {}

	var ps = get_player_state()
	var gs = get_node_or_null("GameState")

	data["save_version"] = 1
	data["player_state"] = {
		"aircraft_instances": ps.get_aircraft_instances()
	}

	if gs != null:
		data["game_state"] = {
			"active_flights": gs.active_flights
		}
	else:
		data["game_state"] = {
			"active_flights": []
		}

	return data

func save_game() -> bool:
	var data: Dictionary = build_save_data()
	var ok := SaveSystem.save_game(data)

	if ok:
		print("[MainGame] Save completed")
	else:
		print("[MainGame] Save failed")

	return ok

func apply_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		print("[MainGame] Apply save failed: invalid root data")
		return

	var ps = get_player_state()
	var gs = get_node_or_null("GameState")

	if gs == null:
		print("[MainGame] Apply save failed: GameState not found")
		return

	var player_data = data.get("player_state", {})
	if typeof(player_data) == TYPE_DICTIONARY:
		var aircraft_instances = player_data.get("aircraft_instances", [])
		if typeof(aircraft_instances) == TYPE_ARRAY:
			ps.aircraft_instances = aircraft_instances.duplicate(true)

	var game_data = data.get("game_state", {})
	if typeof(game_data) == TYPE_DICTIONARY:
		var active_flights = game_data.get("active_flights", [])
		if typeof(active_flights) == TYPE_ARRAY:
			var now_unix: int = int(Time.get_unix_time_from_system())
			var rebuilt_flights: Array = []
			for flight in active_flights:
				if typeof(flight) != TYPE_DICTIONARY:
					continue
				if not flight.has("arrival_at_unix") or not flight.has("started_at_unix"):
					continue
				if now_unix >= flight["arrival_at_unix"]:
					var plane_id: String = str(flight.get("plane_id", ""))
					var destination: String = str(flight.get("destination", ""))
					for plane in ps.aircraft_instances:
						if str(plane.get("id", "")) == plane_id:
							plane["status"] = "grounded"
							plane["current_city_id"] = destination
							break
					continue
				var remaining_seconds: int = flight["arrival_at_unix"] - now_unix
				var remaining_ms: int = remaining_seconds * 1000
				var duration_ms: int = int(flight.get("duration", 0))
				var new_start_time: int = Time.get_ticks_msec() - (duration_ms - remaining_ms)
				var f: Dictionary = flight.duplicate(true)
				f["start_time"] = new_start_time
				rebuilt_flights.append(f)
			gs.active_flights = rebuilt_flights

	_world_map.set_aircraft(ps.get_aircraft_instances())
	print("[MainGame] Apply save completed")

func _load_cities() -> Array:
	var file := FileAccess.open(CITIES_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open %s: %s" % [CITIES_PATH, FileAccess.get_open_error()])
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Failed to parse cities JSON: %s" % json.get_error_message())
		return []

	var data = json.data
	if data is Array:
		return data
	return []
