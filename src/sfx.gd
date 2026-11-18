extends Node
## Tiny sound manager: a pool of players, per-sound rate limiting, looping music.

const SOUNDS := ["shoot", "uzi", "shotgun", "hit", "die", "gem", "pickup", "levelup",
	"explode", "hurt", "select", "confirm", "throw", "siren", "gameover"]
const POOL := 12

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var last_played := {}
var music: AudioStreamPlayer
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		streams[s] = load("res://audio/%s.wav" % s)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.stream = load("res://audio/music.wav")
	music.volume_db = -6.0
	music.finished.connect(func(): music.play())
	add_child(music)


func play(name: String, pitch_jitter: float = 0.08, volume_db: float = 0.0, min_gap: float = 0.03) -> void:
	if muted or not streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(name, -1.0)) < min_gap:
		return
	last_played[name] = now
	var p := players[next]
	next = (next + 1) % POOL
	p.stream = streams[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func start_music() -> void:
	if not muted and not music.playing:
		music.play()


func stop_music() -> void:
	music.stop()


func toggle_mute() -> void:
	muted = not muted
	if muted:
		music.stop()
		for p in players:
			p.stop()
	else:
		music.play()
