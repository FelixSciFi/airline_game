extends Control

const AircraftRecallSystem = preload("res://systems/aircraft_recall_system.gd")

signal back_to_map
signal aircraft_recalled

var _game_world: Node = null
var _airport_city_id: String = ""

@onready var _title_label: Label = $MarginContainer/VBox/TopBar/TitleLabel
@onready var _aircraft_list: VBoxContainer = $MarginContainer/VBox/ScrollContainer/AircraftList

func set_game_world(game_world: Node) -> void:
	_game_world = game_world

func set_airport_city(city_id: String) -> void:
	_airport_city_id = city_id
	_update_title()
	_refresh_aircraft_list()

func _update_title() -> void:
	if _title_label == null:
		return
	var name_str := _airport_city_id
	if _game_world != null:
		var cities: Array = _game_world.get_cities()
		for c in cities:
			if str(c.get("id", "")) == _airport_city_id:
				name_str = str(c.get("name", _airport_city_id))
				break
	_title_label.text = "机场：%s" % name_str

func _ready() -> void:
	$MarginContainer/VBox/BackButton.pressed.connect(_on_back_pressed)
	if _airport_city_id != "":
		_update_title()
		_refresh_aircraft_list()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and _airport_city_id != "":
		_update_title()
		if _aircraft_list != null:
			_refresh_aircraft_list()

func _refresh_aircraft_list() -> void:
	if _aircraft_list == null:
		return
	for child in _aircraft_list.get_children():
		child.queue_free()
	if _game_world == null:
		return
	var player_state: Node = _game_world.get_player_state()
	if player_state == null:
		return
	var instances: Array = player_state.get_aircraft_instances()
	for ac in instances:
		if str(ac.get("status", "")) != "grounded":
			continue
		if str(ac.get("current_city_id", "")) != _airport_city_id:
			continue
		var row := _make_aircraft_row(ac, player_state)
		_aircraft_list.add_child(row)

func _make_aircraft_row(ac: Dictionary, player_state: Node) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	var ac_id := str(ac.get("id", ""))
	var model_id := str(ac.get("model_id", ""))
	var status := str(ac.get("status", ""))
	var model_name: String = player_state.get_model_name(model_id) if player_state else model_id

	var info_label := Label.new()
	info_label.text = "%s | %s | %s" % [ac_id, model_name, status]
	info_label.add_theme_font_size_override("font_size", 36)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_label)

	var recall_btn := Button.new()
	recall_btn.text = "送回机库"
	recall_btn.add_theme_font_size_override("font_size", 44)
	recall_btn.pressed.connect(_on_recall_pressed.bind(ac_id))
	hbox.add_child(recall_btn)

	var depart_btn := Button.new()
	depart_btn.text = "出发"
	depart_btn.add_theme_font_size_override("font_size", 44)
	depart_btn.pressed.connect(_on_depart_pressed.bind(ac_id))
	hbox.add_child(depart_btn)

	return hbox

func _on_recall_pressed(aircraft_id: String) -> void:
	if _game_world == null:
		return
	if AircraftRecallSystem.recall_aircraft(_game_world, aircraft_id):
		_refresh_aircraft_list()
		aircraft_recalled.emit()

func _on_depart_pressed(aircraft_id: String) -> void:
	var wm: Node = get_parent()
	if wm != null and wm.has_method("enter_destination_select_mode"):
		wm.enter_destination_select_mode(aircraft_id)
	back_to_map.emit()

func _on_back_pressed() -> void:
	back_to_map.emit()
