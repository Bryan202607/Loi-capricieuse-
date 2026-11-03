extends Node
# Gestionnaire de sons : effets (plusieurs en même temps) + musique en boucle.
# Les fichiers viennent de assets/sfx (générés par tools/gen_sounds.py).

const NAMES := ["pickup", "gold", "deposit", "splash", "bell", "board", "win", "lose", "tick", "tap", "rumble", "sting", "owl", "crickets", "dawn", "star"]

var sounds := {}
var pool: Array = []
var music: AudioStreamPlayer
var muted := false
var music_tween: Tween


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			sounds[n] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -10.0
	add_child(music)
	var mpath := "res://assets/sfx/music.wav"
	if ResourceLoader.exists(mpath):
		var m = load(mpath)
		if m is AudioStreamWAV:
			m.loop_mode = AudioStreamWAV.LOOP_FORWARD
			m.loop_begin = 0
			m.loop_end = m.data.size() / 2
		music.stream = m
		music.play()


func play(name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(name):
		return
	for p in pool:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return


func set_muted(v: bool) -> void:
	muted = v
	AudioServer.set_bus_mute(0, v)


# Fait varier doucement le volume de la musique (ex. baisser pendant le suspense).
func set_music_db(db: float, dur: float = 1.0) -> void:
	if music == null:
		return
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music, "volume_db", db, dur)
