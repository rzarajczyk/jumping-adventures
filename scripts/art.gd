class_name PenguinArt
extends RefCounted

static var cache: Dictionary = {}
# Atlas regions exclude transparent generator margins without altering source art.
const REGIONS := {
	"penguin": Rect2(228, 108, 846, 1040),
	"penguin_blink": Rect2(228, 108, 846, 1040),
	"penguin_fly": Rect2(228, 108, 846, 1040),
	"garden": Rect2(35, 166, 1915, 492),
	"crystal": Rect2(29, 216, 1925, 402),
	"aurora": Rect2(39, 120, 1908, 548),
	"fish": Rect2(358, 158, 822, 650),
}

static func texture(name: String) -> Texture2D:
	if cache.has(name):
		return cache[name]
	var path := "res://assets/art/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	var original: Texture2D = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = original
	atlas.region = REGIONS.get(name, Rect2(Vector2.ZERO, original.get_size()))
	cache[name] = atlas
	return atlas
