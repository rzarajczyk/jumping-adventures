class_name AdventureCharacters
extends RefCounted

const IDS := ["penguin", "whale", "capybara", "kitten", "puppy", "panda", "otter", "beaver"]
const NAMES := ["Pingwin", "Wieloryb", "Kapibara", "Kotek", "Piesek", "Panda", "Wydra", "Bóbr"]

static func valid_id(id: String) -> String:
	return id if id in IDS else "penguin"

static func display_name(id: String) -> String:
	return NAMES[IDS.find(valid_id(id))]

static func frame(id: String, pose: String = "idle") -> Texture2D:
	id = valid_id(id)
	if id == "penguin":
		return PenguinArt.texture(id + ("" if pose == "idle" else "_" + pose))
	return PenguinArt.texture(id + "_" + pose)
