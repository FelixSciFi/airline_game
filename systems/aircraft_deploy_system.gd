class_name AircraftDeploySystem

## 飞机部署系统：将机库中的飞机部署到指定城市。
## 逻辑仅在此脚本，UI 只负责调用。

const AIRCRAFT_STATUS_STORED := "stored"

## 将飞机从机库部署到城市。
## game_world 需提供 get_player_state() 与 get_cities()。
## 成功返回 true，失败返回 false。
static func deploy_aircraft(game_world: Node, aircraft_id: String, city_id: String) -> bool:
	var player_state: Node = game_world.get_player_state()
	if player_state == null:
		return false
	var instances: Array = player_state.get_aircraft_instances()
	var aircraft: Dictionary = _find_aircraft_by_id(instances, aircraft_id)
	if aircraft.is_empty():
		return false
	if str(aircraft.get("status", "")) != AIRCRAFT_STATUS_STORED:
		return false
	var cities: Array = game_world.get_cities()
	if not _city_exists(cities, city_id):
		return false
	aircraft["status"] = "grounded"
	aircraft["current_city_id"] = city_id
	return true

static func _find_aircraft_by_id(instances: Array, aircraft_id: String) -> Dictionary:
	for ac in instances:
		if str(ac.get("id", "")) == aircraft_id:
			return ac
	return {}

static func _city_exists(cities: Array, city_id: String) -> bool:
	for city in cities:
		if str(city.get("id", "")) == city_id:
			return true
	return false
