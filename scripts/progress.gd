extends Node

const SAVE_PATH := "user://progress.cfg"
const TOTAL_STARS := 11
var records: Dictionary = {}
var selected_character := "penguin"
var music_enabled := true
var effects_enabled := true
var save_path := SAVE_PATH

func _ready() -> void:
	load_progress()

static func medals_for(collected: int) -> int:
	return 3 if collected >= 11 else (2 if collected >= 6 else (1 if collected >= 1 else 0))

func best(difficulty: int, level: int) -> Dictionary:
	return records.get("%d_%d" % [difficulty, level], {"medals": 0, "collected": 0})

func unlocked(difficulty: int, level: int) -> bool:
	return level == 0 or int(best(difficulty, level - 1).medals) > 0

func complete(difficulty: int, level: int, collected: int) -> void:
	var old := best(difficulty, level)
	records["%d_%d" % [difficulty, level]] = {
		"medals": maxi(int(old.medals), medals_for(collected)),
		"collected": maxi(int(old.collected), clampi(collected, 0, TOTAL_STARS))}
	save_progress()

func select_character(id: String) -> void:
	selected_character = AdventureCharacters.valid_id(id)
	save_progress()

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", 2)
	cfg.set_value("save", "records", records)
	cfg.set_value("save", "character", selected_character)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("audio", "effects", effects_enabled)
	var tmp := save_path + ".tmp"
	if cfg.save(tmp) == OK:
		DirAccess.rename_absolute(tmp, save_path)

func load_progress() -> void:
	records.clear()
	selected_character = "penguin"
	music_enabled = true
	effects_enabled = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	var saved = cfg.get_value("save", "records", {})
	var legacy := int(cfg.get_value("save", "version", 1)) < 2
	if saved is Dictionary:
		for d in 3:
			for l in 3:
				var key := "%d_%d" % [d, l]
				var row = saved.get(key, {})
				if not row is Dictionary:
					continue
				var medal = row.get("stars" if legacy else "medals", 0)
				var count = row.get("fish" if legacy else "collected", 0)
				if medal is int and count is int:
					# Old completed attempts also earned the new finish star.
					if legacy and medal > 0:
						count = clampi(count, 0, 10) + 1
					records[key] = {"medals": clampi(medal, 0, 3), "collected": clampi(count, 0, TOTAL_STARS)}
	selected_character = AdventureCharacters.valid_id(str(cfg.get_value("save", "character", "penguin")))
	music_enabled = bool(cfg.get_value("audio", "music", true))
	effects_enabled = bool(cfg.get_value("audio", "effects", true))
