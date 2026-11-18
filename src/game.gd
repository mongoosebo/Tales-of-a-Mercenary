extends Node2D
## Tales of a Mercenary - main game logic.
##
## Enemies, shots, pickups and effects are plain objects drawn in a few batched
## _draw() passes rather than one node each, so hundreds of enemies stay cheap
## (important for the web build).
##
## Level 1 (beach) is a horizontal strip: endless to the left and right, with the
## dunes to the north and the ocean to the south. At 20:00 a pier appears with the
## boss on it; beat him and walk north to reach level 2 (Main Street).

const Data := preload("res://src/data.gd")
const Drawer := preload("res://src/drawer.gd")
const Hud := preload("res://src/hud.gd")

const CELL := 24.0
const MAX_ENEMIES := 360
const MAX_GEMS := 400
const BASE_SPEED := 72.0
const BASE_MAGNET := 26.0
const PROP_CELL := 112

# beach geometry (world y)
const BEACH_TOP := -60.0       # player can't walk further north (dunes)
const BEACH_BOTTOM := 40.0     # ...or further south (water)
const ENEMY_TOP := -76.0
const ENEMY_BOTTOM := 46.0
const SHORE_Y := 50.0
const DUNE_Y := -72.0

# dodge roll
const DODGE_TIME := 0.28
const DODGE_SPEED := 240.0
const DODGE_IFRAMES := 0.45
const DODGE_COOLDOWN := 0.9

enum State { TITLE, PLAY, LEVELUP, PAUSE, OVER, WIN, TRANSITION }


class Enemy:
	var kind := ""
	var pos := Vector2.ZERO
	var hp := 1.0
	var max_hp := 1.0
	var speed := 30.0
	var dmg := 5.0
	var xp := 1
	var radius := 5.0
	var scale := 1.0
	var boss := false
	var knock := Vector2.ZERO
	var flash := 0.0
	var anim := 0.0
	var chuck_cd := 0.0
	var face_left := false
	var dead := false
	# boss attack state (Don): 0 walk, 1 wind-up, 2 spraying
	var atk_state := 0
	var atk_t := 3.0
	var atk_dur := 1.0
	var aim := 0.0
	var sweep_dir := 1.0
	var fire_t := 0.0


class Shot:
	var kind := "bullet"
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 1.0
	var pierce := 1
	var life := 1.0
	var radius := 3.0
	var knock := 20.0
	var hits: Array = []
	var rot := 0.0
	var t := 0.0
	var dur := 0.6
	var start := Vector2.ZERO
	var target_pos := Vector2.ZERO
	var blast := 24.0
	var target: Enemy = null
	var smoke_t := 0.0
	var arc := 26.0


class EShot:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 10.0
	var life := 2.5


class Pickup:
	var kind := "gem"  # gem, pizza, magnet, case, snow
	var pos := Vector2.ZERO
	var val := 1
	var tier := 0
	var pulled := false
	var spd := 0.0


class Fx:
	var kind := "puff"
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var t := 0.0
	var dur := 0.3
	var r := 6.0
	var color := Color.WHITE
	var text := ""
	var rot := 0.0
	var flip := false


var state: State = State.TITLE
var rng := RandomNumberGenerator.new()
var cam: Camera2D
var cam_pos := Vector2.ZERO
var hud: Node2D
var shake := 0.0
var clock := 0.0

# level
var level_id := 1
var lvl: Dictionary = {}
var intro_t := 0.0        # wake-up animation on the beach
var card_t := 0.0         # level title card
var trans_t := 0.0
var pier_active := false
var pier_x := 0.0
var don_spawned := false
var don_dead := false
var boss_ref: Enemy = null

# player
var ppos := Vector2.ZERO
var pface := Vector2.RIGHT
var pmove := Vector2.ZERO
var pmoving := false
var anim_t := 0.0
var hp := 100.0
var max_hp := 100.0
var hurt_t := 0.0
var bullet_iframe := 0.0
var level := 1
var xp := 0.0
var xp_next := 5.0
var kills := 0
var score := 0
var time := 0.0
var total_time := 0.0
var stats := {}

# dodge
var dodge_t := 0.0
var dodge_cd := 0.0
var iframe_t := 0.0
var dodge_dir := Vector2.RIGHT
var ghost_t := 0.0

# supercharge (powerup)
var super_t := 0.0
var super_fire_t := 0.0
var super_gl_t := 0.0
var super_aim := 0.0
var snow_t := 70.0

var weapons := {}
var weapon_order: Array = []
var passives := {}
var passive_order: Array = []

var enemies: Array = []
var shots: Array = []
var eshots: Array = []
var pickups: Array = []
var fx: Array = []
var grid := {}

var spawn_t := 0.0
var events_done := {}
var bosses_spawned := 0
var banner := ""
var banner_t := 0.0

var pending := 0
var choices: Array = []
var sel := 0
var menu_t := 0.0

# touch controls
var touch_idx := -1
var touch_origin := Vector2.ZERO
var touch_vec := Vector2.ZERO
var touch_seen := false

# automated test mode (used by CI / local headless runs)
var autotest := -1.0
var god := false
var shot_path := ""
var shot_at := -1.0
var start_level := 1
var start_time := 0.0
var don_hp_override := -1.0
var force_super := false


func _ready() -> void:
	rng.randomize()
	_setup_input()

	var floor_layer := Drawer.new()
	floor_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_layer.fn = _draw_floor
	add_child(floor_layer)
	var world_layer := Drawer.new()
	world_layer.fn = _draw_world
	add_child(world_layer)
	var top_layer := Drawer.new()
	top_layer.fn = _draw_top
	add_child(top_layer)

	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			autotest = float(a.get_slice("=", 1))
		elif a == "--god":
			god = true
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--shot-at="):
			shot_at = float(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			start_level = int(a.get_slice("=", 1))
		elif a.begins_with("--time="):
			start_time = float(a.get_slice("=", 1))
		elif a.begins_with("--don-hp="):
			don_hp_override = float(a.get_slice("=", 1))
		elif a == "--super":
			force_super = true

	_reset_run()
	state = State.TITLE
	if autotest > 0.0 and not "--title" in OS.get_cmdline_user_args():
		_start()


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("confirm", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z], [JOY_BUTTON_A], [])
	_add_action("dodge", [KEY_SHIFT, KEY_SPACE, KEY_K, KEY_X], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], [])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_add_action("mute", [KEY_M], [], [])


func _add_action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for ax in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = ax[0]
		jm.axis_value = ax[1]
		InputMap.action_add_event(action, jm)


# ====================================================================== run

func _reset_run() -> void:
	hp = 100.0
	max_hp = 100.0
	level = 1
	xp = 0.0
	xp_next = _xp_for(1)
	kills = 0
	score = 0
	total_time = 0.0
	weapons.clear()
	weapon_order.clear()
	passives.clear()
	passive_order.clear()
	bosses_spawned = 0
	pending = 0
	_recalc_stats()
	_add_weapon("pistol")
	_load_level(start_level)
	time = start_time
	for ev in lvl.events:
		if ev[0] < start_time:
			events_done[ev[0]] = true


## Resets the world for a level; the player's build (weapons, items, level) carries over.
func _load_level(id: int) -> void:
	level_id = id
	lvl = Data.LEVELS[id]
	time = 0.0
	ppos = Vector2(0, 28) if id == 1 else Vector2.ZERO
	pface = Vector2.RIGHT
	hurt_t = 0.0
	dodge_t = 0.0
	dodge_cd = 0.0
	iframe_t = 0.0
	super_t = 0.0
	snow_t = 70.0
	enemies.clear()
	shots.clear()
	eshots.clear()
	pickups.clear()
	fx.clear()
	grid.clear()
	spawn_t = 0.5
	events_done.clear()
	banner = ""
	banner_t = 0.0
	pier_active = false
	don_spawned = false
	don_dead = false
	boss_ref = null
	intro_t = 3.0 if id == 1 else 0.0
	card_t = 3.5
	Sfx.set_ambience(id == 1 and state != State.TITLE)
	Sfx.set_music_pitch(1.0)


func _start() -> void:
	state = State.PLAY
	_reset_run()
	Sfx.play("confirm", 0.0)
	Sfx.stop_music()
	Sfx.start_music()
	Sfx.set_ambience(level_id == 1)


func _xp_for(lvl_n: int) -> float:
	return 5.0 + (lvl_n - 1) * 9.0 + floorf(pow(lvl_n - 1, 2) * 0.3)


func _recalc_stats() -> void:
	var p := func(id: String) -> int: return int(passives.get(id, 0))
	stats = {
		"speed": 1.0 + 0.08 * p.call("tape"),
		"might": 1.0 + 0.10 * p.call("dumbbell"),
		"armor": 1.0 - 0.08 * p.call("vest"),
		"cd": 1.0 - 0.07 * p.call("cola"),
		"area": 1.0 + 0.10 * p.call("hairspray"),
		"growth": 1.0 + 0.10 * p.call("walkman"),
		"magnet": 1.0 + 0.30 * p.call("magnet"),
		"regen": 0.2 * p.call("heart"),
		"amount": p.call("headband"),
	}
	max_hp = 100.0 + 20.0 * p.call("heart")


func _add_weapon(id: String) -> void:
	weapons[id] = {
		"lvl": 1, "t": 0.3, "burst": 0, "burst_t": 0.0, "angle": 0.0,
		"pulse": 1.0, "points": [], "swing_t": 9.0, "swing_dir": 0.0,
		"s": Data.weapon_stats(id, 1),
	}
	weapon_order.append(id)


func difficulty() -> float:
	return lvl.diff_offset + time / 60.0 * lvl.diff_scale


func is_supercharged() -> bool:
	return super_t > 0.0


# ====================================================================== loop

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	clock += delta
	match state:
		State.PLAY:
			_update_play(delta)
		State.LEVELUP, State.OVER, State.WIN:
			menu_t += delta
			_update_fx(delta * 0.5)
		State.TRANSITION:
			_update_transition(delta)
		_:
			pass

	if autotest > 0.0:
		if force_super and state == State.PLAY and intro_t <= 0.6 and super_t <= 0.0:
			super_t = Data.SUPER_TIME
		_autotest_step()

	shake = maxf(0.0, shake - delta * 10.0)
	if level_id == 1:
		cam_pos = Vector2(ppos.x, -6.0)
	else:
		cam_pos = ppos
	cam.position = cam_pos.round()
	cam.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)).round()


func _update_play(delta: float) -> void:
	card_t -= delta
	if intro_t > 0.0:
		# waking up next to the wrecked speedboat
		intro_t -= delta
		if rng.randf() < delta * 4.0:
			_add_smoke(Vector2(-46 + rng.randf_range(-4, 4), 36))
		_update_fx(delta)
		if intro_t > 0.6:
			return

	time += delta
	total_time += delta

	if level_id == 2 and time >= lvl.duration:
		_win()
		return
	if level_id == 1 and time >= lvl.duration and not pier_active:
		_start_pier()

	_update_player(delta)
	_spawn(delta)
	_build_grid()
	_update_enemies(delta)
	_update_weapons(delta)
	if super_t > 0.0:
		_update_super(delta)
	_update_shots(delta)
	_update_eshots(delta)
	_update_pickups(delta)
	_update_fx(delta)
	enemies = enemies.filter(func(e): return not e.dead)

	if level_id == 1 and smoke_due():
		_add_smoke(Vector2(-46 + rng.randf_range(-4, 4), 36))

	if hp <= 0.0:
		if god:
			hp = max_hp
		else:
			_game_over()
			return

	if don_dead and ppos.distance_to(Vector2(pier_x, BEACH_TOP)) < 22.0:
		_begin_transition()
		return

	if pending > 0:
		_open_levelup()


func smoke_due() -> bool:
	return absf(ppos.x + 46.0) < 260.0 and rng.randf() < 0.05


func _add_smoke(pos: Vector2) -> void:
	var f := Fx.new()
	f.kind = "smoke"
	f.pos = pos
	f.vel = Vector2(rng.randf_range(-3, 3), -14)
	f.dur = 1.2
	f.r = 3.0
	f.color = Color(0.35, 0.33, 0.38)
	fx.append(f)


func _update_player(delta: float) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_idx >= 0:
		v = touch_vec
	if autotest > 0.0:
		v = _bot_move()
	v = v.limit_length(1.0)
	pmove = v
	pmoving = v.length() > 0.1
	if pmoving:
		pface = v.normalized()
		anim_t += delta * v.length()

	dodge_cd -= delta
	iframe_t -= delta
	bullet_iframe -= delta
	if dodge_t > 0.0:
		dodge_t -= delta
		ppos += dodge_dir * DODGE_SPEED * delta
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.04
			var g := Fx.new()
			g.kind = "ghost"
			g.pos = ppos
			g.dur = 0.25
			g.rot = (1.0 - dodge_t / DODGE_TIME) * TAU * (1.0 if dodge_dir.x >= 0.0 else -1.0)
			g.flip = pface.x < 0.0
			fx.append(g)
	else:
		var spd: float = BASE_SPEED * stats.speed * (1.3 if super_t > 0.0 else 1.0)
		ppos += v * spd * delta
	ppos = _clamp_player(ppos)

	hp = minf(max_hp, hp + stats.regen * delta)
	hurt_t -= delta
	banner_t -= delta


func _try_dodge() -> void:
	if state != State.PLAY or dodge_cd > 0.0 or intro_t > 0.6:
		return
	dodge_dir = pmove.normalized() if pmove.length() > 0.2 else pface
	dodge_t = DODGE_TIME
	iframe_t = DODGE_IFRAMES
	dodge_cd = DODGE_COOLDOWN
	ghost_t = 0.0
	Sfx.play("dodge", 0.1, -4.0, 0.0)


func _clamp_player(p: Vector2) -> Vector2:
	if level_id == 1:
		p.y = clampf(p.y, BEACH_TOP, BEACH_BOTTOM)
	return p


# ====================================================================== level flow

func _start_pier() -> void:
	pier_active = true
	var side := 1.0 if pface.x >= 0.0 else -1.0
	pier_x = roundf(ppos.x + side * 120.0)
	banner = "A PIER... SOMEONE'S WAITING"
	banner_t = 3.0
	don_spawned = true
	bosses_spawned += 1
	boss_ref = _spawn_enemy("don", Vector2(pier_x, ENEMY_BOTTOM))
	boss_ref.atk_t = 3.0
	if don_hp_override > 0.0:
		boss_ref.hp = don_hp_override
	Sfx.play("siren", 0.0, -2.0, 0.0)


func _begin_transition() -> void:
	state = State.TRANSITION
	trans_t = 0.0
	Sfx.play("fanfare", 0.0, 0.0, 0.0)


func _update_transition(delta: float) -> void:
	var before := trans_t
	trans_t += delta
	if before < 1.0 and trans_t >= 1.0:
		# collect anything left lying around, then load the next level
		for p in pickups:
			if p.kind == "gem":
				xp += p.val * stats.growth
		hp = max_hp
		_load_level(level_id + 1)
		Sfx.set_ambience(false)
	if trans_t >= 1.6:
		state = State.PLAY
		while xp >= xp_next:
			xp -= xp_next
			level += 1
			pending += 1
			xp_next = _xp_for(level)


# ====================================================================== spawning

func _spawn(delta: float) -> void:
	for ev in lvl.events:
		if time >= ev[0] and not events_done.has(ev[0]):
			events_done[ev[0]] = true
			_run_event(ev[1])

	snow_t -= delta
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	var m := difficulty()
	spawn_t = maxf(0.12, 0.6 - m * 0.04)
	var target := mini(MAX_ENEMIES, 10 + int(m * 24.0))
	if level_id == 1:
		target = int(target * 0.7)  # narrower arena
	if pier_active:
		target = int(target * (0.25 if not don_dead else 0.15))
	var batch := 1 + int(m / 2.5)
	for i in batch:
		if enemies.size() >= target:
			break
		_spawn_enemy(_pick_kind(m), _offscreen_pos())

	# the occasional pile of "snow" (supercharge powerup)
	if snow_t <= 0.0:
		snow_t = 90.0
		var has_snow := false
		for p in pickups:
			if p.kind == "snow":
				has_snow = true
		if not has_snow and super_t <= 0.0:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 110.0)
			_drop("snow", _clamp_player(ppos + off))


func _pick_kind(m: float) -> String:
	var pool := [["punk", 10.0]]
	if m >= 1.0:
		pool.append(["ninja", 5.0 + m])
	if m >= 3.0:
		pool.append(["biker", 2.0 + m * 0.8])
	if m >= 6.0:
		pool.append(["robot", 1.0 + m * 0.5])
	var total := 0.0
	for p in pool:
		total += p[1]
	var r := rng.randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return "punk"


func _offscreen_pos() -> Vector2:
	if level_id == 1:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		return Vector2(ppos.x + side * rng.randf_range(185.0, 215.0), rng.randf_range(ENEMY_TOP, BEACH_BOTTOM))
	return ppos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 230.0)


func _spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var d: Dictionary = Data.ENEMIES[kind]
	var e := Enemy.new()
	e.kind = kind
	e.pos = pos
	var m := difficulty()
	e.boss = kind == "boss" or kind == "don"
	if kind == "boss":
		e.max_hp = d.hp * (1.0 + bosses_spawned * 1.2)
	elif kind == "don":
		e.max_hp = d.hp
	else:
		e.max_hp = d.hp * (1.0 + m * 0.35)
	e.hp = e.max_hp
	e.speed = d.speed * rng.randf_range(0.9, 1.1)
	e.dmg = d.dmg * (1.0 + m * 0.06)
	e.xp = d.xp
	e.radius = d.r
	e.scale = d.scale
	enemies.append(e)
	return e


func _run_event(kind: String) -> void:
	var m := difficulty()
	var k := "ninja" if m >= 5.0 else "punk"
	match kind:
		"ring":
			var n := 40
			for i in n:
				_spawn_enemy(k, ppos + Vector2.from_angle(TAU * i / n) * 170.0)
			banner = "THEY'VE GOT YOU SURROUNDED!"
			banner_t = 2.5
		"pincer":
			for side in [-1.0, 1.0]:
				for i in 16:
					var y := lerpf(ENEMY_TOP, BEACH_BOTTOM, i / 15.0)
					_spawn_enemy(k, Vector2(ppos.x + side * (180.0 + (i % 2) * 12.0), y))
			banner = "THEY'RE COMING FROM BOTH SIDES!"
			banner_t = 2.5
		"swarm":
			var center: Vector2
			if level_id == 1:
				center = Vector2(ppos.x + (210.0 if rng.randf() < 0.5 else -210.0), -10.0)
			else:
				center = ppos + Vector2.from_angle(rng.randf() * TAU) * 210.0
			for i in 30:
				var e := _spawn_enemy("ninja", center + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)))
				e.speed *= 1.4
			banner = "NINJA SWARM!"
			banner_t = 2.5
		"boss":
			bosses_spawned += 1
			_spawn_enemy("boss", _offscreen_pos())
			banner = "WARNING! THE KINGPIN IS HERE"
			banner_t = 3.5
			Sfx.play("siren", 0.0, -2.0, 0.0)


# ====================================================================== grid

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _build_grid() -> void:
	grid.clear()
	for e in enemies:
		var c := _cell(e.pos)
		if grid.has(c):
			grid[c].append(e)
		else:
			grid[c] = [e]


func _query(pos: Vector2, r: float) -> Array:
	var out := []
	var pad := r + 26.0
	var c0 := _cell(pos - Vector2(pad, pad))
	var c1 := _cell(pos + Vector2(pad, pad))
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var arr = grid.get(Vector2i(cx, cy))
			if arr == null:
				continue
			for e in arr:
				if e.dead:
					continue
				var rr: float = r + e.radius
				if e.pos.distance_squared_to(pos) <= rr * rr:
					out.append(e)
	return out


func _nearest(pos: Vector2, max_range: float, n: int) -> Array:
	var cands := []
	var mr2 := max_range * max_range
	for e in enemies:
		if e.dead:
			continue
		var d2: float = e.pos.distance_squared_to(pos)
		if d2 <= mr2:
			cands.append([d2, e])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(n, cands.size()):
		out.append(cands[i][1])
	return out


# ====================================================================== enemies

func _update_enemies(delta: float) -> void:
	var damp := maxf(0.0, 1.0 - 9.0 * delta)
	for e in enemies:
		if e.dead:
			continue
		var to: Vector2 = ppos - e.pos
		var dist := to.length()
		if not e.boss:
			if level_id == 1:
				if absf(to.x) > 260.0:
					e.pos.x = ppos.x + signf(to.x) * 200.0
					continue
			elif dist > 340.0:
				# wandered too far behind: bring them back in front of the player
				e.pos = ppos + (to / dist).rotated(rng.randf_range(-0.7, 0.7)) * 215.0
				continue
		var dir := to / maxf(dist, 0.001)
		var vel: Vector2 = dir * e.speed

		if e.kind == "don":
			vel = _update_don(e, dir, delta)

		# soft separation so crowds spread out instead of stacking
		var push := Vector2.ZERO
		var c := _cell(e.pos)
		for cx in range(c.x - 1, c.x + 2):
			for cy in range(c.y - 1, c.y + 2):
				var arr = grid.get(Vector2i(cx, cy))
				if arr == null:
					continue
				for o in arr:
					if o == e:
						continue
					var d: Vector2 = e.pos - o.pos
					var l2 := d.length_squared()
					var mn: float = e.radius + o.radius
					if l2 < mn * mn and l2 > 0.0001:
						var l := sqrt(l2)
						push += d / l * (mn - l)
		if e.boss:
			push *= 0.1
		vel += push * 7.0

		e.pos += (vel + e.knock) * delta
		if level_id == 1:
			e.pos.y = clampf(e.pos.y, ENEMY_TOP, ENEMY_BOTTOM)
		e.knock *= damp
		e.flash -= delta
		e.chuck_cd -= delta
		e.anim += delta * e.speed / 28.0 * (0.0 if e.kind == "don" and e.atk_state != 0 else 1.0)
		e.face_left = dir.x < 0.0

		if dist < e.radius + 5.0:
			_hurt_player(e.dmg * delta)


## The Don walks toward you, revs his minigun, then sweeps a stream of bullets
## across the screen. Below half health he sprays two streams and rests less.
func _update_don(e: Enemy, dir: Vector2, delta: float) -> Vector2:
	var enraged := e.hp < e.max_hp * 0.5
	e.atk_t -= delta
	match e.atk_state:
		0:
			if e.atk_t <= 0.0:
				e.atk_state = 1
				e.atk_t = 0.8
				e.aim = dir.angle()
				Sfx.play("rev", 0.0, -2.0, 0.0)
			return dir * e.speed
		1:
			if int(e.atk_t * 20.0) % 2 == 0:
				e.flash = 0.03
			if e.atk_t <= 0.0:
				e.atk_state = 2
				e.atk_dur = 2.6 if enraged else 2.2
				e.atk_t = e.atk_dur
				e.sweep_dir = 1.0 if rng.randf() < 0.5 else -1.0
				e.fire_t = 0.0
			return Vector2.ZERO
		_:
			e.fire_t -= delta
			var k: float = 1.0 - e.atk_t / e.atk_dur
			var sweep := 1.9
			while e.fire_t <= 0.0:
				e.fire_t += 0.035
				var a: float = e.aim - e.sweep_dir * sweep / 2.0 + e.sweep_dir * sweep * k
				var muzzle := e.pos + Vector2(-14.0 if e.face_left else 14.0, 6.0)
				_add_eshot(muzzle, Vector2.from_angle(a) * 150.0, 12.0)
				if enraged:
					var a2: float = e.aim + e.sweep_dir * sweep / 2.0 - e.sweep_dir * sweep * k
					_add_eshot(muzzle, Vector2.from_angle(a2) * 130.0, 12.0)
				Sfx.play("uzi", 0.05, -10.0, 0.06)
			shake = maxf(shake, 0.8)
			if e.atk_t <= 0.0:
				e.atk_state = 0
				e.atk_t = 2.5 if enraged else 4.0
			return Vector2.ZERO


func _add_eshot(pos: Vector2, vel: Vector2, dmg: float) -> void:
	var s := EShot.new()
	s.pos = pos
	s.vel = vel
	s.dmg = dmg
	eshots.append(s)


func _update_eshots(delta: float) -> void:
	for s in eshots:
		s.pos += s.vel * delta
		s.life -= delta
		if s.pos.distance_squared_to(ppos) < 36.0:
			if iframe_t <= 0.0 and bullet_iframe <= 0.0:
				hp -= s.dmg * stats.armor
				bullet_iframe = 0.3
				hurt_t = 0.25
				shake = maxf(shake, 2.0)
				Sfx.play("hurt", 0.05, -3.0, 0.1)
				s.life = 0.0
	eshots = eshots.filter(func(s): return s.life > 0.0)


func _hurt_player(amount: float) -> void:
	if iframe_t > 0.0:
		return
	hp -= amount * stats.armor
	if hurt_t <= 0.0:
		hurt_t = 0.25
		shake = maxf(shake, 1.5)
		Sfx.play("hurt", 0.05, -4.0, 0.2)


func _damage(e: Enemy, amount: float, dir: Vector2, knock: float) -> void:
	if e.dead:
		return
	amount *= stats.might * rng.randf_range(0.9, 1.1)
	e.hp -= amount
	e.flash = 0.08
	e.knock += dir * knock * (0.1 if e.boss else 1.0)
	if fx.size() < 160:
		var f := Fx.new()
		f.kind = "text"
		f.pos = e.pos + Vector2(rng.randf_range(-4, 4), -10.0 * e.scale)
		f.vel = Vector2(0, -24)
		f.dur = 0.5
		f.text = str(maxi(1, roundi(amount)))
		f.color = Color8(252, 220, 72) if amount >= 30.0 else Color8(248, 248, 236)
		fx.append(f)
	Sfx.play("hit", 0.2, -8.0, 0.05)
	if e.hp <= 0.0:
		_kill(e)


func _kill(e: Enemy) -> void:
	e.dead = true
	kills += 1
	score += 10 * maxi(1, e.xp)
	_add_fx("puff", e.pos, 0.3, 6.0 * e.scale, Color8(236, 84, 200))
	Sfx.play("die", 0.15, -6.0, 0.04)
	if e.boss:
		score += 1000
		shake = 4.0
		_add_fx("boom", e.pos, 0.6, 40.0, Color.WHITE)
		Sfx.play("explode", 0.0, 0.0, 0.0)
		_drop("case", e.pos)
		for i in 10:
			_drop_gem(e.pos + Vector2.from_angle(TAU * i / 10.0) * 18.0, 10)
		if e.kind == "don":
			score += 5000
			don_dead = true
			boss_ref = null
			eshots.clear()
			for i in 4:
				_add_fx("boom", e.pos + Vector2(rng.randf_range(-20, 20), rng.randf_range(-16, 16)), 0.6 + i * 0.15, 30.0, Color.WHITE)
			banner = "THE DON IS DOWN! HEAD NORTH TO MAIN STREET"
			banner_t = 6.0
			Sfx.play("fanfare", 0.0, 0.0, 0.0)
		return
	_drop_gem(e.pos, e.xp)
	var r := rng.randf()
	if r < 0.006:
		_drop("pizza", e.pos)
	elif r < 0.0085:
		_drop("magnet", e.pos)
	elif r < 0.0088:
		_drop("snow", e.pos)


func _drop_gem(pos: Vector2, val: int) -> void:
	var gem_count := 0
	for p in pickups:
		if p.kind == "gem":
			gem_count += 1
	if gem_count >= MAX_GEMS:
		# too many on the floor: fold the value into an existing gem
		var g: Pickup = pickups[rng.randi() % pickups.size()]
		if g.kind == "gem":
			g.val += val
			g.tier = _gem_tier(g.val)
			return
	var p := Pickup.new()
	p.kind = "gem"
	p.pos = pos
	p.val = val
	p.tier = _gem_tier(val)
	pickups.append(p)


func _gem_tier(val: int) -> int:
	if val >= 8:
		return 2
	if val >= 3:
		return 1
	return 0


func _drop(kind: String, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.pos = pos
	pickups.append(p)


# ====================================================================== weapons

func _amount_for(id: String) -> int:
	var a: int = stats.amount
	match id:
		"uzi", "ak":
			return a * 3
		"shotgun":
			return a * 2
		"boombox", "mace":
			return 0
	return a


func _gun_pos() -> Vector2:
	return ppos + Vector2(7.0 if pface.x >= 0.0 else -7.0, 0.0)


func _update_weapons(delta: float) -> void:
	for id in weapon_order:
		var w: Dictionary = weapons[id]
		var s: Dictionary = w.s
		match id:
			"chucks":
				_update_chucks(w, s, delta)
			"boombox":
				w.pulse += delta
				w.t -= delta
				if w.t <= 0.0:
					w.t = s.cd * stats.cd
					w.pulse = 0.0
					var r: float = s.radius * stats.area
					for e in _query(ppos, r):
						_damage(e, s.dmg, (e.pos - ppos).normalized(), s.knock)
			"mace":
				w.swing_t += delta
				w.t -= delta
				if w.t <= 0.0:
					w.t = s.cd * stats.cd
					_swing_mace(w, s)
			_:
				w.t -= delta
				if w.t <= 0.0:
					w.t = s.cd * stats.cd
					_fire(id, w, s)
				if (id == "uzi" or id == "ak") and w.burst > 0:
					w.burst_t -= delta
					while w.burst > 0 and w.burst_t <= 0.0:
						w.burst_t += 0.045 if id == "uzi" else 0.08
						w.burst -= 1
						if id == "uzi":
							var dir := pface.rotated(rng.randf_range(-s.spread, s.spread))
							_add_shot("bullet", _gun_pos(), dir * s.speed, s.dmg, s.pierce, 0.9, 3.0, 12.0)
							Sfx.play("uzi", 0.1, -6.0, 0.04)
						else:
							var near := _nearest(ppos, 190.0, 1)
							var dir := pface
							if near.size() > 0:
								dir = (near[0].pos - _gun_pos()).normalized()
							dir = dir.rotated(rng.randf_range(-0.04, 0.04))
							_add_shot("bullet", _gun_pos(), dir * s.speed, s.dmg, s.pierce, 1.0, 3.0, 25.0)
							Sfx.play("ak", 0.08, -5.0, 0.04)


func _fire(id: String, w: Dictionary, s: Dictionary) -> void:
	var n: int = int(s.get("count", 1)) + _amount_for(id)
	match id:
		"pistol":
			var targets := _nearest(ppos, 175.0, n)
			for i in n:
				var dir := pface
				if targets.size() > 0:
					var t: Enemy = targets[i % targets.size()]
					dir = (t.pos - _gun_pos()).normalized()
					if i >= targets.size():
						dir = dir.rotated(0.14 * (i - targets.size() + 1) * (1 if i % 2 == 0 else -1))
				else:
					dir = pface.rotated((i - (n - 1) / 2.0) * 0.14)
				_add_shot("bullet", _gun_pos(), dir * s.speed, s.dmg, s.pierce, 1.2, 3.0, 20.0)
			Sfx.play("shoot", 0.08, -4.0)
		"uzi", "ak":
			w.burst = n
			w.burst_t = 0.0
		"shotgun":
			var targets := _nearest(ppos, 120.0, 1)
			var base := pface
			if targets.size() > 0:
				base = (targets[0].pos - ppos).normalized()
			for i in n:
				var a: float = -s.spread / 2.0 + s.spread * (i / maxf(1.0, n - 1.0))
				var dir := base.rotated(a + rng.randf_range(-0.05, 0.05))
				_add_shot("pellet", _gun_pos(), dir * s.speed * rng.randf_range(0.85, 1.15),
					s.dmg, s.pierce, s.life, 3.0, s.knock)
			shake = maxf(shake, 1.5)
			Sfx.play("shotgun", 0.06, -3.0)
		"grenade":
			var targets := _nearest(ppos, 140.0, 8)
			for i in n:
				var tp: Vector2
				if targets.size() > 0:
					tp = targets[rng.randi() % targets.size()].pos
				else:
					tp = ppos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 90.0)
				_lob_grenade(ppos, tp, 0.55 + i * 0.08, s.dmg, s.radius)
			Sfx.play("throw", 0.1, -4.0)
		"rocket":
			var targets := _nearest(ppos, 260.0, n)
			for i in n:
				var dir := pface.rotated(rng.randf_range(-0.5, 0.5))
				var sh := _add_shot("rocket", _gun_pos(), dir * 60.0, s.dmg, 1, 3.0, 4.0, 0.0)
				sh.blast = s.radius
				sh.dur = s.speed
				if targets.size() > 0:
					sh.target = targets[i % targets.size()]
			Sfx.play("throw", 0.05, -2.0)
		"crossbow":
			var targets := _nearest(ppos, 220.0, 1)
			var base := pface
			if targets.size() > 0:
				base = (targets[0].pos - _gun_pos()).normalized()
			for i in n:
				var dir := base.rotated((i - (n - 1) / 2.0) * 0.12)
				_add_shot("bolt", _gun_pos(), dir * s.speed, s.dmg, s.pierce, 1.6, 4.0, s.knock)
			Sfx.play("bow", 0.08, -3.0)


func _lob_grenade(from: Vector2, to: Vector2, dur: float, dmg: float, radius: float) -> Shot:
	var sh := _add_shot("grenade", from, Vector2.ZERO, dmg, 99, 99.0, 0.0, 0.0)
	sh.start = from
	sh.target_pos = to
	sh.dur = dur
	sh.blast = radius
	return sh


func _swing_mace(w: Dictionary, s: Dictionary) -> void:
	var r: float = s.radius * stats.area
	var dir_a := pface.angle()
	var near := _nearest(ppos, r + 16.0, 1)
	if near.size() > 0:
		dir_a = (near[0].pos - ppos).angle()
	w.swing_t = 0.0
	w.swing_dir = dir_a
	for e in _query(ppos, r):
		var diff := absf(wrapf((e.pos - ppos).angle() - dir_a, -PI, PI))
		if diff <= s.arc / 2.0 + 0.2:
			_damage(e, s.dmg, (e.pos - ppos).normalized(), s.knock)
	Sfx.play("swing", 0.1, -3.0, 0.0)


func _update_chucks(w: Dictionary, s: Dictionary, delta: float) -> void:
	var n: int = s.count + _amount_for("chucks")
	var r: float = s.radius * stats.area
	w.angle += s.spin * delta
	var pts := []
	for i in n:
		var p := ppos + Vector2.from_angle(w.angle + TAU * i / n) * r
		pts.append(p)
		for e in _query(p, 6.0 * stats.area):
			if e.chuck_cd <= 0.0:
				e.chuck_cd = s.cd
				_damage(e, s.dmg, (e.pos - ppos).normalized(), 50.0)
	w.points = pts


## Supercharged: a high-RPM M-16 plus an under-barrel grenade every 2 seconds.
func _update_super(delta: float) -> void:
	var was := super_t
	super_t -= delta
	if super_t <= 0.0 and was > 0.0:
		Sfx.set_music_pitch(1.0)
		banner = "THE RUSH WEARS OFF..."
		banner_t = 1.5
		return
	super_fire_t -= delta
	while super_fire_t <= 0.0:
		super_fire_t += 0.055
		var near := _nearest(ppos, 210.0, 3)
		var dir := pface
		if near.size() > 0:
			dir = (near[rng.randi() % near.size()].pos - _gun_pos()).normalized()
		super_aim = dir.angle()
		dir = dir.rotated(rng.randf_range(-0.06, 0.06))
		_add_shot("bullet", _gun_pos() + dir * 8.0, dir * 330.0, 9.0, 1, 0.9, 3.0, 15.0)
		Sfx.play("uzi", 0.12, -7.0, 0.05)
	super_gl_t -= delta
	if super_gl_t <= 0.0:
		super_gl_t = 2.0
		var near := _nearest(ppos, 200.0, 1)
		var tp := ppos + Vector2.from_angle(super_aim) * 90.0
		if near.size() > 0:
			tp = near[0].pos
		_lob_grenade(_gun_pos(), tp, 0.35, 45.0, 34.0)
		Sfx.play("throw", 0.0, -2.0, 0.0)


func _add_shot(kind: String, pos: Vector2, vel: Vector2, dmg: float, pierce: int,
		life: float, radius: float, knock: float) -> Shot:
	var sh := Shot.new()
	sh.kind = kind
	sh.pos = pos
	sh.vel = vel
	sh.dmg = dmg
	sh.pierce = pierce
	sh.life = life
	sh.radius = radius
	sh.knock = knock
	shots.append(sh)
	return sh


func _update_shots(delta: float) -> void:
	for sh in shots:
		match sh.kind:
			"grenade":
				sh.t += delta
				var k := minf(1.0, sh.t / sh.dur)
				sh.pos = sh.start.lerp(sh.target_pos, k)
				sh.rot += 14.0 * delta
				if k >= 1.0:
					_explode(sh.pos, sh.blast, sh.dmg)
					sh.life = 0.0
			"rocket":
				if sh.target == null or sh.target.dead:
					var near := _nearest(sh.pos, 200.0, 1)
					sh.target = near[0] if near.size() > 0 else null
				var spd := minf(sh.vel.length() + 400.0 * delta, sh.dur)
				var ang: float = sh.vel.angle()
				if sh.target != null:
					ang = rotate_toward(ang, (sh.target.pos - sh.pos).angle(), 6.0 * delta)
				sh.vel = Vector2.from_angle(ang) * spd
				sh.pos += sh.vel * delta
				sh.life -= delta
				sh.smoke_t -= delta
				if sh.smoke_t <= 0.0:
					sh.smoke_t = 0.03
					_add_fx("smoke", sh.pos - sh.vel.normalized() * 4.0, 0.35, 2.5, Color(0.7, 0.7, 0.75))
				if sh.life <= 0.0 or _query(sh.pos, sh.radius).size() > 0:
					_explode(sh.pos, sh.blast, sh.dmg)
					sh.life = 0.0
			_:
				sh.pos += sh.vel * delta
				sh.life -= delta
				for e in _query(sh.pos, sh.radius):
					if sh.hits.has(e):
						continue
					sh.hits.append(e)
					_damage(e, sh.dmg, sh.vel.normalized(), sh.knock)
					sh.pierce -= 1
					if sh.pierce <= 0:
						sh.life = 0.0
						break
	shots = shots.filter(func(s): return s.life > 0.0)


func _explode(pos: Vector2, r: float, dmg: float) -> void:
	r *= stats.area
	for e in _query(pos, r):
		_damage(e, dmg, (e.pos - pos).normalized(), 70.0)
	_add_fx("boom", pos, 0.45, r, Color.WHITE)
	shake = maxf(shake, 2.5)
	Sfx.play("explode", 0.1, -5.0, 0.06)


# ====================================================================== pickups

func _update_pickups(delta: float) -> void:
	var mag: float = BASE_MAGNET * stats.magnet
	var mag2: float = mag * mag
	var collected := false
	for p in pickups:
		var d: Vector2 = ppos - p.pos
		var l2 := d.length_squared()
		# powerups must be walked over; everything else is magnetic
		var reach: float = 64.0 if p.kind == "snow" else mag2
		if not p.pulled and l2 < reach:
			p.pulled = true
			p.spd = -45.0
		if p.pulled:
			p.spd += 420.0 * delta
			var l := sqrt(l2)
			if l > 0.01:
				p.pos += d / l * minf(p.spd * delta, l)
			if l < 6.0:
				_collect(p)
				p.val = -1
				collected = true
	if collected:
		pickups = pickups.filter(func(p): return p.val >= 0)
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		pending += 1
		xp_next = _xp_for(level)


func _collect(p: Pickup) -> void:
	match p.kind:
		"gem":
			xp += p.val * stats.growth
			Sfx.play("gem", 0.0, -8.0, 0.035)
		"pizza":
			hp = minf(max_hp, hp + 30.0)
			_add_fx("ring", ppos, 0.4, 14.0, Color8(72, 200, 88))
			Sfx.play("pickup", 0.0, -2.0)
		"magnet":
			for g in pickups:
				if g.kind == "gem" and not g.pulled:
					g.pulled = true
					g.spd = 60.0
			_add_fx("ring", ppos, 0.4, 20.0, Color8(72, 228, 236))
			Sfx.play("pickup", 0.0, -2.0)
		"case":
			pending += 1
			score += 500
			_add_fx("ring", ppos, 0.5, 24.0, Color8(252, 220, 72))
			Sfx.play("pickup", 0.0, -2.0)
		"snow":
			super_t = Data.SUPER_TIME
			super_fire_t = 0.0
			super_gl_t = 0.3
			hp = minf(max_hp, hp + 20.0)
			banner = "SUPERCHARGED!"
			banner_t = 2.0
			shake = 3.0
			for i in 3:
				_add_fx("ring", ppos, 0.4 + i * 0.15, 18.0 + i * 10.0, Color.WHITE)
			Sfx.play("powerup", 0.0, 0.0, 0.0)
			Sfx.set_music_pitch(1.12)


# ====================================================================== fx

func _add_fx(kind: String, pos: Vector2, dur: float, r: float, color: Color) -> void:
	if fx.size() > 220 and kind != "boom":
		return
	var f := Fx.new()
	f.kind = kind
	f.pos = pos
	f.dur = dur
	f.r = r
	f.color = color
	fx.append(f)


func _update_fx(delta: float) -> void:
	for f in fx:
		f.t += delta
		f.pos += f.vel * delta
	fx = fx.filter(func(f): return f.t < f.dur)


# ====================================================================== level up

func _open_levelup() -> void:
	pending -= 1
	choices = _roll_choices()
	sel = 0
	menu_t = 0.0
	state = State.LEVELUP
	Sfx.play("levelup", 0.0, -2.0, 0.0)


func _roll_choices() -> Array:
	var pool := []
	for id in Data.WEAPON_ORDER:
		if weapons.has(id):
			if weapons[id].lvl < Data.weapon_max(id):
				pool.append({"type": "w", "id": id})
		elif weapon_order.size() < Data.MAX_WEAPONS:
			pool.append({"type": "w", "id": id})
	for id in Data.PASSIVE_ORDER:
		var plvl: int = passives.get(id, 0)
		if plvl > 0:
			if plvl < Data.PASSIVES[id].max:
				pool.append({"type": "p", "id": id})
		elif passive_order.size() < Data.MAX_PASSIVES:
			pool.append({"type": "p", "id": id})
	pool.shuffle()
	var out := pool.slice(0, 3)
	for filler in [{"type": "pizza"}, {"type": "cash"}]:
		if out.size() < 3:
			out.append(filler)
	return out


## Display info for a level-up choice: icon, name, tag (NEW!/LV n), description.
func choice_info(c: Dictionary) -> Dictionary:
	match c.type:
		"w":
			var d: Dictionary = Data.WEAPONS[c.id]
			var next_lvl: int = (weapons[c.id].lvl + 1) if weapons.has(c.id) else 1
			return {"icon": d.icon, "name": d.name,
				"tag": "NEW!" if next_lvl == 1 else "LV %d" % next_lvl,
				"desc": d.desc[next_lvl - 1]}
		"p":
			var d: Dictionary = Data.PASSIVES[c.id]
			var next_lvl: int = int(passives.get(c.id, 0)) + 1
			return {"icon": d.icon, "name": d.name,
				"tag": "NEW!" if next_lvl == 1 else "LV %d" % next_lvl,
				"desc": d.desc}
		"pizza":
			return {"icon": "pizza", "name": "PIZZA", "tag": "", "desc": "HEAL 40 HP. COWABUNGA!"}
		_:
			return {"icon": "cash", "name": "BRIEFCASE OF CASH", "tag": "", "desc": "+500 SCORE"}


func _choose(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	var c: Dictionary = choices[i]
	match c.type:
		"w":
			if weapons.has(c.id):
				var w: Dictionary = weapons[c.id]
				w.lvl += 1
				w.s = Data.weapon_stats(c.id, w.lvl)
			else:
				_add_weapon(c.id)
		"p":
			var plvl: int = passives.get(c.id, 0)
			if plvl == 0:
				passive_order.append(c.id)
			passives[c.id] = plvl + 1
			_recalc_stats()
			if c.id == "heart":
				hp = minf(max_hp, hp + 20.0)
		"pizza":
			hp = minf(max_hp, hp + 40.0)
		"cash":
			score += 500
	Sfx.play("confirm", 0.0)
	state = State.PLAY


func _game_over() -> void:
	state = State.OVER
	menu_t = 0.0
	hp = 0.0
	Sfx.stop_music()
	Sfx.set_ambience(false)
	Sfx.set_music_pitch(1.0)
	Sfx.play("gameover", 0.0, 0.0, 0.0)
	_add_fx("boom", ppos, 0.6, 20.0, Color.WHITE)


func _win() -> void:
	state = State.WIN
	menu_t = 0.0
	for e in enemies:
		_add_fx("puff", e.pos, 0.5, 8.0, Color8(252, 220, 72))
	enemies.clear()
	shots.clear()
	eshots.clear()
	score += 5000
	Sfx.set_music_pitch(1.0)
	Sfx.play("fanfare", 0.0, 0.0, 0.0)


# ====================================================================== input

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY and autotest < 0.0:
		state = State.PAUSE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		Sfx.toggle_mute()
		return

	# touch: dodge button bottom-right, joystick anywhere else
	if event is InputEventScreenTouch:
		touch_seen = true
		if event.pressed and state == State.PLAY and hud.dodge_button_rect().has_point(event.position):
			_try_dodge()
		elif event.pressed and touch_idx < 0 and state == State.PLAY:
			touch_idx = event.index
			touch_origin = event.position
			touch_vec = Vector2.ZERO
		elif not event.pressed and event.index == touch_idx:
			touch_idx = -1
			touch_vec = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == touch_idx:
		touch_vec = ((event.position - touch_origin) / 20.0).limit_length(1.0)

	var any_press: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)

	match state:
		State.TITLE:
			if any_press:
				_start()
		State.PLAY:
			if event.is_action_pressed("pause"):
				state = State.PAUSE
				Sfx.play("select", 0.0)
			elif event.is_action_pressed("dodge"):
				_try_dodge()
		State.PAUSE:
			if event.is_action_pressed("pause") or event.is_action_pressed("confirm") \
					or (event is InputEventMouseButton and event.pressed):
				state = State.PLAY
				Sfx.play("select", 0.0)
		State.LEVELUP:
			if menu_t < 0.35:
				return
			if event.is_action_pressed("move_up"):
				sel = (sel + choices.size() - 1) % choices.size()
				Sfx.play("select", 0.0)
			elif event.is_action_pressed("move_down"):
				sel = (sel + 1) % choices.size()
				Sfx.play("select", 0.0)
			elif event.is_action_pressed("confirm"):
				_choose(sel)
			elif event is InputEventKey and event.pressed and not event.echo \
					and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_3:
				_choose(event.physical_keycode - KEY_1)
			elif event is InputEventMouseMotion:
				for i in choices.size():
					if hud.card_rect(i).has_point(event.position) and sel != i:
						sel = i
						Sfx.play("select", 0.0)
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				for i in choices.size():
					if hud.card_rect(i).has_point(event.position):
						_choose(i)
						break
		State.OVER, State.WIN:
			if menu_t > 1.2 and any_press:
				_start()


# ====================================================================== autotest

## Simple bot for headless testing: grabs pickups, dodges the Don's spray,
## and walks to the exit once the boss is dead.
func _bot_move() -> Vector2:
	if don_dead:
		if banner_t > 4.0:
			return Vector2.ZERO
		return (Vector2(pier_x, BEACH_TOP - 4.0) - ppos).normalized()
	var v := Vector2.from_angle(time * 0.4) * 0.9
	if level_id == 1:
		v = Vector2(1.0 if fmod(time, 40.0) < 20.0 else -1.0, sin(time * 0.7)) * 0.9
	var best: Pickup = null
	var bd := 1e9
	for p in pickups:
		var d2: float = p.pos.distance_squared_to(ppos)
		if d2 < bd:
			bd = d2
			best = p
	if best != null and bd < 150.0 * 150.0:
		v = (best.pos - ppos).normalized()
	if boss_ref != null and not boss_ref.dead:
		var to := boss_ref.pos - ppos
		v = to.normalized() if to.length() > 70.0 else -to.normalized().rotated(0.8)
	if eshots.size() > 0 and dodge_cd <= 0.0 and rng.randf() < 0.05:
		_try_dodge()
	return v


func _autotest_step() -> void:
	if state == State.LEVELUP:
		if shot_path != "" and shot_at == -2.0 and level >= 3 and menu_t > 0.4:
			get_viewport().get_texture().get_image().save_png(shot_path)
			print("screenshot saved ", shot_path)
			shot_path = ""
		if menu_t < 0.5 and shot_at == -2.0 and level >= 3:
			return
		_choose(rng.randi() % choices.size())
	elif state == State.OVER or state == State.WIN:
		print("AUTOTEST END state=%s level_id=%d time=%.1f total=%.1f level=%d kills=%d" % [
			State.keys()[state], level_id, time, total_time, level, kills])
		get_tree().quit()
		return
	if shot_path != "" and shot_at == -3.0 and don_dead and banner_t < 5.0:
		shot_at = 0.0
	if shot_path != "" and ((shot_at > 0.0 and total_time >= shot_at) or (shot_at == 0.0 and clock > 1.0)):
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("screenshot saved ", shot_path)
		shot_path = ""
	if int(total_time * 60.0) % 600 == 0 and state == State.PLAY and intro_t <= 0.6:
		var bhp := ""
		if boss_ref != null:
			bhp = " DON_HP=%d atk=%d eshots=%d" % [boss_ref.hp, boss_ref.atk_state, eshots.size()]
		print("L%d t=%.0f lvl=%d hp=%.0f enemies=%d shots=%d pickups=%d super=%.1f weapons=%s%s fps=%d" % [
			level_id, time, level, hp, enemies.size(), shots.size(), pickups.size(), super_t,
			str(weapon_order), bhp, Engine.get_frames_per_second()])
	if total_time >= autotest or (state == State.TITLE and clock > 1.5):
		print("AUTOTEST DONE level_id=%d time=%.1f level=%d kills=%d enemies=%d don_dead=%s" % [
			level_id, time, level, kills, enemies.size(), str(don_dead)])
		get_tree().quit()


# ====================================================================== drawing

func _hash(x: int, y: int) -> int:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _view_rect(margin: float = 24.0) -> Rect2:
	return Rect2(cam_pos - Vector2(160, 90) - Vector2(margin, margin), Vector2(320, 180) + Vector2(margin, margin) * 2.0)


func _draw_floor(ci: CanvasItem) -> void:
	if state == State.TITLE:
		return
	if level_id == 1:
		_draw_beach(ci)
		return
	var origin := Vector2(floorf((cam_pos.x - 200.0) / 64.0) * 64.0, floorf((cam_pos.y - 140.0) / 64.0) * 64.0)
	ci.draw_texture_rect(Art.tex.floor, Rect2(origin, Vector2(64 * 8, 64 * 6)), true)
	# flat decals: manholes, neon puddles, painted road markings
	var vr := _view_rect(40.0)
	var cs := 80
	for cx in range(floori(vr.position.x / cs), floori(vr.end.x / cs) + 1):
		for cy in range(floori(vr.position.y / cs), floori(vr.end.y / cs) + 1):
			var h := _hash(cx * 7 + 3, cy * 13 + 5)
			if h % 100 >= 40:
				continue
			var pos := Vector2(cx * cs + 12 + (h / 11) % 56, cy * cs + 12 + (h / 17) % 56).round()
			match (h / 100) % 4:
				0:
					ci.draw_set_transform(pos, 0.0, Vector2(1.0, 0.55))
					ci.draw_circle(Vector2.ZERO, 8.0, Color8(30, 26, 44))
					ci.draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color8(78, 72, 102), 1.0)
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					ci.draw_rect(Rect2(pos + Vector2(-4, -1), Vector2(8, 1)), Color8(78, 72, 102))
					ci.draw_rect(Rect2(pos + Vector2(-4, 1), Vector2(8, 1)), Color8(78, 72, 102))
				1:
					var flick := 0.55 + 0.1 * sin(clock * 3.0 + h)
					ci.draw_set_transform(pos, 0.0, Vector2(1.0, 0.4))
					ci.draw_circle(Vector2.ZERO, 12.0 + (h % 6), Color(0.16, 0.32, 0.5, flick))
					ci.draw_circle(Vector2(-3, -4), 6.0, Color(0.92, 0.33, 0.78, 0.35))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					ci.draw_rect(Rect2(pos + Vector2(2, -1), Vector2(4, 1)), Color(0.3, 0.9, 0.93, 0.6))
				2:
					for i in 3:
						ci.draw_rect(Rect2(pos + Vector2(i * 10 - 14, 0), Vector2(6, 2)), Color8(150, 140, 120))
				_:
					ci.draw_rect(Rect2(pos + Vector2(-1, -6), Vector2(2, 8)), Color8(150, 140, 120))
					ci.draw_rect(Rect2(pos + Vector2(-3, -6), Vector2(6, 1)), Color8(150, 140, 120))
					ci.draw_rect(Rect2(pos + Vector2(-2, -7), Vector2(4, 1)), Color8(150, 140, 120))


func _draw_beach(ci: CanvasItem) -> void:
	var vr := _view_rect(40.0)
	var x0 := floorf(vr.position.x / 64.0) * 64.0
	var w := vr.size.x + 128.0
	# sand
	ci.draw_texture_rect(Art.tex.sand, Rect2(x0, -128, w, 256), true)

	# dunes along the north edge, with grass tufts
	ci.draw_rect(Rect2(x0, -100, w, DUNE_Y + 100), Color8(212, 172, 108))
	ci.draw_rect(Rect2(x0, DUNE_Y - 2, w, 2), Color8(190, 148, 92))
	ci.draw_rect(Rect2(x0, DUNE_Y, w, 2), Color8(244, 214, 156))
	var gx := floori(x0 / 6.0)
	for i in int(w / 6.0):
		var h := _hash(gx + i, 77)
		if h % 3 == 0:
			var px := (gx + i) * 6.0 + h % 5
			var py := -96.0 + (h / 7) % 22
			ci.draw_rect(Rect2(px, py, 1, 3), Color8(72, 152, 64))
			ci.draw_rect(Rect2(px + 1, py + 1, 1, 2), Color8(40, 110, 52))
			if h % 2 == 0:
				ci.draw_rect(Rect2(px - 1, py + 1, 1, 2), Color8(96, 176, 80))

	# boardwalk path north from the pier, once the Don is down
	if pier_active:
		ci.draw_rect(Rect2(pier_x - 12, -100, 24, DUNE_Y + 104), Color8(150, 100, 60))
		for yy in range(-100, int(DUNE_Y) + 4, 4):
			ci.draw_rect(Rect2(pier_x - 12, yy, 24, 1), Color8(110, 70, 44))
		ci.draw_rect(Rect2(pier_x - 13, -100, 1, DUNE_Y + 104), Color8(80, 50, 32))
		ci.draw_rect(Rect2(pier_x + 12, -100, 1, DUNE_Y + 104), Color8(80, 50, 32))

	# wet sand + ocean with animated foam
	var shore := SHORE_Y + sin(clock * 1.1) * 2.0
	ci.draw_rect(Rect2(x0, shore - 6, w, 6), Color8(200, 160, 104))
	ci.draw_rect(Rect2(x0, shore, w, 100), Color8(48, 168, 208))
	ci.draw_rect(Rect2(x0, shore + 10, w, 100), Color8(36, 132, 192))
	ci.draw_rect(Rect2(x0, shore + 24, w, 100), Color8(28, 100, 168))
	var fx0 := floori(x0 / 4.0)
	for i in int(w / 4.0):
		var px := (fx0 + i) * 4.0
		var fy := shore + sin(px * 0.11 + clock * 2.2) * 1.5
		ci.draw_rect(Rect2(px, roundf(fy), 3, 1), Color8(248, 248, 236))
		var h := _hash(fx0 + i, 5)
		if h % 9 == 0:
			var sy := shore + 6.0 + (h / 9) % 30
			if int(clock * 3.0 + h) % 4 == 0:
				ci.draw_rect(Rect2(px, sy, 2, 1), Color(1, 1, 1, 0.7))
			ci.draw_rect(Rect2(px + 3, sy + 3, 4, 1), Color(1, 1, 1, 0.18))

	# the pier: planks out into the water
	if pier_active:
		var top := 22.0
		ci.draw_rect(Rect2(pier_x - 20, top, 40, 100), Color8(160, 108, 64))
		for yy in range(int(top), int(top) + 100, 4):
			ci.draw_rect(Rect2(pier_x - 20, yy, 40, 1), Color8(112, 72, 44))
		for xx in [-20, 19]:
			ci.draw_rect(Rect2(pier_x + xx, top, 1, 100), Color8(72, 44, 28))
		for yy in range(int(top) + 8, int(top) + 100, 16):
			ci.draw_rect(Rect2(pier_x - 23, yy, 3, 5), Color8(72, 44, 28))
			ci.draw_rect(Rect2(pier_x + 20, yy, 3, 5), Color8(72, 44, 28))


func _visible_props() -> Array:
	var out := []
	var vr := _view_rect(32.0)
	if level_id == 1:
		# palms on the dunes, umbrellas on the sand, the wrecked speedboat
		for cx in range(floori(vr.position.x / 56.0), floori(vr.end.x / 56.0) + 1):
			var h := _hash(cx, 11)
			if h % 100 < 55:
				out.append(["palm", Vector2(cx * 56 + h % 40, DUNE_Y + 4 + (h / 3) % 6)])
		for cx in range(floori(vr.position.x / 130.0), floori(vr.end.x / 130.0) + 1):
			var h := _hash(cx, 23)
			if h % 100 < 35 and absi(cx) > 0:
				out.append(["umbrella", Vector2(cx * 130 + h % 90, -40.0 + (h / 5) % 60)])
		if vr.has_point(Vector2(-46, 50)):
			out.append(["boat", Vector2(-46, 52)])
		if pier_active:
			out = out.filter(func(p): return absf(p[1].x - pier_x) > 26.0)
		return out
	var c0 := Vector2i(floori(vr.position.x / PROP_CELL), floori(vr.position.y / PROP_CELL))
	var c1 := Vector2i(floori(vr.end.x / PROP_CELL), floori(vr.end.y / PROP_CELL))
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			if absi(cx) <= 1 and absi(cy) <= 1:
				continue  # keep the start area clear
			var h := _hash(cx, cy)
			if h % 100 >= 30:
				continue
			var kinds := ["palm", "palm", "drum", "crate", "palm"]
			var kind: String = kinds[(h / 100) % kinds.size()]
			var pos := Vector2(cx * PROP_CELL + 16 + (h / 7) % 80, cy * PROP_CELL + 16 + (h / 13) % 80)
			out.append([kind, pos])
	return out


func _draw_sprite(ci: CanvasItem, tex: Texture2D, pos: Vector2, s: float, flip: bool,
		mod: Color = Color.WHITE, rot: float = 0.0) -> void:
	ci.draw_set_transform(pos.round(), rot, Vector2(-s if flip else s, s))
	ci.draw_texture(tex, Vector2(-tex.get_width() / 2, -tex.get_height() / 2 - 2), mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_world(ci: CanvasItem) -> void:
	if state == State.TITLE:
		return
	var vr := _view_rect()
	var bob := int(clock * 4.0) % 2

	# pickups lie flat on the ground
	for p in pickups:
		if not vr.has_point(p.pos):
			continue
		match p.kind:
			"gem":
				ci.draw_texture(Art.tex["gem_%d" % p.tier], (p.pos - Vector2(2, 3)).round())
			_:
				var t: Texture2D = Art.tex[p.kind]
				ci.draw_texture(Art.tex.shadow, (p.pos + Vector2(-6, 3)).round())
				if p.kind == "snow":
					# glittering pile
					var g := 0.5 + 0.5 * sin(clock * 6.0)
					ci.draw_circle(p.pos.round(), 9.0, Color(1, 1, 1, 0.12 + 0.1 * g))
				ci.draw_texture(t, (p.pos - Vector2(t.get_width() / 2, t.get_height() / 2 + bob)).round())
				if p.kind == "snow" and int(clock * 8.0) % 3 == 0:
					ci.draw_rect(Rect2((p.pos + Vector2(rng.randi_range(-5, 5), rng.randi_range(-6, 0))).round(), Vector2.ONE), Color.WHITE)

	# y-sorted actors and props
	var list := []
	for e in enemies:
		if vr.has_point(e.pos):
			list.append([e.pos.y + 6.0 * e.scale, 0, e])
	if state != State.OVER:
		list.append([ppos.y + 6.0, 1, null])
	for pr in _visible_props():
		list.append([pr[1].y, 2, pr])
	list.sort_custom(func(a, b): return a[0] < b[0])

	# shadows first so they never overlap sprites
	for it in list:
		match it[1]:
			0:
				var e: Enemy = it[2]
				var st: Texture2D = Art.tex.shadow_big if e.boss else Art.tex.shadow
				ci.draw_texture(st, (e.pos + Vector2(-st.get_width() / 2, 5.0 * e.scale)).round())
			1:
				if intro_t <= 1.2:
					ci.draw_texture(Art.tex.shadow, (ppos + Vector2(-6, 5)).round())

	for it in list:
		match it[1]:
			0:
				_draw_enemy(ci, it[2])
			1:
				_draw_player(ci)
			2:
				var pr: Array = it[2]
				var t: Texture2D = Art.tex[pr[0]]
				var pos: Vector2 = pr[1]
				if pr[0] != "boat":
					ci.draw_texture(Art.tex.shadow, (pos + Vector2(-6, -2)).round())
				ci.draw_texture(t, (pos - Vector2(t.get_width() / 2, t.get_height())).round())


func _draw_enemy(ci: CanvasItem, e: Enemy) -> void:
	var frame := int(e.anim * 4.0) % 2
	var mod := Color.WHITE
	if e.flash > 0.0:
		mod = Color(6, 6, 6)
	_draw_sprite(ci, Art.tex["%s_%d" % [e.kind, frame]], e.pos, e.scale, e.face_left, mod)
	if e.kind == "don":
		# muzzle flash while spraying, "!" while revving
		if e.atk_state == 2 and int(clock * 30.0) % 2 == 0:
			var mz := e.pos + Vector2(-17.0 if e.face_left else 17.0, 6.0)
			ci.draw_circle(mz.round(), 3.0, Color8(252, 220, 72))
			ci.draw_circle(mz.round(), 1.5, Color.WHITE)
		elif e.atk_state == 1:
			Art.draw_text(ci, "!", e.pos + Vector2(-2, -34), Color8(228, 44, 60), 2, 0, true)
	elif e.boss:
		var w := 30.0
		var bp := (e.pos + Vector2(-w / 2.0, -22.0 * e.scale / 2.0 - 14.0)).round()
		ci.draw_rect(Rect2(bp - Vector2.ONE, Vector2(w + 2, 4)), Color8(20, 14, 28))
		ci.draw_rect(Rect2(bp, Vector2(w * maxf(0.0, e.hp / e.max_hp), 2)), Color8(236, 84, 200))


func _draw_player(ci: CanvasItem) -> void:
	if intro_t > 1.2:
		# lying in the sand, then a little shake as he comes to
		var jitter := Vector2(1, 0) if intro_t < 1.8 and int(clock * 20.0) % 2 == 0 else Vector2.ZERO
		_draw_sprite(ci, Art.tex.hero_0, ppos + Vector2(0, 6) + jitter, 1.0, false, Color.WHITE, -PI / 2.0)
		if int(clock * 2.0) % 2 == 0:
			Art.draw_text(ci, "Z", ppos + Vector2(8, -14), Color.WHITE, 1, 0, true)
		return
	var frame := (int(anim_t * 8.0) % 2) if pmoving else 0
	var mod := Color.WHITE
	if super_t > 0.0:
		var k := 0.5 + 0.5 * sin(clock * 20.0)
		mod = Color(1.0 + k * 0.6, 1.0 + k * 0.3, 1.0 + k * 0.6)
	if hurt_t > 0.0 and int(clock * 30.0) % 2 == 0:
		mod = Color(1.0, 0.35, 0.35)
	if iframe_t > 0.0 and dodge_t <= 0.0 and int(clock * 30.0) % 2 == 0:
		mod.a = 0.4
	var rot := 0.0
	if dodge_t > 0.0:
		rot = (1.0 - dodge_t / DODGE_TIME) * TAU * (1.0 if dodge_dir.x >= 0.0 else -1.0)
	_draw_sprite(ci, Art.tex["hero_%d" % frame], ppos, 1.0, pface.x < 0.0, mod, rot)

	if super_t > 0.0 and dodge_t <= 0.0:
		# M-16 held toward the target
		var left := cos(super_aim) < 0.0
		ci.draw_set_transform((_gun_pos() + Vector2(0, 1)).round(), super_aim, Vector2(1, -1 if left else 1))
		ci.draw_texture(Art.tex.m16, Vector2(-4, -3))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if hp < max_hp:
		var hb := (ppos + Vector2(-8, 9)).round()
		ci.draw_rect(Rect2(hb - Vector2.ONE, Vector2(18, 4)), Color8(20, 14, 28))
		ci.draw_rect(Rect2(hb, Vector2(16.0 * maxf(0.0, hp / max_hp), 2)), Color8(228, 44, 60))


func _draw_top(ci: CanvasItem) -> void:
	if state == State.TITLE:
		return
	var pink := Color8(236, 84, 200)

	# boombox rings
	if weapons.has("boombox") and state != State.OVER:
		var w: Dictionary = weapons.boombox
		var r: float = w.s.radius * stats.area
		ci.draw_arc(ppos.round(), r, 0.0, TAU, 40, Color(pink, 0.22), 1.0)
		var k := clampf(w.pulse / 0.3, 0.0, 1.0)
		if k < 1.0:
			ci.draw_arc(ppos.round(), r * k, 0.0, TAU, 40, Color(pink, 1.0 - k), 2.0)
			ci.draw_arc(ppos.round(), r * k * 0.6, 0.0, TAU, 32, Color(Color8(72, 228, 236), (1.0 - k) * 0.7), 1.0)

	# nunchucks
	if weapons.has("chucks") and state != State.OVER:
		var w: Dictionary = weapons.chucks
		var t: Texture2D = Art.tex.chuck
		for p in w.points:
			ci.draw_set_transform(p.round(), w.angle * 3.0, Vector2.ONE)
			ci.draw_texture(t, -Vector2(t.get_width() / 2, t.get_height() / 2))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# mace swing
	if weapons.has("mace") and state != State.OVER:
		var w: Dictionary = weapons.mace
		var dur := 0.2
		if w.swing_t < dur:
			var k: float = w.swing_t / dur
			var arc: float = w.s.arc
			var r: float = w.s.radius * stats.area
			var a: float = w.swing_dir - arc / 2.0 + arc * k
			ci.draw_arc(ppos.round(), r * 0.8, w.swing_dir - arc / 2.0, a, 24, Color(Color8(252, 220, 72), 0.5 * (1.0 - k)), 3.0)
			ci.draw_set_transform((ppos + Vector2.from_angle(a) * 6.0).round(), a, Vector2.ONE)
			ci.draw_texture(Art.tex.mace, Vector2(0, -3))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# projectiles
	for sh in shots:
		match sh.kind:
			"grenade":
				var k := minf(1.0, sh.t / sh.dur)
				var hgt := sin(k * PI) * 26.0 * clampf(sh.dur / 0.55, 0.5, 1.0)
				ci.draw_texture(Art.tex.shadow, (sh.pos + Vector2(-6, 2)).round())
				ci.draw_set_transform((sh.pos - Vector2(0, hgt)).round(), sh.rot, Vector2.ONE)
				ci.draw_texture(Art.tex.grenade, Vector2(-3, -3))
			"rocket":
				ci.draw_set_transform(sh.pos.round(), sh.vel.angle(), Vector2.ONE)
				ci.draw_texture(Art.tex.rocket, Vector2(-5, -2))
			"bolt":
				ci.draw_set_transform(sh.pos.round(), sh.vel.angle(), Vector2.ONE)
				ci.draw_texture(Art.tex.bolt, Vector2(-4, -1))
			"pellet":
				ci.draw_texture(Art.tex.pellet, (sh.pos - Vector2(1, 1)).round())
			_:
				ci.draw_set_transform(sh.pos.round(), sh.vel.angle(), Vector2.ONE)
				ci.draw_texture(Art.tex.bullet, Vector2(-2, -1))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# the Don's minigun bullets
	for s in eshots:
		ci.draw_rect(Rect2((s.pos - Vector2(2, 2)).round(), Vector2(4, 4)), Color8(144, 20, 44))
		ci.draw_rect(Rect2((s.pos - Vector2(1, 1)).round(), Vector2(2, 2)), Color8(252, 220, 72))

	# effects
	for f in fx:
		var k: float = f.t / f.dur
		match f.kind:
			"puff":
				var r: float = 2.0 + f.r * k
				ci.draw_circle(f.pos.round(), r, Color(f.color, 1.0 - k))
				ci.draw_circle(f.pos.round(), r * 0.55, Color(1, 1, 1, 1.0 - k))
			"boom":
				var grow := minf(1.0, k * 4.0)
				var r: float = f.r * grow
				if k < 0.5:
					ci.draw_circle(f.pos.round(), r, Color8(252, 136, 40))
					ci.draw_circle(f.pos.round(), r * 0.7, Color8(252, 220, 72))
					ci.draw_circle(f.pos.round(), r * 0.4 * (1.0 - k * 2.0), Color.WHITE)
				else:
					var a := 1.0 - (k - 0.5) * 2.0
					ci.draw_circle(f.pos.round(), r * (0.8 + k * 0.3), Color(0.25, 0.2, 0.3, a * 0.7))
					ci.draw_arc(f.pos.round(), r, 0.0, TAU, 32, Color(Color8(252, 136, 40), a), 2.0)
			"smoke":
				ci.draw_circle(f.pos.round(), f.r * (0.6 + k), Color(f.color, 0.6 * (1.0 - k)))
			"ring":
				ci.draw_arc(ppos.round(), f.r * (0.4 + k), 0.0, TAU, 32, Color(f.color, 1.0 - k), 2.0)
			"ghost":
				_draw_sprite(ci, Art.tex.hero_0, f.pos, 1.0, f.flip, Color(0.4, 0.9, 1.0, 0.5 * (1.0 - k)), f.rot)
			"text":
				Art.draw_text(ci, f.text, f.pos, Color(f.color, 1.0 - maxf(0.0, k - 0.6) * 2.5), 1, 1, true)

	# exit arrow from the pier, pointing north to Main Street
	if don_dead:
		var bobv := sin(clock * 5.0) * 3.0
		var tip := Vector2(pier_x, -88.0 + bobv).round()
		var col := Color8(252, 220, 72) if int(clock * 4.0) % 2 == 0 else Color8(252, 136, 40)
		var pts := PackedVector2Array([tip, tip + Vector2(-9, 10), tip + Vector2(-4, 10),
			tip + Vector2(-4, 20), tip + Vector2(4, 20), tip + Vector2(4, 10), tip + Vector2(9, 10)])
		var outline := PackedVector2Array()
		for p in pts:
			outline.append(p + Vector2(1, 1))
		ci.draw_colored_polygon(outline, Color8(20, 14, 28))
		ci.draw_colored_polygon(pts, col)
		Art.draw_text(ci, "MAIN ST", Vector2(pier_x + 14, -84.0 + bobv), Color.WHITE, 1, 0, true)
