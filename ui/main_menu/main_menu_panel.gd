extends Control

signal open_bills
signal open_shop
signal open_hangar
signal close_menu

var _player_state: Node = null

@onready var _shop_button: Button = $CenterContainer/VBox/ShopButton
@onready var _hangar_button: Button = $CenterContainer/VBox/HangarButton
@onready var _bills_button: Button = $CenterContainer/VBox/BillsButton
@onready var _close_button: Button = $CenterContainer/VBox/CloseButton
@onready var _money_label: Label = $CenterContainer/VBox/MoneyLabel

func set_player_state(player_state: Node) -> void:
	_player_state = player_state

func _ready() -> void:
	_shop_button.pressed.connect(_on_shop_pressed)
	_hangar_button.pressed.connect(_on_hangar_pressed)
	_bills_button.pressed.connect(_on_bills_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_refresh_balance()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_balance()

func _refresh_balance() -> void:
	if _money_label == null:
		return
	if _player_state != null:
		_money_label.text = "当前余额: %d" % _player_state.get_balance()
	else:
		_money_label.text = "当前余额: 100000"

func _on_bills_pressed() -> void:
	open_bills.emit()

func _on_shop_pressed() -> void:
	open_shop.emit()

func _on_hangar_pressed() -> void:
	open_hangar.emit()

func _on_close_pressed() -> void:
	close_menu.emit()
