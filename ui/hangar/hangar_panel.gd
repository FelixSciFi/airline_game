extends Control

signal back_to_menu

var _player_state: Node = null

@onready var _balance_label: Label = $MarginContainer/VBox/TopBar/BalanceLabel
@onready var _aircraft_list: VBoxContainer = $MarginContainer/VBox/ScrollContainer/AircraftList

func set_player_state(player_state: Node) -> void:
	_player_state = player_state

func _ready() -> void:
	$MarginContainer/VBox/BackButton.pressed.connect(_on_back_pressed)
	_refresh_balance()
	_refresh_aircraft_list()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_balance()
		if _aircraft_list != null:
			_refresh_aircraft_list()

func _refresh_balance() -> void:
	if _balance_label == null:
		return
	if _player_state != null:
		_balance_label.text = "当前余额: %d" % _player_state.get_balance()
	else:
		_balance_label.text = "当前余额: --"

func _refresh_aircraft_list() -> void:
	if _aircraft_list == null:
		return
	for child in _aircraft_list.get_children():
		child.queue_free()
	if _player_state == null:
		return
	var instances: Array = _player_state.get_aircraft_instances()
	for ac in instances:
		var row := _make_aircraft_row(ac)
		_aircraft_list.add_child(row)

func _make_aircraft_row(ac: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	var ac_id := str(ac.get("id", ""))
	var model_id := str(ac.get("model_id", ""))
	var status := str(ac.get("status", ""))
	var model_name: String = _player_state.get_model_name(model_id) if _player_state else model_id

	var info_label := Label.new()
	info_label.text = "%s | %s | %s" % [ac_id, model_name, status]
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_label)

	var sell_btn := Button.new()
	sell_btn.text = "卖出"
	sell_btn.add_theme_font_size_override("font_size", 14)
	var can_sell: bool = (status == "stored")
	sell_btn.disabled = !can_sell
	if can_sell:
		sell_btn.pressed.connect(_on_sell_pressed.bind(ac_id))
	hbox.add_child(sell_btn)

	return hbox

func _on_sell_pressed(aircraft_id: String) -> void:
	if _player_state == null:
		return
	if _player_state.sell_aircraft(aircraft_id):
		_refresh_balance()
		_refresh_aircraft_list()

func _on_back_pressed() -> void:
	back_to_menu.emit()
