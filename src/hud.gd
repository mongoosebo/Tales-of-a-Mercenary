extends Node2D
## Screen-space UI: title screen, HUD, level-up cards, pause and game-over.

const W := 320.0
const H := 180.0

const C_DARK := Color8(20, 14, 28)
const C_PANEL := Color8(36, 24, 64)
const C_PANEL2 := Color8(56, 36, 96)
const C_PINK := Color8(236, 84, 200)
const C_CYAN := Color8(72, 228, 236)
const C_YELLOW := Color8(252, 220, 72)
const C_ORANGE := Color8(252, 136, 40)
const C_WHITE := Color8(248, 248, 236)
const C_RED := Color8(228, 44, 60)
const C_GREY := Color8(150, 140, 180)

const Data := preload("res://src/data.gd")
# mirrors game.gd's State enum
const TITLE := 0
const PLAY := 1
const LEVELUP := 2
const PAUSE := 3
const OVER := 4
const WIN := 5

var game  # game.gd


func _process(_delta: float) -> void:
	queue_redraw()


func card_rect(i: int) -> Rect2:
	return Rect2(36, 38 + i * 44, 248, 38)


func _draw() -> void:
	match game.state:
		TITLE:
			_draw_title()
			return
		_:
			_draw_hud()
	match game.state:
		LEVELUP:
			_draw_levelup()
		PAUSE:
			_draw_pause()
		OVER:
			_draw_over(false)
		WIN:
			_draw_over(true)
	_draw_touch_stick()


# ---------------------------------------------------------------- helpers

func _text(t: String, pos: Vector2, color: Color = C_WHITE, scale: int = 1, align: int = 0, shadow: bool = true) -> void:
	Art.draw_text(self, t, pos, color, scale, align, shadow)


func _panel(r: Rect2, fill: Color = C_PANEL, border: Color = C_CYAN) -> void:
	# SNES-style window: dark outline, coloured border, bevel highlight
	draw_rect(r.grow(1), C_DARK)
	draw_rect(r, border)
	draw_rect(r.grow(-1), C_DARK)
	draw_rect(r.grow(-2), fill)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 1)), Color(1, 1, 1, 0.12))


func _icon(id: String, pos: Vector2, scale: int = 1) -> void:
	var t: Texture2D = Art.icons.get(id)
	if t == null:
		return
	draw_texture_rect(t, Rect2(pos.round(), t.get_size() * scale), false)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	# XP bar
	draw_rect(Rect2(0, 0, W, 7), C_DARK)
	draw_rect(Rect2(1, 1, W - 2, 5), C_PANEL)
	var k: float = clampf(game.xp / game.xp_next, 0.0, 1.0)
	draw_rect(Rect2(1, 1, (W - 2) * k, 5), C_CYAN)
	draw_rect(Rect2(1, 1, (W - 2) * k, 1), Color(1, 1, 1, 0.5))
	_text("LV %d" % game.level, Vector2(W - 3, 9), C_YELLOW, 1, 2)

	# timer + kills
	_text(_fmt_time(game.time), Vector2(W / 2, 9), C_WHITE, 1, 1)
	_text("KO %d" % game.kills, Vector2(W - 3, 18), C_WHITE, 1, 2)

	# weapons row, passives row
	var x := 2.0
	for id in game.weapon_order:
		var w: Dictionary = game.weapons[id]
		_slot(Vector2(x, 9), Data.WEAPONS[id].icon, w.lvl)
		x += 13
	x = 2.0
	for id in game.passive_order:
		_slot(Vector2(x, 24), Data.PASSIVES[id].icon, game.passives[id])
		x += 13

	# HP bar bottom-left
	var hpk: float = clampf(game.hp / game.max_hp, 0.0, 1.0)
	draw_rect(Rect2(2, H - 9, 66, 7), C_DARK)
	draw_rect(Rect2(3, H - 8, 64 * hpk, 5), C_RED)
	draw_rect(Rect2(3, H - 8, 64 * hpk, 1), Color(1, 1, 1, 0.4))
	_text("%d" % ceili(maxf(0.0, game.hp)), Vector2(72, H - 10), C_WHITE)

	# event banner
	if game.banner_t > 0.0 and game.state == PLAY:
		if int(game.clock * 6.0) % 2 == 0:
			_text(game.banner, Vector2(W / 2, 40), C_RED if game.banner.begins_with("WARNING") else C_YELLOW, 1, 1)


func _slot(pos: Vector2, icon: String, lvl: int) -> void:
	draw_rect(Rect2(pos, Vector2(12, 14)), C_DARK)
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(10, 10)), C_PANEL)
	_icon(icon, pos + Vector2(1, 1))
	for i in lvl:
		draw_rect(Rect2(pos + Vector2(1 + i * 2, 12), Vector2(1, 1)), C_YELLOW)


# ---------------------------------------------------------------- level up

func _draw_levelup() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.02, 0.1, 0.65))
	var hue := fmod(game.clock * 0.5, 1.0)
	var title_col := Color.from_hsv(hue, 0.55, 1.0)
	_text("LEVEL UP!", Vector2(W / 2, 12), title_col, 2, 1)
	for i in game.choices.size():
		var r := card_rect(i)
		var info: Dictionary = game.choice_info(game.choices[i])
		var selected: bool = i == game.sel
		var border := C_YELLOW if selected and int(game.clock * 4.0) % 2 == 0 else (C_PINK if selected else C_CYAN)
		_panel(r, C_PANEL2 if selected else C_PANEL, border)
		draw_rect(Rect2(r.position + Vector2(5, 7), Vector2(24, 24)), C_DARK)
		_icon(info.icon, r.position + Vector2(7, 9), 2)
		_text(info.name, r.position + Vector2(35, 7), C_YELLOW)
		if info.tag != "":
			_text(info.tag, r.position + Vector2(r.size.x - 6, 7), C_CYAN if info.tag == "NEW!" else C_WHITE, 1, 2)
		_text(info.desc, r.position + Vector2(35, 21), C_WHITE)
		_text(str(i + 1), r.position + Vector2(-8, 15), C_GREY)
	_text("ARROWS + ENTER, 1-3, OR TAP A CARD", Vector2(W / 2, H - 10), C_GREY, 1, 1)


# ---------------------------------------------------------------- pause / over

func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.02, 0.1, 0.6))
	_panel(Rect2(70, 50, 180, 80))
	_text("PAUSED", Vector2(W / 2, 60), C_YELLOW, 2, 1)
	_text("ESC / P  -  RESUME", Vector2(W / 2, 90), C_WHITE, 1, 1)
	_text("M  -  MUTE SOUND", Vector2(W / 2, 104), C_WHITE, 1, 1)


func _draw_over(won: bool) -> void:
	var a := clampf(game.menu_t * 2.0, 0.0, 0.75)
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.02, 0.1, a))
	if game.menu_t < 0.4:
		return
	if won:
		_text("MISSION COMPLETE", Vector2(W / 2, 30), C_YELLOW, 2, 1)
		_text("YOU SURVIVED THE NIGHT!", Vector2(W / 2, 52), C_CYAN, 1, 1)
	else:
		_text("GAME OVER", Vector2(W / 2, 30), C_RED, 3, 1)
	_panel(Rect2(70, 70, 180, 64))
	_text("TIME", Vector2(84, 80), C_GREY)
	_text(_fmt_time(game.time), Vector2(236, 80), C_WHITE, 1, 2)
	_text("LEVEL", Vector2(84, 92), C_GREY)
	_text(str(game.level), Vector2(236, 92), C_WHITE, 1, 2)
	_text("KOS", Vector2(84, 104), C_GREY)
	_text(str(game.kills), Vector2(236, 104), C_WHITE, 1, 2)
	_text("SCORE", Vector2(84, 116), C_GREY)
	_text(str(game.score), Vector2(236, 116), C_YELLOW, 1, 2)
	if game.menu_t > 1.2 and int(game.clock * 2.0) % 2 == 0:
		_text("PRESS ANY KEY OR TAP TO RETRY", Vector2(W / 2, 150), C_WHITE, 1, 1)


# ---------------------------------------------------------------- touch stick

func _draw_touch_stick() -> void:
	if game.touch_idx < 0 or game.state != PLAY:
		return
	var o: Vector2 = game.touch_origin
	draw_arc(o, 20, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.0)
	draw_circle(o + game.touch_vec * 20.0, 6, Color(1, 1, 1, 0.35))


# ---------------------------------------------------------------- title

func _draw_title() -> void:
	var t: float = game.clock
	# synthwave sky: banded gradient
	var bands := [
		Color8(20, 10, 44), Color8(36, 14, 70), Color8(64, 18, 96), Color8(104, 24, 112),
		Color8(156, 36, 120), Color8(204, 60, 112), Color8(240, 96, 96),
	]
	var horizon := 108.0
	var bh := horizon / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0, i * bh, W, bh + 1), bands[i])
	# stars
	var srng := RandomNumberGenerator.new()
	srng.seed = 42
	for i in 40:
		var sp := Vector2(srng.randi_range(0, 319), srng.randi_range(0, 60))
		if (int(t * 3.0) + i) % 7 != 0:
			draw_rect(Rect2(sp, Vector2.ONE), Color(1, 1, 1, 0.7))
	# striped sun
	var sun_c := Vector2(W / 2, horizon - 6)
	var sun_r := 44.0
	for y in range(int(sun_c.y - sun_r), int(horizon)):
		var dy := y - sun_c.y
		var half := sqrt(maxf(0.0, sun_r * sun_r - dy * dy))
		var k := (y - (sun_c.y - sun_r)) / (sun_r * 2.0)
		# horizontal gaps that widen toward the bottom
		var stripe := int(y - sun_c.y + t * 6.0) % 8
		if y > sun_c.y - 10 and stripe < int(lerpf(0, 5, clampf((y - sun_c.y + 10) / 40.0, 0, 1))):
			continue
		draw_rect(Rect2(sun_c.x - half, y, half * 2.0, 1), C_YELLOW.lerp(C_PINK, k))
	# city skyline silhouette
	var crng := RandomNumberGenerator.new()
	crng.seed = 7
	var x := 0.0
	while x < W:
		var bw := crng.randi_range(10, 24)
		var bht := crng.randi_range(8, 30)
		draw_rect(Rect2(x, horizon - bht, bw, bht), Color8(28, 12, 48))
		for wy in range(int(horizon - bht + 3), int(horizon - 2), 4):
			for wx in range(int(x + 2), int(x + bw - 2), 4):
				if crng.randf() < 0.35:
					draw_rect(Rect2(wx, wy, 1, 1), C_YELLOW if crng.randf() < 0.7 else C_CYAN)
		x += bw + crng.randi_range(0, 3)
	# neon grid floor
	draw_rect(Rect2(0, horizon, W, H - horizon), Color8(18, 6, 36))
	draw_line(Vector2(0, horizon), Vector2(W, horizon), C_PINK, 1.0)
	var scroll := fmod(t * 0.6, 1.0)
	for i in 10:
		var z := (i + scroll) / 10.0
		var y: float = horizon + pow(z, 2.2) * (H - horizon)
		draw_line(Vector2(0, roundf(y)), Vector2(W, roundf(y)), Color(C_PINK, 0.25 + z * 0.6), 1.0)
	for i in range(-12, 13):
		var x0 := W / 2 + i * 6.0
		var x1 := W / 2 + i * 48.0
		draw_line(Vector2(x0, horizon), Vector2(x1, H), Color(C_PINK, 0.55), 1.0)

	# logo
	_text("TALES OF A", Vector2(W / 2, 16), C_CYAN, 1, 1)
	var logo := "MERCENARY"
	var lx := W / 2 - Art.text_width(logo, 3) / 2.0
	Art.draw_text(self, logo, Vector2(lx + 2, 28 + 2), C_PINK, 3, 0, false)
	Art.draw_text(self, logo, Vector2(lx, 28), C_YELLOW, 3, 0, true)
	# chrome shine line
	draw_rect(Rect2(lx, 31, Art.text_width(logo, 3), 1), Color(1, 1, 1, 0.55))
	_text("MIAMI 1986", Vector2(W / 2, 54), C_WHITE, 1, 1)

	# hero
	var frame := int(t * 4.0) % 2
	var ht: Texture2D = Art.tex["hero_%d" % frame]
	draw_texture_rect(Art.tex.shadow, Rect2(W / 2 - 18, 160, 36, 9), false)
	draw_texture_rect(ht, Rect2(W / 2 - 24, 118, 48, 48), false)

	if int(t * 2.0) % 2 == 0:
		_text("PRESS ANY KEY / TAP TO START", Vector2(W / 2, 100), C_WHITE, 1, 1)
	_text("WASD/ARROWS/STICK: MOVE", Vector2(4, H - 18), C_GREY)
	_text("GUNS FIRE BY THEMSELVES", Vector2(4, H - 9), C_GREY)
	_text("SURVIVE 15:00", Vector2(W - 4, H - 9), C_YELLOW, 1, 2)
