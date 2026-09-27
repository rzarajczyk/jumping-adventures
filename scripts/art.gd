class_name PenguinArt
extends RefCounted

static var cache: Dictionary = {}
# Atlas regions exclude transparent generator margins without altering source art.
const REGIONS := {
	"wind_bottle": Rect2(144, 42, 1021, 1173),
	"anchor": Rect2(136, 37, 982, 1188),
	"cloud_pack": Rect2(149, 66, 995, 1124),
	"whale_idle": Rect2(46, 167, 675, 406),
	"whale_blink": Rect2(769, 167, 676, 407),
	"whale_fly": Rect2(1488, 107, 660, 406),
	"capybara_idle": Rect2(115, 84, 562, 577),
	"capybara_blink": Rect2(794, 84, 561, 577),
	"capybara_fly": Rect2(1526, 59, 562, 576),
	"kitten_idle": Rect2(106, 27, 523, 670),
	"kitten_blink": Rect2(799, 30, 517, 667),
	"kitten_fly": Rect2(1494, 29, 574, 620),
	"puppy_idle": Rect2(115, 30, 537, 670),
	"puppy_blink": Rect2(766, 31, 547, 669),
	"puppy_fly": Rect2(1499, 23, 580, 632),
	"panda_idle": Rect2(134, 15, 513, 702),
	"panda_blink": Rect2(799, 15, 513, 702),
	"panda_fly": Rect2(1494, 6, 605, 689),
	"star": Rect2(64, 82, 1125, 1075),
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
	var source_name := name
	for id in ["whale", "capybara", "kitten", "puppy", "panda"]:
		if name.begins_with(id + "_"):
			source_name = id
	var path := "res://assets/art/%s.png" % source_name
	if not ResourceLoader.exists(path):
		return null
	var original: Texture2D = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = original
	atlas.region = REGIONS.get(name, Rect2(Vector2.ZERO, original.get_size()))
	cache[name] = atlas
	return atlas
