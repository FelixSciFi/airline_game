class_name AircraftRecallSystem

## 飞机召回系统：将停放在城市的飞机送回机库。
## 逻辑仅在此脚本，UI 只负责调用。

const AIRCRAFT_STATUS_GROUNDED := "grounded"
const AIRCRAFT_STATUS_STORED := "stored"

## 将飞机从城市送回机库。
## game_world 需提供 get_player_state()。
## 成功返回 true，失败返回 false。
static func recall_aircraft(game_world: Node, aircraft_id: String) -> bool:
	var player_state: Node = game_world.get_player_state()
	if player_state == null:
		return false
	var instances: Array = player_state.get_aircraft_instances()
	var aircraft: Dictionary = _find_aircraft_by_id(instances, aircraft_id)
	if aircraft.is_empty():
		return false
	if str(aircraft.get("status", "")) != AIRCRAFT_STATUS_GROUNDED:
		return false
	aircraft["status"] = AIRCRAFT_STATUS_STORED
	aircraft["current_city_id"] = null
	return true

static func _find_aircraft_by_id(instances: Array, aircraft_id: String) -> Dictionary:
	for ac in instances:
		if str(ac.get("id", "")) == aircraft_id:
			return ac
	return {}
