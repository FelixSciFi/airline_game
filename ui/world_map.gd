extends Control

const DOT_SIZE := 10
const LABEL_OFFSET := Vector2(12, -6)

var _cities_layer: Node2D
var _main_menu_panel: Control
var _bill_panel: Control
var _shop_panel: Control
var _hangar_panel: Control

func _ready() -> void:
	_cities_layer = $CitiesLayer
	# Ensure we fill the viewport when parent is Node2D（延后设置避免与 anchor 冲突）
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_apply_viewport_size")

func _apply_viewport_size() -> void:
	var rect := get_viewport().get_visible_rect()
	set_deferred("size", rect.size)
	set_deferred("position", Vector2.ZERO)

	var player_state: Node = get_parent().get_node_or_null("PlayerState")

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
	add_child(_hangar_panel)
	_hangar_panel.visible = false
	_hangar_panel.back_to_menu.connect(_on_hangar_back_to_menu)

	$MenuButton.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
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

func set_cities(cities: Array) -> void:
	for child in _cities_layer.get_children():
		child.queue_free()

	for city in cities:
		var x: float = float(city.get("x", 0))
		var y: float = float(city.get("y", 0))
		var name_str: String = str(city.get("name", ""))

		# Dot (small ColorRect)
		var dot := ColorRect.new()
		dot.color = Color(0.9, 0.3, 0.2, 1)
		dot.set_position(Vector2(x - DOT_SIZE / 2.0, y - DOT_SIZE / 2.0))
		dot.set_size(Vector2(DOT_SIZE, DOT_SIZE))
		_cities_layer.add_child(dot)

		# Label with city name
		var label := Label.new()
		label.text = name_str
		label.add_theme_font_size_override("font_size", 14)
		label.set_position(Vector2(x, y) + LABEL_OFFSET)
		_cities_layer.add_child(label)
