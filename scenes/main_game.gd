extends Node2D

const CITIES_PATH := "res://data/cities.json"

var _cities: Array = []

@onready var _world_map: Control = $WorldMap

func _ready() -> void:
	_cities = _load_cities()
	_world_map.set_cities(_cities)
	_world_map.set_aircraft(get_player_state().get_aircraft_instances())

func get_cities() -> Array:
	return _cities

func get_player_state() -> Node:
	return get_node_or_null("PlayerState")

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
