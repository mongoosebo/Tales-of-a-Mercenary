extends Node2D
## Tales of a Mercenary - main game logic.
##
## Enemies, shots, pickups and effects are plain objects drawn in a few batched
## _draw() passes rather than one node each, so hundreds of enemies stay cheap
## (important for the web build).

const Data := preload("res://src/data.gd")
const Drawer := preload("res://src/drawer.gd")
const Hud := preload("res://src/hud.gd")

const WIN_TIME := 15.0 * 60.0
const CELL := 24.0
const MAX_ENEMIES := 360
const MAX_GEMS := 400
const BASE_SPEED := 72.0
const BASE_MAGNET := 26.0
const PROP_CELL := 112

## [time in seconds, event]
const EVENTS := [
	[150.0, "ring"], [300.0, "boss"], [390.0, "ring"], [480.0, "swarm"],
	[600.0, "boss"], [690.0, "ring"], [780.0, "swarm"], [840.0, "boss"],
]

enum State { TITLE, PLAY, LEVELUP, PAUSE, OVER, WIN }


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


class Pickup:
	var kind := "gem"  # gem, pizza, magnet, case
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


var state: State = State.TITLE
var rng := RandomNumberGenerator.new()
var cam: Camera2D
var hud: Node2D
var shake := 0.0
var clock := 0.0

# player
var ppos := Vector2.ZERO
var pface := Vector2.RIGHT
var pmoving := false
var anim_t := 0.0
var hp := 100.0
var max_hp := 100.0
var hurt_t := 0.0
var level := 1
var xp := 0.0
var xp_next := 5.0
var kills := 0
var score := 0
var time := 0.0
var stats := {}

var weapons := {}
var weapon_order: Array = []
var passives := {}
var passive_order: Array = []

var enemies: Array = []
var shots: Array = []
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

# touch joystick
var touch_idx := -1
var touch_origin := Vector2.ZERO
var touch_vec := Vector2.ZERO

# automated test mode (used by CI / local headless runs)
var autotest := -1.0
var god := false
var shot_path := ""
var shot_at := -1.0


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

	_reset_run()
	state = State.TITLE

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			autotest = float(a.get_slice("=", 1))
		elif a == "--god":
			god = true
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--shot-at="):
			shot_at = float(a.get_slice("=", 1))
	if autotest > 0.0 and not "--title" in OS.get_cmdline_user_args():
		_start()


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("confirm", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z], [JOY_BUTTON_A], [])
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
	ppos = Vector2.ZERO
	pface = Vector2.RIGHT
	hp = 100.0
	max_hp = 100.0
	hurt_t = 0.0
	level = 1
	xp = 0.0
	xp_next = _xp_for(1)
	kills = 0
	score = 0
	time = 0.0
	weapons.clear()
	weapon_order.clear()
	passives.clear()
	passive_order.clear()
	enemies.clear()
	shots.clear()
	pickups.clear()
	fx.clear()
	grid.clear()
	spawn_t = 0.5
	events_done.clear()
	bosses_spawned = 0
	banner = ""
	banner_t = 0.0
	pending = 0
	_recalc_stats()
	_add_weapon("pistol")


func _start() -> void:
	_reset_run()
	state = State.PLAY
	Sfx.play("confirm", 0.0)
	Sfx.stop_music()
	Sfx.start_music()


func _xp_for(lvl: int) -> float:
	return 5.0 + (lvl - 1) * 9.0 + floorf(pow(lvl - 1, 2) * 0.3)


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
		"pulse": 1.0, "points": [], "s": Data.weapon_stats(id, 1),
	}
	weapon_order.append(id)


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
		_:
			pass

	if autotest > 0.0:
		_autotest_step()

	shake = maxf(0.0, shake - delta * 10.0)
	cam.position = ppos.round()
	cam.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)).round()


func _update_play(delta: float) -> void:
	time += delta
	if time >= WIN_TIME:
		_win()
		return

	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_idx >= 0:
		v = touch_vec
	if autotest > 0.0:
		v = Vector2.from_angle(time * 0.4) * 0.9
		var best: Pickup = null
		var bd := 1e9
		for p in pickups:
			var d2: float = p.pos.distance_squared_to(ppos)
			if d2 < bd:
				bd = d2
				best = p
		if best != null and bd < 150.0 * 150.0:
			v = (best.pos - ppos).normalized()
	v = v.limit_length(1.0)
	pmoving = v.length() > 0.1
	if pmoving:
		pface = v.normalized()
		anim_t += delta * v.length()
	ppos += v * BASE_SPEED * stats.speed * delta

	hp = minf(max_hp, hp + stats.regen * delta)
	hurt_t -= delta
	banner_t -= delta

	_spawn(delta)
	_build_grid()
	_update_enemies(delta)
	_update_weapons(delta)
	_update_shots(delta)
	_update_pickups(delta)
	_update_fx(delta)
	enemies = enemies.filter(func(e): return not e.dead)

	if hp <= 0.0:
		if god:
			hp = max_hp
		else:
			_game_over()
			return
	if pending > 0:
		_open_levelup()


# ====================================================================== spawning

func _spawn(delta: float) -> void:
	for ev in EVENTS:
		if time >= ev[0] and not events_done.has(ev[0]):
			events_done[ev[0]] = true
			_run_event(ev[1])

	spawn_t -= delta
	if spawn_t > 0.0:
		return
	var m := time / 60.0
	spawn_t = maxf(0.12, 0.6 - m * 0.04)
	var target := mini(MAX_ENEMIES, 10 + int(m * 24.0))
	var batch := 1 + int(m / 2.5)
	for i in batch:
		if enemies.size() >= target:
			break
		_spawn_enemy(_pick_kind(m), _offscreen_pos())


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
	return ppos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 230.0)


func _spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var d: Dictionary = Data.ENEMIES[kind]
	var e := Enemy.new()
	e.kind = kind
	e.pos = pos
	var m := time / 60.0
	e.boss = kind == "boss"
	if e.boss:
		e.max_hp = d.hp * (1.0 + bosses_spawned * 1.2)
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
	var m := time / 60.0
	match kind:
		"ring":
			var n := 40
			var k := "ninja" if m >= 5.0 else "punk"
			for i in n:
				_spawn_enemy(k, ppos + Vector2.from_angle(TAU * i / n) * 170.0)
			banner = "THEY'VE GOT YOU SURROUNDED!"
			banner_t = 2.5
		"swarm":
			var a := rng.randf() * TAU
			var center := ppos + Vector2.from_angle(a) * 210.0
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
	var pad := r + 16.0
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
		if dist > 340.0 and not e.boss:
			# wandered too far behind: bring them back in front of the player
			e.pos = ppos + (to / dist).rotated(rng.randf_range(-0.7, 0.7)) * 215.0
			continue
		var dir := to / maxf(dist, 0.001)
		var vel: Vector2 = dir * e.speed

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
		e.knock *= damp
		e.flash -= delta
		e.chuck_cd -= delta
		e.anim += delta * e.speed / 28.0
		e.face_left = dir.x < 0.0

		if dist < e.radius + 5.0:
			_hurt_player(e.dmg * delta)


func _hurt_player(amount: float) -> void:
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
		return
	_drop_gem(e.pos, e.xp)
	var r := rng.randf()
	if r < 0.006:
		_drop("pizza", e.pos)
	elif r < 0.0085:
		_drop("magnet", e.pos)


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
		"uzi":
			return a * 3
		"shotgun":
			return a * 2
		"boombox":
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
			_:
				w.t -= delta
				if w.t <= 0.0:
					w.t = s.cd * stats.cd
					_fire(id, w, s)
				if id == "uzi" and w.burst > 0:
					w.burst_t -= delta
					while w.burst > 0 and w.burst_t <= 0.0:
						w.burst_t += 0.045
						w.burst -= 1
						var dir := pface.rotated(rng.randf_range(-s.spread, s.spread))
						_add_shot("bullet", _gun_pos(), dir * s.speed, s.dmg, s.pierce, 0.9, 3.0, 12.0)
						Sfx.play("uzi", 0.1, -6.0, 0.04)


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
		"uzi":
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
				var sh := _add_shot("pellet", _gun_pos(), dir * s.speed * rng.randf_range(0.85, 1.15),
					s.dmg, s.pierce, s.life, 3.0, s.knock)
				sh.rot = 0.0
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
				var sh := _add_shot("grenade", ppos, Vector2.ZERO, s.dmg, 99, 99.0, 0.0, 0.0)
				sh.start = ppos
				sh.target_pos = tp
				sh.dur = 0.55 + i * 0.08
				sh.blast = s.radius
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
		if not p.pulled and l2 < mag2:
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
		var lvl: int = passives.get(id, 0)
		if lvl > 0:
			if lvl < Data.PASSIVES[id].max:
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
			var lvl: int = passives.get(c.id, 0)
			if lvl == 0:
				passive_order.append(c.id)
			passives[c.id] = lvl + 1
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
	Sfx.play("gameover", 0.0, 0.0, 0.0)
	_add_fx("boom", ppos, 0.6, 20.0, Color.WHITE)


func _win() -> void:
	state = State.WIN
	menu_t = 0.0
	for e in enemies:
		_add_fx("puff", e.pos, 0.5, 8.0, Color8(252, 220, 72))
	enemies.clear()
	shots.clear()
	score += 5000
	Sfx.play("levelup", 0.0, 0.0, 0.0)


# ====================================================================== input

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY and autotest < 0.0:
		state = State.PAUSE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		Sfx.toggle_mute()
		return

	# touch joystick (works in any state; only used while playing)
	if event is InputEventScreenTouch:
		if event.pressed and touch_idx < 0 and state == State.PLAY:
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
		print("AUTOTEST END state=%s time=%.1f level=%d kills=%d" % [State.keys()[state], time, level, kills])
		get_tree().quit()
		return
	if shot_path != "" and ((shot_at > 0.0 and time >= shot_at) or (shot_at == 0.0 and clock > 1.0)):
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("screenshot saved ", shot_path)
		shot_path = ""
	if int(time * 60.0) % 600 == 0 and state == State.PLAY:
		print("t=%.0f lvl=%d hp=%.0f enemies=%d shots=%d pickups=%d fx=%d weapons=%s passives=%s fps=%d" % [
			time, level, hp, enemies.size(), shots.size(), pickups.size(), fx.size(),
			str(weapon_order), str(passives), Engine.get_frames_per_second()])
	if time >= autotest or (state == State.TITLE and clock > 1.5):
		print("AUTOTEST DONE time=%.1f level=%d kills=%d enemies=%d" % [time, level, kills, enemies.size()])
		get_tree().quit()


# ====================================================================== drawing

func _hash(x: int, y: int) -> int:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _view_rect(margin: float = 24.0) -> Rect2:
	return Rect2(ppos - Vector2(160, 90) - Vector2(margin, margin), Vector2(320, 180) + Vector2(margin, margin) * 2.0)


func _draw_floor(ci: CanvasItem) -> void:
	var origin := Vector2(floorf((ppos.x - 200.0) / 64.0) * 64.0, floorf((ppos.y - 140.0) / 64.0) * 64.0)
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


func _visible_props() -> Array:
	var out := []
	var vr := _view_rect(32.0)
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


func _draw_sprite(ci: CanvasItem, tex: Texture2D, pos: Vector2, s: float, flip: bool, mod: Color = Color.WHITE) -> void:
	ci.draw_set_transform(pos.round(), 0.0, Vector2(-s if flip else s, s))
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
				ci.draw_texture(t, (p.pos - Vector2(t.get_width() / 2, t.get_height() / 2 + bob)).round())

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
				ci.draw_texture(Art.tex.shadow, (ppos + Vector2(-6, 5)).round())

	for it in list:
		match it[1]:
			0:
				var e: Enemy = it[2]
				var frame := int(e.anim * 4.0) % 2
				var mod := Color.WHITE
				if e.flash > 0.0:
					mod = Color(6, 6, 6)
				_draw_sprite(ci, Art.tex["%s_%d" % [e.kind, frame]], e.pos, e.scale, e.face_left, mod)
				if e.boss:
					var w := 30.0
					var bp := (e.pos + Vector2(-w / 2.0, -22.0 * e.scale / 2.0 - 14.0)).round()
					ci.draw_rect(Rect2(bp - Vector2.ONE, Vector2(w + 2, 4)), Color8(20, 14, 28))
					ci.draw_rect(Rect2(bp, Vector2(w * maxf(0.0, e.hp / e.max_hp), 2)), Color8(236, 84, 200))
			1:
				var frame := (int(anim_t * 8.0) % 2) if pmoving else 0
				var mod := Color.WHITE
				if hurt_t > 0.0 and int(clock * 30.0) % 2 == 0:
					mod = Color(1.0, 0.35, 0.35)
				_draw_sprite(ci, Art.tex["hero_%d" % frame], ppos, 1.0, pface.x < 0.0, mod)
				if hp < max_hp:
					var hb := (ppos + Vector2(-8, 9)).round()
					ci.draw_rect(Rect2(hb - Vector2.ONE, Vector2(18, 4)), Color8(20, 14, 28))
					ci.draw_rect(Rect2(hb, Vector2(16.0 * maxf(0.0, hp / max_hp), 2)), Color8(228, 44, 60))
			2:
				var pr: Array = it[2]
				var t: Texture2D = Art.tex[pr[0]]
				var pos: Vector2 = pr[1]
				ci.draw_texture(Art.tex.shadow, (pos + Vector2(-6, -2)).round())
				ci.draw_texture(t, (pos - Vector2(t.get_width() / 2, t.get_height())).round())


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

	# projectiles
	for sh in shots:
		match sh.kind:
			"grenade":
				var k := minf(1.0, sh.t / sh.dur)
				var hgt := sin(k * PI) * 26.0
				ci.draw_texture(Art.tex.shadow, (sh.pos + Vector2(-6, 2)).round())
				ci.draw_set_transform((sh.pos - Vector2(0, hgt)).round(), sh.rot, Vector2.ONE)
				ci.draw_texture(Art.tex.grenade, Vector2(-3, -3))
			"rocket":
				ci.draw_set_transform(sh.pos.round(), sh.vel.angle(), Vector2.ONE)
				ci.draw_texture(Art.tex.rocket, Vector2(-5, -2))
			"pellet":
				ci.draw_texture(Art.tex.pellet, (sh.pos - Vector2(1, 1)).round())
			_:
				ci.draw_set_transform(sh.pos.round(), sh.vel.angle(), Vector2.ONE)
				ci.draw_texture(Art.tex.bullet, Vector2(-2, -1))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
			"text":
				Art.draw_text(ci, f.text, f.pos, Color(f.color, 1.0 - maxf(0.0, k - 0.6) * 2.5), 1, 1, true)
