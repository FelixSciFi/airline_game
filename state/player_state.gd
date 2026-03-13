extends Node

## 唯一真实数据源：余额、已拥有飞机、账单流水；购买/卖出及流水记录均在此完成。

const INITIAL_BALANCE := 100000
const AIRCRAFT_STATUS_STORED := "stored"
const AIRCRAFT_STATUS_GROUNDED := "grounded"
const AIRCRAFT_STATUS_IN_FLIGHT := "in_flight"
const ID_FORMAT := "plane_%03d"
const AIRCRAFT_MODELS_PATH := "res://data/aircraft_models.json"
const SELL_RATIO := 0.8

var balance: int = INITIAL_BALANCE
var aircraft_instances: Array = []  # 元素: { id, model_id, status, current_city_id }
var finance_logs: Array = []       # 元素: { amount, type, desc }，新记录插在最前
var _models_by_id: Dictionary = {}
var _next_aircraft_index: int = 1

func _ready() -> void:
	_load_models()

func _load_models() -> void:
	var file := FileAccess.open(AIRCRAFT_MODELS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data = json.data
	if data is Array:
		for m in data:
			var mid := str(m.get("id", ""))
			_models_by_id[mid] = {
				"name": str(m.get("name", "")),
				"price": int(m.get("price", 0)),
				"speed": int(m.get("speed", 1))
			}

func get_balance() -> int:
	return balance

func get_aircraft_instances() -> Array:
	return aircraft_instances

func get_model_name(model_id: String) -> String:
	var info = _models_by_id.get(model_id, {})
	return str(info.get("name", model_id))

func get_model_speed(model_id: String) -> int:
	var info = _models_by_id.get(model_id, {})
	return int(info.get("speed", 1))

func get_finance_logs() -> Array:
	return finance_logs

func add_finance_log(amount: int, log_type: String, desc: String) -> void:
	finance_logs.insert(0, {"amount": amount, "type": log_type, "desc": desc})

## 购买飞机：扣款、生成实例、写入流水。余额不足返回 false。
func purchase_aircraft(model_id: String, price: int) -> bool:
	if balance < price:
		return false
	var new_id := _generate_aircraft_id()
	var model_name: String = get_model_name(model_id)
	balance -= price
	aircraft_instances.append({
		"id": new_id,
		"model_id": model_id,
		"status": AIRCRAFT_STATUS_STORED,
		"current_city_id": null
	})
	add_finance_log(-price, "buy_aircraft", "Buy aircraft %s %s" % [model_name, new_id])
	return true

## 卖出飞机：仅允许 stored；加款、删除实例、写入流水。
func sell_aircraft(aircraft_id: String) -> bool:
	var idx := -1
	for i in range(aircraft_instances.size()):
		if str(aircraft_instances[i].get("id", "")) == aircraft_id:
			idx = i
			break
	if idx < 0:
		return false
	var ac: Dictionary = aircraft_instances[idx]
	if str(ac.get("status", "")) != AIRCRAFT_STATUS_STORED:
		return false
	var model_id := str(ac.get("model_id", ""))
	var model_name: String = get_model_name(model_id)
	var info = _models_by_id.get(model_id, {})
	var buy_price: int = info.get("price", 0)
	var sell_price := int(buy_price * SELL_RATIO)
	balance += sell_price
	aircraft_instances.remove_at(idx)
	add_finance_log(sell_price, "sell_aircraft", "Sell aircraft %s %s" % [model_name, aircraft_id])
	return true

func _generate_aircraft_id() -> String:
	var id_str := ID_FORMAT % _next_aircraft_index
	_next_aircraft_index += 1
	return id_str
