extends Node
## All pixel art lives here as text grids, turned into textures at startup.
## One character = one pixel; the palette below maps characters to colours.
## Keeps the repo free of binary art and makes sprites easy to tweak.

const PAL := {
	".": Color(0, 0, 0, 0),
	"k": Color8(20, 14, 28),     # outline
	"w": Color8(248, 248, 236),  # white
	"s": Color8(244, 184, 140),  # skin
	"S": Color8(196, 120, 88),   # skin shade
	"h": Color8(132, 72, 36),    # hair
	"H": Color8(84, 44, 24),
	"r": Color8(228, 44, 60),    # red
	"R": Color8(144, 20, 44),
	"b": Color8(64, 104, 208),   # denim
	"B": Color8(36, 60, 136),
	"g": Color8(84, 84, 104),    # gunmetal
	"G": Color8(156, 156, 176),
	"y": Color8(252, 220, 72),   # yellow
	"Y": Color8(212, 140, 32),
	"e": Color8(72, 200, 88),    # green
	"E": Color8(28, 116, 60),
	"p": Color8(236, 84, 200),   # neon pink
	"P": Color8(132, 40, 148),
	"c": Color8(72, 228, 236),   # neon cyan
	"C": Color8(36, 124, 168),
	"l": Color8(120, 76, 52),    # leather
	"L": Color8(68, 44, 36),
	"o": Color8(252, 136, 40),   # orange
	"n": Color8(44, 40, 64),     # ninja cloth
	"N": Color8(84, 80, 116),
	"m": Color8(184, 188, 204),  # metal
	"M": Color8(112, 116, 140),
	"v": Color8(56, 168, 72),    # army green
	"V": Color8(36, 104, 48),
}

# ------------------------------------------------------------------ sprites

const HERO_TOP := [
	"......kkkkk.....",
	".....khhhhhk....",
	"....khhhhhhhk...",
	".rr.krrrrrrrrk..",
	"..rrkhhskkkkkk..",
	"....khhsssssk...",
	"....khhsssSsk...",
	".....kkSsssk....",
	"....kvvwwwwvk...",
	"...kssvwwwwvsggk",
	"...kSkvwwwwvkkk.",
]
const HERO_LEGS_A := [
	"....kbbbbbbk....",
	"....kbbkkbbk....",
	"....kbbk.kbbk...",
	"....kBBk.kBBk...",
	"....kLLk.kLLk...",
]
const HERO_LEGS_B := [
	"....kbbbbbbk....",
	"...kbbk.kbbk....",
	"..kbbk...kbbk...",
	".kBBk.....kBBk..",
	".kLLk.....kLLk..",
]

const PUNK_TOP := [
	".......ee.......",
	"......keEk......",
	"......keEk......",
	".....kkeEkk.....",
	"....ksssssk.....",
	"....ksskskk.....",
	"....kssssSk.....",
	".....kSSSk......",
	"...kllllllllk...",
	"..klLlrrrrlLlk..",
	"..ksklrrrrlksk..",
]
const PUNK_LEGS_A := [
	"...k.kllllk.k...",
	"....knnnnnnk....",
	"....knnk.knnk...",
	"....knnk.knnk...",
	"....kLLk.kLLk...",
]
const PUNK_LEGS_B := [
	"...k.kllllk.k...",
	"...knnk.knnk....",
	"..knnk...knnk...",
	".knnk.....knnk..",
	".kLLk.....kLLk..",
]

const NINJA_TOP := [
	"................",
	"......kkkkk.....",
	".....knnnnnk....",
	"....knnnnnnnk...",
	".rr.krrrrrrrk...",
	"..rrknnwkwknk...",
	"....knnnnnnnk...",
	".....knnnnnk....",
	"....knnnnnnnk...",
	"...knnNnnnNnnk..",
	"...knkNnnnNknk..",
]
const NINJA_LEGS_A := [
	"....k.knnnk.k...",
	"....knnnnnnk....",
	"....knnk.knnk...",
	"....knnk.knnk...",
	"....kNNk.kNNk...",
]
const NINJA_LEGS_B := [
	"....k.knnnk.k...",
	"...knnk.knnk....",
	"..knnk...knnk...",
	".knnk.....knnk..",
	".kNNk.....kNNk..",
]

const BIKER_TOP := [
	"................",
	".....kkkkkk.....",
	"....kRRRRRRk....",
	"....kRrrrrRRk...",
	"....ksskkkkkk...",
	"....kssssssk....",
	"....khhhhhhk....",
	"...kkhhhhhhkk...",
	"..kssLLLLLLssk..",
	".ksssLlLLlLsssk.",
	".kskkLLLLLLkksk.",
]
const BIKER_LEGS_A := [
	".kk.kbbbbbbk.kk.",
	"....kBBBBBBk....",
	"....kBBk.kBBk...",
	"....kBBk.kBBk...",
	"...kLLLk.kLLLk..",
]
const BIKER_LEGS_B := [
	".kk.kbbbbbbk.kk.",
	"...kBBk.kBBk....",
	"..kBBk...kBBk...",
	".kBBk.....kBBk..",
	"kLLLk.....kLLLk.",
]

const ROBOT_TOP := [
	"......kkkk......",
	"......kmrk......",
	"....kkkmmkkk....",
	"...kmmmmmmmmk...",
	"...kmrrrrrrmk...",
	"...kmMMMMMMmk...",
	"....kkkkkkkk....",
	"...kmmmmmmmmk...",
	"..kmkmMccMmkmk..",
	"..kmkmMccMmkmk..",
	"..kMkmmmmmmkMk..",
]
const ROBOT_LEGS_A := [
	"..kk.kMMMMk.kk..",
	".....kmkkmk.....",
	"....kmmk.kmmk...",
	"....kMMk.kMMk...",
	"...kkkkk.kkkkk..",
]
const ROBOT_LEGS_B := [
	"..kk.kMMMMk.kk..",
	"....kmk..kmk....",
	"...kmmk...kmmk..",
	"...kMMk...kMMk..",
	"..kkkkk...kkkkk.",
]

const BULLET := [
	".Yyw",
	"Yyyw",
	".Yyw",
]
const PELLET := [
	".o.",
	"oyo",
	".o.",
]
const GRENADE := [
	"..kk..",
	".kVvk.",
	"kvvvVk",
	"kvVvvk",
	".kvvk.",
	"..kk..",
]
const CHUCK := [
	"kk.....",
	"klk....",
	".klk...",
	"..kyk..",
	"...klk.",
	"....klk",
	".....kk",
]
const ROCKET := [
	"..kkkk..",
	"okVvvvmk",
	"ykVvvvmmk",
	"okVvvvmk",
	"..kkkk..",
]
const GEM := [
	"..k..",
	".kck.",
	"kcwck",
	"kccCk",
	".kCk.",
	"..k..",
]
const PIZZA := [
	"kkkkkkkk",
	"kYYYYYYk",
	".kyryyrk",
	".kyyyyk.",
	"..kryk..",
	"..kyyk..",
	"...kk...",
]
const MAGNET := [
	"kk....kk",
	"wk....kw",
	"rk....kr",
	"rk....kr",
	"rrk..krr",
	".rrkkrr.",
	"..rrrr..",
]
const CASE := [
	"...kkkk...",
	"...k..k...",
	"kkkkkkkkkk",
	"kLllllllLk",
	"klllyylllk",
	"kLllyyllLk",
	"klllllllLk",
	"kkkkkkkkkk",
]

const PALM := [
	"....ee.....ee...",
	"..eeEEe...eEEee.",
	".eE...eeeee...Ee",
	"eE...eeEEEee...E",
	"e...eE.ll.Ee....",
	"...eE..lL..Ee...",
	"..e....lL....e..",
	".......lL.......",
	"......lL........",
	"......lL........",
	"......lLl.......",
	".......lL.......",
	".......lL.......",
	".......llL......",
	"........lL......",
	"........lL......",
	"........lL......",
	".......llL......",
	".......lLl......",
	".......lL.......",
	".......lL.......",
	"......llLl......",
	".....kllLlk.....",
	"......kkkk......",
]
const DRUM := [
	".kkkkkk.",
	"kCCCCCCk",
	"kccccCCk",
	"kkkkkkkk",
	"kccwcCCk",
	"kccwcCCk",
	"kkkkkkkk",
	"kccccCCk",
	"kccccCCk",
	".kkkkkk.",
]
const CRATE := [
	"kkkkkkkkkk",
	"kYyyyyyyYk",
	"kyYyyyyYyk",
	"kyyYyyYyyk",
	"kyyyYYyyyk",
	"kyyyYYyyyk",
	"kyyYyyYyyk",
	"kyYyyyyYyk",
	"kYyyyyyyYk",
	"kkkkkkkkkk",
]

# Beach boss: slick hair, one-piece wraparound shades, pink suit, minigun
const DON_TOP := [
	"......kkkkk.....",
	".....knnnnnk....",
	"....knnNnnnnk...",
	"....knssssssk...",
	"....kkkkkkkkkk..",
	"....kkkkckkkkk..",
	"....kssssSssk...",
	".....ksSSSsk....",
	"...kppwyywppk...",
	"..kpppwyywpppkkk",
	"..kpkpwwwwkmmmmk",
]
const DON_LEGS_A := [
	"..ksk.kwwkkMmmmk",
	"....kpppppkkkkk.",
	"....kppk.kppk...",
	"....kppk.kppk...",
	"....kwwk.kwwk...",
]
const DON_LEGS_B := [
	"..ksk.kwwkkMmmmk",
	"...kppk.kppkkkk.",
	"..kppk...kppk...",
	".kppk.....kppk..",
	".kwwk.....kwwk..",
]

const BOAT := [
	"...........kkk..................",
	"..........kcck..................",
	".....kkkkkkcckkkkkkkkkkkk.......",
	"....krrrrrrrrrrrrrrrrrrrrkkk....",
	"...kwwwwwwwwwwwwwwwwwwwwwwwwkk..",
	"..kwwwwwwwwkkwwwwwwwwwwwwwwwwwk.",
	".kwwwwwwwwk..kwwwwrrrrrrwwwwwwwk",
	"..kmmmmmmmmkkmmmmmmmmmmmmmmmmmk.",
	"...kMMMMMMMMMMMMMMMMMMMMMMMMMk..",
	"....kkkkkkkkkkkkkkkkkkkkkkkkk...",
]
const UMBRELLA := [
	"......kkkkk.....",
	"...kkpwpwpwpkk..",
	"..kpwpwpwpwpwpk.",
	".kpwpwpwpwpwpwpk",
	".kkkkkkkkkkkkkkk",
	".......kl.......",
	".......kl.......",
	".......kl.......",
	".......kl.......",
	".......kl.......",
	".......kl.......",
	"......kkllk.....",
]
const SNOW := [
	".....kk.....",
	"....kwwk....",
	"...kwwwmk...",
	"..kwwwwwmk..",
	".kwwwwwwwmk.",
	"kccccccccccc",
	"kCCCCCCCCCCk",
]
const M16 := [
	"......kkk.......",
	"kkkkkkkGkkkkkkk.",
	"kgggggggggggggGk",
	"kgkkkkgkkkkkkkk.",
	"kk...kgkk.......",
	".....kgggk......",
	"......kkk.......",
]
const MACE := [
	".........kkkk..",
	"kkkk.kkkkyyyyk.",
	"kLLkkyyyyyyyyyk",
	"kLLkkyyyyyyyyyk",
	"kkkk.kkkkyyyyk.",
	".........kkkk..",
]
const BOLT := [
	"r......",
	"lllllmw",
	"r......",
]

# ------------------------------------------------------------------ icons (10x10)

const ICONS := {
	"pistol": [
		"..........",
		".kkkkkkkk.",
		"kGGGGGGGGk",
		"kggggggggk",
		"kgggkkkkk.",
		"kggk.k....",
		"kggk......",
		"kggk......",
		".kk.......",
		"..........",
	],
	"uzi": [
		"..........",
		"kkkkkkkkk.",
		"kGGGGGGGGk",
		"kggggggggk",
		".kgkkgk...",
		".kgk.gk...",
		".kgk.kgk..",
		"..k...gk..",
		"......kk..",
		"..........",
	],
	"shotgun": [
		"..........",
		"..........",
		"kk........",
		"kLkkkkkkkk",
		"kllGGGGGGk",
		"klLkgkkkkk",
		"kk..kk....",
		"..........",
		"..........",
		"..........",
	],
	"grenade": [
		"....kk....",
		"...kGk.k..",
		"..kkkkk...",
		".kvvVVvk..",
		"kvvVvvVvk.",
		"kvVvvvVvk.",
		"kvvVVvvvk.",
		".kvvvvvk..",
		"..kkkkk...",
		"..........",
	],
	"boombox": [
		"..kkkkkk..",
		"..k....k..",
		"kkkkkkkkkk",
		"kmmmmmmmmk",
		"kMkkmmkkMk",
		"kkpkmmkpkk",
		"kMkkmmkkMk",
		"kmmmmmmmmk",
		"kkkkkkkkkk",
		"..........",
	],
	"chucks": [
		"kk........",
		"klk.......",
		"kllk......",
		".kllk.....",
		"..kk.k....",
		"......k...",
		".....kk...",
		"....kllk..",
		"....kllk..",
		"....kllk..",
	],
	"rocket": [
		"..........",
		"..........",
		"kkkkkkkkk.",
		"kvVvvvvvVk",
		"kVvvvvvvVkk",
		"kkkkgkkkkk",
		"....gk....",
		"....kk....",
		"..........",
		"..........",
	],
	"ak": [
		"..........",
		"..........",
		"kkkkkkkkkk",
		"klllgggggk",
		"kllkgkkkkk",
		"kkk.lk....",
		"....lk....",
		"....kk....",
		"..........",
		"..........",
	],
	"crossbow": [
		"....k.....",
		"....lk....",
		"....l.k...",
		"....l..k..",
		"kkkklmmmmw",
		"....l..k..",
		"....l.k...",
		"....lk....",
		"....k.....",
		"..........",
	],
	"mace": [
		"......kkk.",
		".....kyyyk",
		"....kyyyyk",
		"...kyyyyk.",
		"..kyyyk...",
		".kLLk.....",
		"kLLk......",
		"kkk.......",
		"..........",
		"..........",
	],
	"snow": [
		"..........",
		"....kk....",
		"...kwwk...",
		"..kwwwmk..",
		".kwwwwwmk.",
		"kccccccccc",
		"kCCCCCCCCk",
		"..........",
		"..........",
		"..........",
	],
	"tape": [
		"..........",
		"kkkkkkkkkk",
		"kppppppppk",
		"kpwwwwwwpk",
		"kpwkwwkwpk",
		"kpwwwwwwpk",
		"kppppppppk",
		"kpkkkkkkpk",
		"kkkkkkkkkk",
		"..........",
	],
	"dumbbell": [
		"..........",
		"kk......kk",
		"kmk....kmk",
		"kmkkkkkkmk",
		"kmMMMMMMmk",
		"kmkkkkkkmk",
		"kmk....kmk",
		"kk......kk",
		"..........",
		"..........",
	],
	"vest": [
		".kk....kk.",
		"kvvk..kvvk",
		"kvvvkkvvvk",
		"kvvvvvvvvk",
		"kvVvvvvVvk",
		"kvvvvvvvvk",
		"kvVvvvvVvk",
		"kvvvvvvvvk",
		".kkkkkkkk.",
		"..........",
	],
	"cola": [
		"..kkkk....",
		".kmmmmk...",
		".krrrrk...",
		".krwwrk...",
		".krwrrk...",
		".krwwrk...",
		".krrrrk...",
		".kmmmmk...",
		"..kkkk....",
		"..........",
	],
	"hairspray": [
		"......w.w.",
		"....kk.w..",
		"...kmk..w.",
		"..kppk....",
		"..kppk....",
		"..kPpk....",
		"..kppk....",
		"..kPpk....",
		"..kkkk....",
		"..........",
	],
	"walkman": [
		".kkkkkkk..",
		"kccccccck.",
		"kckkkkkck.",
		"kckwkwkck.",
		"kckkkkkck.",
		"kccccccck.",
		"kcyycrrck.",
		"kkkkkkkkk.",
		"..........",
		"..........",
	],
	"magnet": [
		"..........",
		".kk....kk.",
		".wk....kw.",
		".rk....kr.",
		".rk....kr.",
		".rrk..krr.",
		"..rrkkrr..",
		"...rrrr...",
		"..........",
		"..........",
	],
	"heart": [
		"..........",
		".kk..kk...",
		"krrkkrrk..",
		"krwrrrrrk.",
		"krrrrrrrk.",
		".krrrrrk..",
		"..krrrk...",
		"...krk....",
		"....k.....",
		"..........",
	],
	"headband": [
		"..........",
		"..........",
		"..........",
		"rrrrrrrrrr",
		"RrrrrrrrrR",
		"..........",
		"rr........",
		".rr.......",
		"..r.......",
		"..........",
	],
	"pizza": [
		"..........",
		"kkkkkkkk..",
		"kYYYYYYk..",
		".kyryyrk..",
		".kyyyyk...",
		"..kryk....",
		"..kyyk....",
		"...kk.....",
		"..........",
		"..........",
	],
	"cash": [
		"..........",
		"kkkkkkkkkk",
		"keeeeeeeek",
		"keEkeekEek",
		"keekyykeek",
		"keEkeekEek",
		"keeeeeeeek",
		"kkkkkkkkkk",
		"..........",
		"..........",
	],
}

# ------------------------------------------------------------------ 5x7 font

const FONT_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:!?-+%/'()<>* "
const FONT := [
	[".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	[".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	[".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	[".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	[".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	[".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	[".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	[".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	[".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	[".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	[".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	[".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	[".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
	[".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
	["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	[".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	[".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	[".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
	[".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
	["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
	[".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
	[".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
	[".....", ".....", ".....", ".....", ".....", ".....", "....."],
]
const GLYPH_W := 5
const GLYPH_H := 7
const GLYPH_ADV := 6

var tex := {}
var icons := {}
var font_tex: ImageTexture
var font_index := {}


func _init() -> void:
	tex["hero_0"] = make(HERO_TOP + HERO_LEGS_A)
	tex["hero_1"] = make(HERO_TOP + HERO_LEGS_B)
	tex["punk_0"] = make(PUNK_TOP + PUNK_LEGS_A)
	tex["punk_1"] = make(PUNK_TOP + PUNK_LEGS_B)
	tex["ninja_0"] = make(NINJA_TOP + NINJA_LEGS_A)
	tex["ninja_1"] = make(NINJA_TOP + NINJA_LEGS_B)
	tex["biker_0"] = make(BIKER_TOP + BIKER_LEGS_A)
	tex["biker_1"] = make(BIKER_TOP + BIKER_LEGS_B)
	tex["robot_0"] = make(ROBOT_TOP + ROBOT_LEGS_A)
	tex["robot_1"] = make(ROBOT_TOP + ROBOT_LEGS_B)
	# Boss: a gold-chained kingpin, recoloured biker
	tex["boss_0"] = make(BIKER_TOP + BIKER_LEGS_A, {"R": "P", "r": "p", "L": "n", "l": "y"})
	tex["boss_1"] = make(BIKER_TOP + BIKER_LEGS_B, {"R": "P", "r": "p", "L": "n", "l": "y"})
	tex["bullet"] = make(BULLET)
	tex["pellet"] = make(PELLET)
	tex["grenade"] = make(GRENADE)
	tex["chuck"] = make(CHUCK)
	tex["rocket"] = make(ROCKET)
	tex["gem_0"] = make(GEM)
	tex["gem_1"] = make(GEM, {"c": "e", "C": "E"})
	tex["gem_2"] = make(GEM, {"c": "p", "C": "P"})
	tex["pizza"] = make(PIZZA)
	tex["magnet"] = make(MAGNET)
	tex["case"] = make(CASE)
	tex["palm"] = make(PALM)
	tex["drum"] = make(DRUM)
	tex["crate"] = make(CRATE)
	tex["don_0"] = make(DON_TOP + DON_LEGS_A)
	tex["don_1"] = make(DON_TOP + DON_LEGS_B)
	tex["boat"] = make(BOAT)
	tex["umbrella"] = make(UMBRELLA)
	tex["snow"] = make(SNOW)
	tex["m16"] = make(M16)
	tex["mace"] = make(MACE)
	tex["bolt"] = make(BOLT)
	tex["sand"] = _make_sand()
	tex["shadow"] = _make_shadow(12, 4)
	tex["shadow_big"] = _make_shadow(22, 6)
	tex["floor"] = _make_floor()
	for k in ICONS:
		icons[k] = make(ICONS[k])
	_make_font()


func make(rows: Array, swap: Dictionary = {}) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = max(w, (r as String).length())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if swap.has(ch):
				ch = swap[ch]
			img.set_pixel(x, y, PAL.get(ch, Color(1, 0, 1)))
	return ImageTexture.create_from_image(img)


func _make_shadow(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(w / 2.0, h / 2.0)
	for y in h:
		for x in w:
			var d := Vector2((x + 0.5 - c.x) / (w / 2.0), (y + 0.5 - c.y) / (h / 2.0))
			if d.length() <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.35))
	return ImageTexture.create_from_image(img)


func _make_floor() -> ImageTexture:
	# 64x64 night-time asphalt with paving seams, grit and the odd crack.
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var base := Color8(52, 46, 72)
	var dark := Color8(40, 34, 58)
	var light := Color8(64, 58, 88)
	var seam := Color8(34, 28, 50)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1986
	for y in size:
		for x in size:
			var c := base
			var r := rng.randf()
			if r < 0.08:
				c = dark
			elif r < 0.12:
				c = light
			if x == 0 or y == 0:
				c = seam
			elif x == 1 or y == 1:
				c = light
			img.set_pixel(x, y, c)
	# a couple of cracks
	for crack in [[Vector2i(8, 40), 9], [Vector2i(44, 10), 7]]:
		var p: Vector2i = crack[0]
		for i in int(crack[1]):
			img.set_pixelv(p, seam)
			p += Vector2i(1, rng.randi_range(-1, 1))
			p.x = clampi(p.x, 2, size - 2)
			p.y = clampi(p.y, 2, size - 2)
	return ImageTexture.create_from_image(img)


func _make_sand() -> ImageTexture:
	# 64x64 warm sand with grain, little shells and footprints
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var base := Color8(232, 196, 132)
	var dark := Color8(208, 168, 108)
	var light := Color8(248, 220, 160)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	for y in size:
		for x in size:
			var c := base
			var r := rng.randf()
			if r < 0.12:
				c = dark
			elif r < 0.18:
				c = light
			# soft wind ripples
			if (x + y * 3 + int(sin(x * 0.3) * 2.0)) % 23 == 0:
				c = dark
			img.set_pixel(x, y, c)
	for shell in [Vector2i(12, 20), Vector2i(44, 50), Vector2i(50, 8)]:
		img.set_pixelv(shell, Color8(248, 248, 236))
		img.set_pixelv(shell + Vector2i(1, 0), Color8(236, 150, 170))
	return ImageTexture.create_from_image(img)


func _make_font() -> void:
	var n := FONT_CHARS.length()
	var img := Image.create(n * GLYPH_W, GLYPH_H, false, Image.FORMAT_RGBA8)
	for i in n:
		font_index[FONT_CHARS[i]] = i
		var g: Array = FONT[i]
		for y in GLYPH_H:
			var row: String = g[y]
			for x in GLYPH_W:
				if row[x] == "#":
					img.set_pixel(i * GLYPH_W + x, y, Color.WHITE)
	font_tex = ImageTexture.create_from_image(img)


func text_width(text: String, scale: int = 1) -> int:
	return text.length() * GLYPH_ADV * scale - scale


## Draws pixel text onto any CanvasItem during its _draw().
## align: 0 = left, 1 = centred on pos.x, 2 = right-aligned to pos.x
func draw_text(ci: CanvasItem, text: String, pos: Vector2, color: Color = Color.WHITE,
		scale: int = 1, align: int = 0, shadow: bool = true) -> void:
	text = text.to_upper()
	var x := pos.x
	if align == 1:
		x -= text_width(text, scale) / 2.0
	elif align == 2:
		x -= text_width(text, scale)
	x = floorf(x)
	var y := floorf(pos.y)
	var sh := Color(0.04, 0.02, 0.08, color.a)
	for i in text.length():
		var ch := text[i]
		var idx: int = font_index.get(ch, -1)
		if idx >= 0 and ch != " ":
			var src := Rect2(idx * GLYPH_W, 0, GLYPH_W, GLYPH_H)
			if shadow:
				ci.draw_texture_rect_region(font_tex,
					Rect2(x + scale, y + scale, GLYPH_W * scale, GLYPH_H * scale), src, sh)
			ci.draw_texture_rect_region(font_tex,
				Rect2(x, y, GLYPH_W * scale, GLYPH_H * scale), src, color)
		x += GLYPH_ADV * scale
