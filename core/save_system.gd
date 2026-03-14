class_name SaveSystem
extends RefCounted

const SAVE_PATH := "user://savegame.json"

static func save_game(data: Dictionary) -> bool:
	var json_str: String = JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("[SaveSystem] Save failed")
		return false
	file.store_string(json_str)
	file.close()
	print("[SaveSystem] Save success")
	return true

static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveSystem] No save file")
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("[SaveSystem] Load failed: cannot open file")
		return {}
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty():
		print("[SaveSystem] Load failed: empty file")
		return {}
	var data = JSON.parse_string(text)
	if data == null:
		print("[SaveSystem] Load failed: JSON parse error")
		return {}
	if typeof(data) != TYPE_DICTIONARY:
		print("[SaveSystem] Load failed: not a Dictionary")
		return {}
	print("[SaveSystem] Load success")
	return data

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveSystem] No save file to delete")
		return true
	var dir := DirAccess.open("user://")
	if dir == null:
		print("[SaveSystem] Delete failed")
		return false
	var err: Error = dir.remove("savegame.json")
	if err != OK:
		print("[SaveSystem] Delete failed")
		return false
	print("[SaveSystem] Delete success")
	return true
