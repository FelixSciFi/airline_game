extends Control

signal back_to_menu

const MODELS_PATH := "res://data/aircraft_models.json"

var _player_state: Node = null
var _models: Array = []
var _balance_label: Label
var _models_container: VBoxContainer

func set_player_state(player_state: Node) -> void:
	_player_state = player_state

func _ready() -> void:
	_balance_label = $MarginContainer/VBox/TopBar/BalanceLabel
	_models_container = $MarginContainer/VBox/ScrollContainer/ModelsContainer
	$MarginContainer/VBox/BackButton.pressed.connect(_on_back_pressed)
	_load_models()
	_build_model_list()
	_refresh_balance()

func _load_models() -> void:
	var file := FileAccess.open(MODELS_PATH, FileAccess.READ)
	if file == null:
		push_error("Shop: failed to open %s" % MODELS_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("Shop: failed to parse models JSON")
		return
	var data = json.data
	if data is Array:
		_models = data
	else:
		_models = []

func _build_model_list() -> void:
	for model in _models:
		var card := _make_model_card(model)
		_models_container.add_child(card)

func _make_model_card(model: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = str(model.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(name_label)

	var price := int(model.get("price", 0))
	var price_label := Label.new()
	price_label.text = "Price: %d" % price
	price_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(price_label)

	var stats := "Speed:%d Capacity:%d Range:%d Fuel:%.1f" % [
		int(model.get("speed", 0)),
		int(model.get("capacity", 0)),
		int(model.get("max_range", 0)),
		float(model.get("fuel_rate", 0))
	]
	var stats_label := Label.new()
	stats_label.text = stats
	stats_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(stats_label)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.add_theme_font_size_override("font_size", 44)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var model_id := str(model.get("id", ""))
	buy_btn.pressed.connect(_on_buy_pressed.bind(model_id, price))
	vbox.add_child(buy_btn)

	return panel

func _on_buy_pressed(model_id: String, price: int) -> void:
	if _player_state == null:
		return
	if _player_state.purchase_aircraft(model_id, price):
		_refresh_balance()
	# 余额不足时不做反应，也可在此处加提示

func _refresh_balance() -> void:
	if _balance_label == null:
		return
	if _player_state != null:
		_balance_label.text = "Balance: %d" % _player_state.get_balance()
	else:
		_balance_label.text = "Balance: --"

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_balance()

func _on_back_pressed() -> void:
	back_to_menu.emit()
