extends Control

signal back_to_menu

var _player_state: Node = null

@onready var _back_button: Button = $MarginContainer/VBox/BackButton
@onready var _balance_label: Label = $MarginContainer/VBox/BalanceLabel
@onready var _logs_container: VBoxContainer = $MarginContainer/VBox/ScrollContainer/LogsContainer

func set_player_state(player_state: Node) -> void:
	_player_state = player_state

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_display()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_display()

func _refresh_display() -> void:
	if _balance_label != null:
		if _player_state != null:
			_balance_label.text = "Balance: %d" % _player_state.get_balance()
		else:
			_balance_label.text = "Balance: --"
	if _logs_container == null:
		return
	for child in _logs_container.get_children():
		child.queue_free()
	if _player_state == null:
		return
	var logs: Array = _player_state.get_finance_logs()
	for log in logs:
		var entry: Dictionary = log if log is Dictionary else {}
		var amount: int = entry.get("amount", 0)
		var desc: String = str(entry.get("desc", ""))
		var prefix: String = "+" if amount >= 0 else ""
		var line := "%s%d %s" % [prefix, amount, desc]
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 36)
		_logs_container.add_child(label)

func _on_back_pressed() -> void:
	back_to_menu.emit()
