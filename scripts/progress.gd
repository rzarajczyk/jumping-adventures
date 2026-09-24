extends Node

const SAVE_PATH := "user://progress.cfg"
var records: Dictionary = {}
var music_enabled := true
var effects_enabled := true
var save_path := SAVE_PATH

func _ready() -> void:
	load_progress()

static func stars_for(fish: int) -> int:
	return 3 if fish >= 10 else (2 if fish >= 5 else 1)

func best(difficulty: int, level: int) -> Dictionary:
	return records.get("%d_%d" % [difficulty, level], {"stars": 0, "fish": 0})

func unlocked(difficulty: int, level: int) -> bool:
	return level == 0 or int(best(difficulty, level - 1).stars) > 0

func complete(difficulty: int, level: int, fish: int) -> void:
	var old := best(difficulty, level)
	records["%d_%d" % [difficulty, level]] = {
		"stars": maxi(int(old.stars), stars_for(fish)),
		"fish": maxi(int(old.fish), clampi(fish, 0, 10))}
	save_progress()

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", 1)
	cfg.set_value("save", "records", records)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("audio", "effects", effects_enabled)
	var tmp := save_path + ".tmp"
	if cfg.save(tmp) == OK:
		DirAccess.rename_absolute(tmp, save_path)

func load_progress() -> void:
	records.clear()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	var saved = cfg.get_value("save", "records", {})
	if saved is Dictionary:
		for d in 3:
			for l in 3:
				var key := "%d_%d" % [d, l]
				var row = saved.get(key, {})
				if row is Dictionary and row.get("stars", 0) is int and row.get("fish", 0) is int:
					records[key] = {"stars": clampi(row.get("stars", 0), 0, 3), "fish": clampi(row.get("fish", 0), 0, 10)}
	music_enabled = bool(cfg.get_value("audio", "music", true))
	effects_enabled = bool(cfg.get_value("audio", "effects", true))
