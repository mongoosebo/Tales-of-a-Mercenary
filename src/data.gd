extends RefCounted
## Game data: weapons, passive items and enemies. Tweak balance here.

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6

const WEAPON_ORDER := ["pistol", "uzi", "shotgun", "grenade", "boombox", "chucks", "rocket"]

const WEAPONS := {
	"pistol": {
		"name": "9MM PISTOL", "icon": "pistol",
		"desc": ["FIRES AT THE NEAREST ENEMY", "+1 BULLET", "+5 DAMAGE",
			"+1 BULLET, FASTER RELOAD", "BULLETS PIERCE +1 ENEMY", "+1 BULLET, +5 DAMAGE"],
	},
	"uzi": {
		"name": "UZI", "icon": "uzi",
		"desc": ["SPRAYS BULLETS WHERE YOU FACE", "+3 BULLETS PER BURST", "+3 DAMAGE",
			"FASTER RELOAD", "+4 BULLETS PER BURST", "+3 DAMAGE, PIERCE +1"],
	},
	"shotgun": {
		"name": "SHOTGUN", "icon": "shotgun",
		"desc": ["CLOSE RANGE BLAST, BIG KNOCKBACK", "+2 PELLETS", "+4 DAMAGE",
			"FASTER RELOAD", "+3 PELLETS, LONGER RANGE", "+5 DAMAGE, PIERCE +1"],
	},
	"grenade": {
		"name": "GRENADES", "icon": "grenade",
		"desc": ["LOBS EXPLOSIVES AT ENEMIES", "+1 GRENADE", "BIGGER BLAST",
			"+12 DAMAGE", "+1 GRENADE, FASTER THROWS", "HUGE BLAST, +10 DAMAGE"],
	},
	"boombox": {
		"name": "BOOMBOX", "icon": "boombox",
		"desc": ["SOUND WAVES HURT NEARBY FOES", "BIGGER RANGE", "+3 DAMAGE",
			"FASTER BEAT", "BIGGER RANGE", "+5 DAMAGE"],
	},
	"chucks": {
		"name": "NUNCHUCKS", "icon": "chucks",
		"desc": ["NUNCHUCKS SPIN AROUND YOU", "+1 NUNCHUCK", "+6 DAMAGE",
			"SPIN FASTER AND WIDER", "+1 NUNCHUCK", "+1 NUNCHUCK, +8 DAMAGE"],
	},
	"rocket": {
		"name": "BAZOOKA", "icon": "rocket",
		"desc": ["HOMING ROCKET, BIG EXPLOSION", "+15 DAMAGE", "+1 ROCKET",
			"BIGGER BLAST", "FASTER RELOAD", "+1 ROCKET, +20 DAMAGE"],
	},
}

const PASSIVE_ORDER := ["tape", "dumbbell", "vest", "cola", "hairspray", "walkman", "magnet", "heart", "headband"]

const PASSIVES := {
	"tape": {"name": "AEROBICS TAPE", "icon": "tape", "desc": "+8% MOVE SPEED", "max": 5},
	"dumbbell": {"name": "PUMPING IRON", "icon": "dumbbell", "desc": "+10% DAMAGE", "max": 5},
	"vest": {"name": "KEVLAR VEST", "icon": "vest", "desc": "-8% DAMAGE TAKEN", "max": 5},
	"cola": {"name": "JOLT COLA", "icon": "cola", "desc": "-7% WEAPON COOLDOWN", "max": 5},
	"hairspray": {"name": "HAIRSPRAY", "icon": "hairspray", "desc": "+10% AREA (BIG HAIR!)", "max": 5},
	"walkman": {"name": "WALKMAN", "icon": "walkman", "desc": "+10% EXPERIENCE", "max": 5},
	"magnet": {"name": "MAGNET BELT", "icon": "magnet", "desc": "+30% PICKUP RANGE", "max": 5},
	"heart": {"name": "BEEF JERKY", "icon": "heart", "desc": "+20 MAX HP, +0.2 HP/SEC", "max": 5},
	"headband": {"name": "LUCKY HEADBAND", "icon": "headband", "desc": "+1 PROJECTILE FOR GUNS", "max": 2},
}

const ENEMIES := {
	"punk": {"hp": 8.0, "speed": 30.0, "dmg": 10.0, "xp": 1, "r": 5.0, "scale": 1.0},
	"ninja": {"hp": 6.0, "speed": 50.0, "dmg": 8.0, "xp": 1, "r": 5.0, "scale": 1.0},
	"biker": {"hp": 35.0, "speed": 24.0, "dmg": 16.0, "xp": 3, "r": 6.0, "scale": 1.0},
	"robot": {"hp": 80.0, "speed": 20.0, "dmg": 22.0, "xp": 8, "r": 6.0, "scale": 1.0},
	"boss": {"hp": 1400.0, "speed": 32.0, "dmg": 35.0, "xp": 0, "r": 13.0, "scale": 2.0},
}


static func weapon_max(_id: String) -> int:
	return 6


## Returns the stats for a weapon at a given level (1..6).
static func weapon_stats(id: String, lvl: int) -> Dictionary:
	var s := {}
	match id:
		"pistol":
			s = {"dmg": 10.0, "cd": 1.0, "count": 1, "pierce": 1, "speed": 240.0}
			if lvl >= 2: s.count += 1
			if lvl >= 3: s.dmg += 5
			if lvl >= 4: s.count += 1; s.cd -= 0.2
			if lvl >= 5: s.pierce += 1
			if lvl >= 6: s.count += 1; s.dmg += 5
		"uzi":
			s = {"dmg": 5.0, "cd": 1.4, "count": 5, "pierce": 1, "speed": 260.0, "spread": 0.16}
			if lvl >= 2: s.count += 3
			if lvl >= 3: s.dmg += 3
			if lvl >= 4: s.cd -= 0.35
			if lvl >= 5: s.count += 4
			if lvl >= 6: s.dmg += 3; s.pierce += 1
		"shotgun":
			s = {"dmg": 7.0, "cd": 1.6, "count": 5, "pierce": 2, "speed": 250.0, "spread": 0.55, "life": 0.3, "knock": 90.0}
			if lvl >= 2: s.count += 2
			if lvl >= 3: s.dmg += 4
			if lvl >= 4: s.cd -= 0.4
			if lvl >= 5: s.count += 3; s.life += 0.1
			if lvl >= 6: s.dmg += 5; s.pierce += 1
		"grenade":
			s = {"dmg": 22.0, "cd": 2.6, "count": 1, "radius": 26.0}
			if lvl >= 2: s.count += 1
			if lvl >= 3: s.radius += 8
			if lvl >= 4: s.dmg += 12
			if lvl >= 5: s.count += 1; s.cd -= 0.5
			if lvl >= 6: s.radius += 10; s.dmg += 10
		"boombox":
			s = {"dmg": 5.0, "cd": 0.6, "radius": 30.0, "knock": 30.0}
			if lvl >= 2: s.radius += 7
			if lvl >= 3: s.dmg += 3
			if lvl >= 4: s.cd -= 0.15
			if lvl >= 5: s.radius += 8
			if lvl >= 6: s.dmg += 5
		"chucks":
			s = {"dmg": 12.0, "count": 2, "radius": 30.0, "spin": 3.5, "cd": 0.5}
			if lvl >= 2: s.count += 1
			if lvl >= 3: s.dmg += 6
			if lvl >= 4: s.spin += 1.5; s.radius += 6
			if lvl >= 5: s.count += 1
			if lvl >= 6: s.count += 1; s.dmg += 8
		"rocket":
			s = {"dmg": 40.0, "cd": 3.0, "count": 1, "radius": 30.0, "speed": 150.0}
			if lvl >= 2: s.dmg += 15
			if lvl >= 3: s.count += 1
			if lvl >= 4: s.radius += 10
			if lvl >= 5: s.cd -= 0.8
			if lvl >= 6: s.count += 1; s.dmg += 20
	return s
