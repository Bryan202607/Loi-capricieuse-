extends Node2D
# Lois Capricieuses - v4
# Parcours : cinématique d'ouverture -> écran d'accueil -> niveaux -> partie.
# Partie : traverser la rivière EN BATEAU (nager = mourir), attraper des fruits
# (3 à la fois) et les rapporter à la cabane avant la fin du temps, malgré deux
# lois de la nature (les mêmes à chaque fois pour un niveau donné).
# Victoire -> la nuit tombe (suspense) -> score -> aube -> niveau suivant.
# Sauvegarde : niveau atteint, étoiles et score de chaque niveau, son.
# Images : assets/ (tools/gen_assets*.py). Sons : assets/sfx (tools/gen_sounds.py).

const Laws = preload("res://laws.gd")
const Sfx = preload("res://sfx.gd")
const Lang = preload("res://lang.gd")
const Data = preload("res://levels_data.gd")

const W := 720.0
const H := 1280.0
const TOP_BAR := 150.0
const RIVER_TOP := 520.0
const RIVER_BOT := 760.0
const HUT_POS := Vector2(360, 1205)
const HUT_DRAW := Vector2(360, 1222)
const HUT2_DRAW := Vector2(548, 1106)
const BOAT_X := 360.0
const BOAT_N_Y := RIVER_TOP + 58.0
const BOAT_S_Y := RIVER_BOT - 58.0
const BOAT_SPEED := 70.0
const BOAT_PAUSE := 2.0
const BOARD_RADIUS := 100.0
const CAPACITY_BASE := 3
const BASE_SPEED := 270.0
const SOLUTION_AFTER := 5
# --- Monétisation (cœurs, pubs, version sans pub) ---
# TEST_MODE = true : les pubs sont des écrans d'essai raccourcis (x0,2) et l'achat est simulé.
# AVANT PUBLICATION : mettre false et brancher AdMob (pubs) + Google Play Billing (achat).
const TEST_MODE := true
const MAX_HEARTS := 5
const HEART_SECS := 300.0
const REWIND_SECS := 20.0
const AD_COMEBACK := 25.0
const AD_SKIP := 30.0
const AD_INTER := 15.0
const SKIP_AFTER_DEATHS := 3
const AD_EVERY := 3
const DIE_TIME := 0.9
const GOLD_BONUS := 8.0
const MAX_LEVEL := 160
const IMPOSSIBLE_FROM := 156
const EXTREME_FROM := 100
const LEVELS_PER_PAGE := 12
const MAX_PAGES := 14
const DUSK_LEN := 6.6
const DAWN_LEN := 2.8
const CINE_LEN := 21.0
const MUTE_RECT := Rect2(644, 2, 74, 58)
const PAUSE_RECT := Rect2(566, 2, 74, 58)
const HOME_RECT := Rect2(20, 160, 150, 56)

const PLAYER_ANCHOR := Vector2(48, 90)
const FRUIT_ANCHOR := Vector2(28, 38)
const BOAT_ANCHOR := Vector2(46, 66)
const HUT_ANCHOR := Vector2(110, 182)
const HUT2_ANCHOR := Vector2(79, 131)
const TREE_ANCHOR := Vector2(64, 148)
const BUSH_ANCHOR := Vector2(36, 44)
const ROCK_ANCHOR := Vector2(32, 40)

const VIL_SPOTS := [Vector2(212, 1236), Vector2(512, 1238), Vector2(176, 1168),
		Vector2(548, 1180), Vector2(128, 1244), Vector2(604, 1252)]
const CINE_VIL := [Vector2(170, 880), Vector2(270, 905), Vector2(450, 905), Vector2(550, 880)]
const DAY_TINTS := [Color(1.0, 0.86, 0.55, 0.10), Color(1, 1, 1, 0.0),
		Color(1.0, 0.5, 0.2, 0.15), Color(0.45, 0.55, 1.0, 0.10)]
const CONFETTI := [Color("ff6b6b"), Color("ffd166"), Color("7ee081"), Color("4aa8ee"), Color("f06aa8")]
const CURATED := [["fruits_aimants", "vent_est"], ["eau_solide", "fruits_timides"], ["pieds_plomb", "eau_monte"],
		["nuit", "fruits_aimants"], ["pluie", "grand_sac"], ["bateau_fou", "fruits_vagabonds"]]
const DUSK_LINES := ["Un vent étrange se lève au loin...", "Quelque chose bouge dans l'obscurité...",
		"Les lois de demain restent un mystère...", "La rivière murmure d'étranges secrets...",
		"Les villageois dorment. La nature, elle, veille...", "Demain, les règles vont encore changer..."]
const CINE_CAPTIONS := [
	[0.5, 5.2, "Il était une fois, un village paisible\nau bord d'une rivière..."],
	[5.9, 10.5, "Mais un matin, la nature a décidé\nde changer toutes ses règles !"],
	[11.2, 16.0, "Les fruits sont restés de l'autre côté de l'eau.\nSans eux, le village ne passera pas l'hiver..."],
	[16.6, 20.4, "Toi seul peux traverser la rivière.\nBonne chance, héros !"],
]
const CINE_BANNERS := [
	["L'EAU DEVIENT GLACE !", Color("b8e6fa")], ["LE COURANT S'INVERSE !", Color("4aa8ee")],
	["LA PLUIE S'ABAT !", Color("78a4c8")], ["LE VENT SE DÉCHAÎNE !", Color("33c9a8")],
	["LA NUIT TOMBE EN PLEIN JOUR !", Color("9fa8ff")],
]


# Couche additive pour les lueurs (nuit).
class LightLayer extends Node2D:
	var game
	func _draw() -> void:
		if game != null:
			game.draw_lights(self)


# --- État du jeu ---
var state := "cine"   # cine, menu, levels, confirm, intro, play, pause, dying, dusk, win, lose, dawn
var lose_reason := "temps"
var level := 1
var cur_level := 1
var best_day := 1
var level_stars: Array = []
var level_score: Array = []
var last_stars := 0
var last_score := 0
var new_record := false
var muted := false
var relaxed := false
var hearts := MAX_HEARTS
var next_heart := 0.0
var premium := false
# --- Statistiques en ligne (Firebase Realtime Database) ---
# Colle ici l'adresse de ta base, ex. "https://mon-projet-default-rtdb.firebaseio.com". Vide = désactivé.
const STATS_URL := "https://loi-capricieuse-default-rtdb.firebaseio.com"
var player_id := ""
var share_stats := true
var deaths_total := 0
var wins_total := 0
var play_secs := 0.0
var first_seen := 0
var http: HTTPRequest
var sync_cd := 0.0
var sync_dirty := false
var history: Array = []
var hist_t := 0.0
var ad_kind := ""
var ad_left := 0.0
var ad_len_cur := 0.0
var ad_base := 0.0
var ad_idx := 1
var ad_n := 1
var ad_cancelable := true
var shop_return := "settings"
# --- Pièges cachés (positions fixes par niveau, jamais montrés avant une mort) ---
var traps: Array = []
var strikes: Array = []
var strike_t := 0.0
var strike_rng := RandomNumberGenerator.new()
var trap_cfg := {}
var fake_spots: Array = []
var shown := {}
var hit_trap := -1
var dead_reason := "noyade"
var flash := 0.0
var boulders: Array = []
var boulder_t := 0.0
var fail_count := 0
var fail_level := 0
var laws: Array = []
var goal := 5
var total_time := 75.0
var pos := Vector2(360, 940)
var vel := Vector2.ZERO
var target := Vector2.ZERO
var has_target := false
var moving := false
var facing := 1.0
var hero_cheer := false
var fruits: Array = []
var carried := 0
var deposited := 0
var time_left := 75.0
var last_sec := 0
var t := 0.0
var win_t := 0.0
var dusk_t := 0.0
var dawn_t := 0.0
var cine_t := 0.0
var cine_scene := 0
var cine_phase := -1
var fired := {}
var dusk_amt := 0.0
var ui_lock := 0.0
var die_t := 0.0
var shake := 0.0
var cur_shake := Vector2.ZERO
var cam_zoom := 1.0
var cam_center := Vector2(360, 640)
var conf_cd := 0.0
var ring_cd := 0.0
var press_id := ""
var lvl_page := 0

# --- Bateau ---
var boat_y := BOAT_S_Y
var boat_to_north := true
var boat_wait := 1.0
var riding := false
var board_cd := 0.0

# --- Effets des lois (recalculés à chaque niveau) ---
var speed_mult := 1.0
var slippery := false
var mirror := false
var river_push := Vector2.ZERO
var boat_pause := BOAT_PAUSE
var boat_speed_mult := 1.0
var capacity := CAPACITY_BASE
var water_solid := false
var fruit_mode := "static"
var wind := Vector2.ZERO
var night := false
var rain := false
var leaves := false

# --- Images, sons, décor, effets ---
var tex := {}
var decor: Array = []
var extra := 0.0
var top_y := 150.0
var cam_y := 0.0
var flowers: Array = []
var particles: Array = []
var floaters: Array = []
var sfx
var light_layer: Node2D


func _ready() -> void:
	randomize()
	sfx = Sfx.new()
	add_child(sfx)
	load_textures()
	build_decor()
	build_light_layer()
	load_save()
	http = HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	sfx.set_muted(muted)
	level = cur_level
	sync_stats(true)
	laws = []
	apply_laws()
	compute_day_params()
	start_cine()


func load_textures() -> void:
	var names := ["grass", "water", "ice", "bank_n", "bank_s", "landing", "player", "player_w1", "player_w2",
			"player_cheer", "fruit", "gold", "boat", "hut", "hut2", "tree", "bush", "rock",
			"flower_a", "flower_b", "flower_c", "star", "star_off", "glow"]
	for i in 4:
		names.append("vil%d_idle" % i)
		names.append("vil%d_cheer" % i)
	for n in names:
		tex[n] = load("res://assets/%s.png" % n)


func build_decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	decor.clear()
	flowers.clear()
	for s in [Vector2(34, 230), Vector2(690, 300), Vector2(40, 440), Vector2(684, 480),
			Vector2(40, 880), Vector2(690, 950), Vector2(36, 1090), Vector2(688, 1130), Vector2(24, 1236)]:
		decor.append({"kind": "tree", "pos": s})
	for s in [Vector2(108, 470), Vector2(622, 226), Vector2(116, 890), Vector2(612, 1010), Vector2(668, 1240)]:
		decor.append({"kind": "bush", "pos": s})
	for s in [Vector2(604, 446), Vector2(92, 290), Vector2(632, 850), Vector2(98, 1170)]:
		decor.append({"kind": "rock", "pos": s})
	var kinds := ["flower_a", "flower_b", "flower_c"]
	for i in 46:
		var y := 0.0
		if r.randf() < 0.5:
			y = r.randf_range(TOP_BAR + 30.0, RIVER_TOP - 40.0)
		else:
			y = r.randf_range(RIVER_BOT + 40.0, H - 20.0)
		flowers.append({"kind": kinds[r.randi() % 3], "pos": Vector2(r.randf_range(16.0, W - 16.0), y)})


func build_light_layer() -> void:
	light_layer = LightLayer.new()
	light_layer.game = self
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light_layer.material = mat
	add_child(light_layer)


# --- Sauvegarde ---
func blank_progress() -> void:
	level_stars = []
	level_score = []
	for i in MAX_LEVEL + 1:
		level_stars.append(0)
		level_score.append(0)


func load_save() -> void:
	blank_progress()
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		best_day = clampi(int(cfg.get_value("game", "best_day", 1)), 1, MAX_LEVEL)
		cur_level = clampi(int(cfg.get_value("game", "cur_level", best_day)), 1, best_day)
		muted = bool(cfg.get_value("game", "muted", false))
		relaxed = bool(cfg.get_value("game", "relaxed", false))
		premium = bool(cfg.get_value("game", "premium", false))
		hearts = clampi(int(cfg.get_value("game", "hearts", MAX_HEARTS)), 0, MAX_HEARTS)
		next_heart = float(cfg.get_value("game", "next_heart", 0.0))
		Lang.code = str(cfg.get_value("game", "lang", default_lang()))
		player_id = str(cfg.get_value("game", "player_id", ""))
		share_stats = bool(cfg.get_value("game", "share_stats", true))
		deaths_total = int(cfg.get_value("game", "deaths_total", 0))
		wins_total = int(cfg.get_value("game", "wins_total", 0))
		play_secs = float(cfg.get_value("game", "play_secs", 0.0))
		first_seen = int(cfg.get_value("game", "first_seen", 0))
		var st = cfg.get_value("game", "stars_list", [])
		var sc = cfg.get_value("game", "score_list", [])
		for i in mini(st.size(), level_stars.size()):
			level_stars[i] = int(st[i])
		for i in mini(sc.size(), level_score.size()):
			level_score[i] = int(sc[i])
	else:
		best_day = 1
		cur_level = 1
		Lang.code = default_lang()
	ensure_player_id()


func ensure_player_id() -> void:
	if player_id.length() < 16:
		player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if first_seen == 0:
		first_seen = int(Time.get_unix_time_from_system())


func stats_payload() -> Dictionary:
	return {
		"best_day": best_day,
		"cur_level": cur_level,
		"stars": total_stars(),
		"score": total_score(),
		"deaths": deaths_total,
		"wins": wins_total,
		"play_secs": int(play_secs),
		"premium": premium,
		"lang": Lang.code,
		"relaxed": relaxed,
		"platform": OS.get_name(),
		"version": str(ProjectSettings.get_setting("application/config/version", "1.0")),
		"first_seen": first_seen,
		"last_seen": int(Time.get_unix_time_from_system()),
	}


# Envoie les stats du joueur (identifiant anonyme) à la base en ligne, si elle est configurée.
func sync_stats(force: bool) -> void:
	if STATS_URL == "" or not share_stats or http == null or player_id == "":
		return
	if not force and sync_cd > 0.0:
		sync_dirty = true
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := "%s/players/%s.json" % [STATS_URL.trim_suffix("/"), player_id]
	var err := http.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_PUT, JSON.stringify(stats_payload()))
	if err == OK:
		sync_cd = 20.0
		sync_dirty = false


func stats_tick(delta: float) -> void:
	if state == "play":
		play_secs += delta
	sync_cd = maxf(0.0, sync_cd - delta)
	if sync_dirty and sync_cd <= 0.0:
		sync_stats(false)
	elif state == "play" and fmod(play_secs, 90.0) < delta:
		sync_dirty = true


func short_id() -> String:
	return player_id.substr(0, 8).to_upper()


func default_lang() -> String:
	var l := OS.get_locale_language()
	if Lang.CODES.has(l):
		return l
	return "en"


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best_day", best_day)
	cfg.set_value("game", "cur_level", cur_level)
	cfg.set_value("game", "muted", muted)
	cfg.set_value("game", "relaxed", relaxed)
	cfg.set_value("game", "premium", premium)
	cfg.set_value("game", "hearts", hearts)
	cfg.set_value("game", "next_heart", next_heart)
	cfg.set_value("game", "lang", Lang.code)
	cfg.set_value("game", "player_id", player_id)
	cfg.set_value("game", "share_stats", share_stats)
	cfg.set_value("game", "deaths_total", deaths_total)
	cfg.set_value("game", "wins_total", wins_total)
	cfg.set_value("game", "play_secs", play_secs)
	cfg.set_value("game", "first_seen", first_seen)
	cfg.set_value("game", "stars_list", level_stars)
	cfg.set_value("game", "score_list", level_score)
	cfg.save("user://save.cfg")


func reset_progress() -> void:
	blank_progress()
	best_day = 1
	cur_level = 1
	level = 1
	save_game()


func total_stars() -> int:
	var s := 0
	for v in level_stars:
		s += int(v)
	return s


func total_score() -> int:
	var s := 0
	for v in level_score:
		s += int(v)
	return s


func T(s: String) -> String:
	return Lang.t(s)


func snd(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if sfx != null:
		sfx.play(n, vol_db, pitch)


func fire(key: String, sound: String, vol: float = 0.0) -> void:
	if not fired.has(key):
		fired[key] = true
		snd(sound, vol)


func toggle_mute() -> void:
	muted = not muted
	sfx.set_muted(muted)
	save_game()


# --- Niveaux : les lois sont toujours les mêmes pour un niveau donné ---
func level_laws(lv: int) -> Array:
	var all: Array = Laws.all()
	if lv >= 1 and lv <= CURATED.size():
		var c: Array = CURATED[lv - 1]
		var res: Array = []
		for id in c:
			for l in all:
				if l["id"] == id:
					res.append(l)
		return res
	var res: Array = []
	for attempt in 30:
		res = _roll_laws(lv, attempt)
		var ids := []
		for l in res:
			ids.append(l["id"])
		# Cette paire fait glisser le héros dans l'eau trop souvent : on retire ce tirage.
		if not (ids.has("fruits_timides") and ids.has("pieds_plume")):
			break
	return res


func _roll_laws(lv: int, attempt: int) -> Array:
	var all: Array = Laws.all()
	var r := RandomNumberGenerator.new()
	r.seed = lv * 7919 + 13 + attempt * 104729
	for i in range(all.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = all[i]
		all[i] = all[j]
		all[j] = tmp
	var a = all[0]
	var b = null
	for l in all:
		if l["group"] != a["group"]:
			b = l
			break
	if lv >= EXTREME_FROM:
		for l in all:
			if l["group"] != a["group"] and l["group"] != b["group"]:
				return [a, b, l]
	return [a, b]


func new_day() -> void:
	laws = level_laws(level)
	apply_laws()
	compute_day_params()
	if level != fail_level:
		fail_count = 0
		fail_level = level
	reset_scene()
	time_left = total_time
	state = "intro"
	ui_lock = 0.4


func reset_scene() -> void:
	traps.clear()
	strikes.clear()
	boulders.clear()
	fake_spots.clear()
	shown = {}
	hit_trap = -1
	flash = 0.0
	history.clear()
	hist_t = 0.0
	deposited = 0
	carried = 0
	fruits.clear()
	particles.clear()
	floaters.clear()
	pos = Vector2(360, 940)
	vel = Vector2.ZERO
	has_target = false
	moving = false
	riding = false
	hero_cheer = false
	board_cd = 0.0
	boat_y = BOAT_S_Y
	boat_to_north = true
	boat_wait = 1.0


func difficulty(lv: int) -> float:
	return clampf((lv - 1) / 154.0, 0.0, 1.0)


func goal_for(lv: int) -> int:
	if lv >= IMPOSSIBLE_FROM:
		return 25 + (lv - IMPOSSIBLE_FROM) * 5
	return mini(5 + floori((lv - 1) / 10.0), 20)


func tier_name(lv: int) -> String:
	if lv >= IMPOSSIBLE_FROM:
		return T("IMPOSSIBLE")
	if lv >= EXTREME_FROM:
		return T("EXTRÊME")
	if lv >= 70:
		return T("TRÈS DIFFICILE")
	if lv >= 40:
		return T("DIFFICILE")
	if lv >= 15:
		return T("NORMAL")
	return T("FACILE")


func tier_color(lv: int) -> Color:
	if lv >= IMPOSSIBLE_FROM:
		return Color("4a1f2a")
	if lv >= EXTREME_FROM:
		return Color("8e24aa")
	if lv >= 70:
		return Color("e53935")
	if lv >= 40:
		return Color("fb8c00")
	if lv >= 15:
		return Color("1e88e5")
	return Color("43a047")


func compute_day_params() -> void:
	goal = goal_for(level)
	if level >= IMPOSSIBLE_FROM:
		total_time = 45.0
	else:
		# Temps = ce dont le robot de test a besoin x une marge qui se réduit avec les niveaux.
		var need: float = float(Data.NEED[level - 1])
		var margin := 2.5 - 1.1 * (level - 1) / 99.0
		if level >= EXTREME_FROM:
			margin = 1.3 - 0.2 * (level - EXTREME_FROM) / float(IMPOSSIBLE_FROM - 1 - EXTREME_FROM)
		total_time = maxf(round(need * margin), 30.0)
	if relaxed:
		total_time = round(total_time * 1.7)


func apply_laws() -> void:
	speed_mult = 1.0
	slippery = false
	mirror = false
	river_push = Vector2.ZERO
	boat_speed_mult = 1.0
	capacity = CAPACITY_BASE
	water_solid = false
	fruit_mode = "static"
	wind = Vector2.ZERO
	night = false
	rain = false
	leaves = false
	var pause_mult := 1.0
	for l in laws:
		match l["id"]:
			"eau_monte":
				river_push = Vector2(0, -150)
			"eau_solide":
				water_solid = true
			"bateau_fou":
				boat_speed_mult = 2.2
				pause_mult *= 0.6
			"fruits_timides":
				fruit_mode = "flee"
			"fruits_aimants":
				fruit_mode = "chase"
			"fruits_vagabonds":
				fruit_mode = "wander"
			"pieds_plume":
				speed_mult = 1.7
				slippery = true
			"pieds_plomb":
				speed_mult = 0.65
				pause_mult *= 1.7
			"grand_sac":
				speed_mult = 0.8
				capacity = 5
			"miroir":
				mirror = true
			"vent_est":
				wind = Vector2(60, 0)
				leaves = true
			"nuit":
				night = true
			"pluie":
				rain = true
				slippery = true
	var dd := difficulty(level)
	boat_speed_mult *= 1.0 - 0.25 * dd
	pause_mult *= 1.0 + 0.6 * dd
	if relaxed:
		pause_mult *= 1.5
	boat_pause = BOAT_PAUSE * pause_mult


func map_extra(lv: int) -> float:
	if lv >= IMPOSSIBLE_FROM:
		return 1500.0
	if lv < 12:
		return 0.0
	return minf(float(lv - 11) * 9.0, 1200.0)


func build_ext_decor() -> void:
	var i := decor.size() - 1
	while i >= 0:
		if decor[i].has("ext"):
			decor.remove_at(i)
		i -= 1
	i = flowers.size() - 1
	while i >= 0:
		if flowers[i].has("ext"):
			flowers.remove_at(i)
		i -= 1
	if extra <= 0.0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = level * 7919 + 3
	var y := TOP_BAR - extra + 30.0
	while y < TOP_BAR - 40.0:
		var kinds := ["tree", "bush", "rock"]
		decor.append({"kind": kinds[r.randi() % 3], "pos": Vector2(r.randf_range(24.0, 60.0), y + r.randf_range(0, 60)), "ext": true})
		decor.append({"kind": kinds[r.randi() % 3], "pos": Vector2(r.randf_range(660.0, 696.0), y + r.randf_range(0, 60)), "ext": true})
		y += r.randf_range(120.0, 210.0)
	var fk := ["flower_a", "flower_b", "flower_c"]
	for j in int(extra / 22.0):
		flowers.append({"kind": fk[r.randi() % 3], "pos": Vector2(r.randf_range(16.0, W - 16.0), r.randf_range(TOP_BAR - extra, TOP_BAR)), "ext": true})


func start_play() -> void:
	compute_day_params()
	reset_scene()
	extra = map_extra(level)
	top_y = TOP_BAR - extra
	cam_y = 0.0
	build_ext_decor()
	state = "play"
	dusk_amt = 0.0
	cam_zoom = 1.0
	time_left = total_time
	last_sec = int(ceil(total_time))
	build_traps()
	for sp in fake_spots:
		fruits.append({"pos": sp, "carried": false, "gold": false, "fake": true, "dir": Vector2.RIGHT, "dir_t": 1.0})
	var n := mini(goal + 2, 9)
	for i in n:
		spawn_fruit(i == 0 and level >= 2)


func spawn_fruit(gold: bool) -> void:
	var p := Vector2(randf_range(120.0, W - 120.0), randf_range(top_y + 50.0, RIVER_TOP - 50.0))
	for attempt in 30:
		var ok := true
		for tr in traps:
			if p.distance_to(tr["pos"]) < 100.0:
				ok = false
		for sp in fake_spots:
			if p.distance_to(sp) < 125.0:
				ok = false
		if ok:
			break
		p = Vector2(randf_range(120.0, W - 120.0), randf_range(top_y + 50.0, RIVER_TOP - 50.0))
	fruits.append({
		"pos": p,
		"carried": false,
		"gold": gold,
		"fake": false,
		"dir": Vector2.RIGHT.rotated(randf() * TAU),
		"dir_t": randf_range(0.5, 2.0),
	})


func lose(reason: String) -> void:
	state = "lose"
	lose_reason = reason
	fail_count += 1
	deaths_total += 1
	sync_dirty = true
	ui_lock = 0.6
	snd("lose")
	lose_heart()


func win_game(skipped: bool = false) -> void:
	state = "dusk"
	dusk_t = 0.0
	fired = {}
	fail_count = 0
	ui_lock = 0.5
	has_target = false
	moving = false
	var ratio := clampf(time_left / total_time, 0.0, 1.0)
	last_stars = 3 if ratio >= 0.4 else (2 if ratio >= 0.18 else 1)
	last_score = goal * 100 + int(time_left) * 10 + last_stars * 250
	if skipped:
		last_stars = 1
		last_score = 0
	new_record = last_score > int(level_score[level])
	if new_record:
		level_score[level] = last_score
	if last_stars > int(level_stars[level]):
		level_stars[level] = last_stars
	if level < MAX_LEVEL:
		best_day = maxi(best_day, level + 1)
		cur_level = level + 1
	else:
		cur_level = level
	wins_total += 1
	save_game()
	sync_stats(false)
	snd("win")
	sfx.set_music_db(-24.0, 3.0)


func start_dying(reason: String = "noyade") -> void:
	dead_reason = reason
	state = "dying"
	die_t = 0.0
	vel = Vector2.ZERO
	has_target = false
	moving = false
	shake = 1.0
	if reason != "noyade":
		match reason:
			"ours":
				snd("board", 2.0, 0.6)
				snd("lose", -6.0)
				spawn_particles(pos, Color(0.75, 0.75, 0.8), 18, 220.0, 0.7, 4.0, 500.0, 120.0)
			"fosse":
				snd("rumble", -2.0)
				spawn_particles(pos, Color(0.45, 0.3, 0.15), 26, 160.0, 0.9, 5.0, 500.0, 60.0)
			"pierre":
				snd("board", 3.0, 0.5)
				spawn_particles(pos, Color(0.7, 0.65, 0.55), 22, 240.0, 0.8, 5.0, 600.0, 100.0)
			"foudre":
				snd("sting", -2.0)
				flash = 1.0
				spawn_particles(pos, Color(0.85, 0.92, 1.0), 26, 260.0, 0.7, 4.0, 200.0, 80.0)
			"pics":
				snd("board", 2.0, 0.7)
				snd("lose", -6.0)
				spawn_particles(pos, Color(0.9, 0.2, 0.2), 22, 240.0, 0.7, 4.0, 500.0, 110.0)
			"rocher":
				snd("rumble", 0.0)
				spawn_particles(pos, Color(0.7, 0.65, 0.55), 26, 260.0, 0.8, 5.0, 600.0, 100.0)
			"faux":
				snd("rumble", 0.0)
				flash = 0.7
				spawn_particles(pos, Color(1.0, 0.55, 0.2), 34, 300.0, 0.8, 5.5, 300.0, 120.0)
		return
	snd("splash")
	for i in 3:
		spawn_ring(pos + Vector2(0, 6), Color(1, 1, 1), 10.0 + i * 8.0, 70.0 + i * 30.0, 0.7 + i * 0.15)
	spawn_particles(pos, Color(0.78, 0.92, 1.0), 18, 200.0, 0.8, 4.5, 700.0, 190.0)


# --- Navigation ---
func go_menu() -> void:
	state = "menu"
	laws = []
	apply_laws()
	reset_scene()
	pos = Vector2(470, 1150)
	facing = -1.0
	dusk_amt = 0.0
	cam_zoom = 1.0
	ui_lock = 0.3
	sfx.set_music_db(-10.0, 0.6)


func start_cine() -> void:
	state = "cine"
	cine_t = 0.0
	cine_phase = -1
	cine_scene = 0
	fired = {}
	reset_scene()
	laws = []
	apply_laws()
	ui_lock = 0.6


func end_cine() -> void:
	apply_laws()
	go_menu()


func begin_level(lv: int) -> void:
	level = clampi(lv, 1, best_day)
	cur_level = level
	save_game()
	new_day()


func next_after_win() -> void:
	# Pub obligatoire après chaque 3e niveau (sauf version sans pub).
	if not premium and level % AD_EVERY == 0 and level < MAX_LEVEL:
		start_ad("inter", 1, AD_INTER, false)
		return
	proceed_after_win()


func proceed_after_win() -> void:
	if level >= MAX_LEVEL:
		go_menu()
		return
	level += 1
	new_day()
	state = "dawn"
	dawn_t = 0.0
	fired = {}
	ui_lock = 0.4


func finish_dawn() -> void:
	state = "intro"
	dusk_amt = 0.0
	cam_zoom = 1.0
	ui_lock = 0.2
	sfx.set_music_db(-10.0, 1.0)


func enter_pause() -> void:
	if state == "play":
		state = "pause"


func back_action() -> void:
	match state:
		"play":
			enter_pause()
		"pause":
			state = "play"
		"levels", "settings":
			state = "menu"
		"confirm":
			state = "settings"
		"intro", "lose", "win", "nohearts":
			go_menu()
		"shop":
			state = shop_return
		"ad":
			if ad_cancelable and ad_left > 0.0:
				ad_cancel()
		"menu":
			get_tree().quit()
		"cine":
			end_cine()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_action()


# --- Effets visuels ---
func trim_fx() -> void:
	while particles.size() > 320:
		particles.pop_front()


func spawn_particles(p: Vector2, col: Color, n: int, speed: float, life: float, size: float = 4.0, grav: float = 300.0, up: float = 0.0) -> void:
	for i in n:
		var a := randf() * TAU
		var s := randf_range(0.3, 1.0) * speed
		particles.append({"p": p, "v": Vector2(cos(a), sin(a)) * s + Vector2(0, -up),
				"life": life * randf_range(0.7, 1.0), "max": life, "c": col, "s": size, "g": grav,
				"k": "dot", "r1": 0.0})
	trim_fx()


func spawn_ring(p: Vector2, col: Color, r0: float, r1: float, life: float) -> void:
	particles.append({"p": p, "v": Vector2.ZERO, "life": life, "max": life, "c": col, "s": r0, "g": 0.0,
			"k": "ring", "r1": r1})
	trim_fx()


func add_floater(text: String, p: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": p, "life": 1.1, "max": 1.1, "c": col})
	while floaters.size() > 12:
		floaters.pop_front()


func update_fx(delta: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var q = particles[i]
		q["life"] -= delta
		if q["life"] <= 0.0:
			particles.remove_at(i)
		else:
			q["v"] += Vector2(0, q["g"]) * delta
			q["p"] += q["v"] * delta
		i -= 1
	i = floaters.size() - 1
	while i >= 0:
		var q = floaters[i]
		q["life"] -= delta
		if q["life"] <= 0.0:
			floaters.remove_at(i)
		else:
			q["pos"] += Vector2(0, -46.0) * delta
		i -= 1
	shake = maxf(0.0, shake - delta * 2.2)
	flash = maxf(0.0, flash - delta * 2.5)


# --- Boutons de l'interface ---
func btn(id: String, rect: Rect2, label: String, col: Color, size: int = 32, sub: String = "") -> Dictionary:
	return {"id": id, "rect": rect, "label": label, "color": col, "size": size, "sub": sub}


func ui_buttons() -> Array:
	var b: Array = []
	match state:
		"menu":
			b.append(btn("play", Rect2(100, 650, 520, 118), T("JOUER"), Color("43a047"), 46, T("Jour %d") % cur_level))
			b.append(btn("levels", Rect2(100, 796, 520, 96), T("NIVEAUX"), Color("1e88e5"), 38))
			b.append(btn("intro", Rect2(100, 918, 250, 84), T("INTRO"), Color("8e24aa"), 30))
			b.append(btn("settings", Rect2(370, 918, 250, 84), T("PARAMÈTRES"), Color("fb8c00"), 25))
		"settings":
			b.append(btn("sound", Rect2(110, 400, 500, 96), T("SON : NON") if muted else T("SON : OUI"), Color("fb8c00"), 34))
			b.append(btn("lang", Rect2(110, 516, 500, 96), T("LANGUE : %s") % Lang.name_of(Lang.code), Color("1e88e5"), 34))
			b.append(btn("relaxed", Rect2(110, 632, 500, 96), T("MODE DÉTENDU : OUI") if relaxed else T("MODE DÉTENDU : NON"), Color("43a047"), 30))
			b.append(btn("shop", Rect2(110, 760, 500, 84), T("VERSION SANS PUB : ACTIVÉE") if premium else T("VERSION SANS PUB"), Color("f9a825"), 28))
			b.append(btn("reset", Rect2(110, 858, 500, 84), T("EFFACER MA PROGRESSION"), Color("c62828"), 28))
			b.append(btn("stats", Rect2(110, 956, 500, 84), T("STATS EN LIGNE : OUI") if share_stats else T("STATS EN LIGNE : NON"), Color("00897b"), 28))
			b.append(btn("back", Rect2(110, 1062, 500, 84), T("RETOUR"), Color("8e24aa"), 36))
		"levels":
			var first := lvl_page * LEVELS_PER_PAGE + 1
			for k in LEVELS_PER_PAGE:
				var n := first + k
				if n > MAX_LEVEL:
					break
				var cx := k % 3
				var cy := floori(k / 3.0)
				var bb := btn("lvl_%d" % n, Rect2(50.0 + cx * 215.0, 250.0 + cy * 172.0, 190, 150), str(n), Color("43a047"), 54)
				bb["cell"] = n
				b.append(bb)
			b.append(btn("cur", Rect2(230, 960, 260, 72), T("MON NIVEAU"), Color("fb8c00"), 26))
			b.append(btn("prev", Rect2(50, 960, 150, 72), "<", Color("1e88e5"), 44))
			b.append(btn("next", Rect2(520, 960, 150, 72), ">", Color("1e88e5"), 44))
			b.append(btn("back", Rect2(190, 1090, 340, 90), T("RETOUR"), Color("8e24aa"), 36))
		"confirm":
			b.append(btn("reset_yes", Rect2(110, 700, 240, 90), T("OUI"), Color("e53935"), 38))
			b.append(btn("reset_no", Rect2(370, 700, 240, 90), T("NON"), Color("43a047"), 38))
		"pause":
			b.append(btn("resume", Rect2(110, 520, 500, 100), T("REPRENDRE"), Color("43a047"), 40))
			b.append(btn("retry", Rect2(110, 650, 500, 90), T("RECOMMENCER"), Color("fb8c00"), 34))
			b.append(btn("tomenu", Rect2(110, 770, 500, 90), T("MENU"), Color("8e24aa"), 34))
			b.append({"id": "mute", "rect": MUTE_RECT, "icon": "mute"})
		"intro", "lose", "win":
			b.append(btn("home", HOME_RECT, T("MENU"), Color(0.2, 0.3, 0.42), 24))
			b.append({"id": "mute", "rect": MUTE_RECT, "icon": "mute"})
			if state == "lose":
				b.append_array(lose_buttons())
		"nohearts":
			b.append(btn("home", HOME_RECT, T("MENU"), Color(0.2, 0.3, 0.42), 24))
			b.append(btn("shop", Rect2(60, 780, 600, 96), T("SANS PUB + CŒURS ILLIMITÉS : %s") % price_text(), Color("f9a825"), 22))
		"shop":
			if not premium:
				b.append(btn("buy", Rect2(110, 780, 500, 110), T("ACHETER : %s") % price_text(), Color("43a047"), 30))
			b.append(btn("shop_back", Rect2(110, 1000, 500, 90), T("RETOUR"), Color("8e24aa"), 36))
		"ad":
			if ad_left <= 0.0:
				var lab := T("CONTINUER") if ad_idx >= ad_n else T("PUB SUIVANTE")
				b.append(btn("ad_done", Rect2(110, 1010, 500, 100), lab, Color("43a047"), 38))
			elif ad_cancelable:
				b.append(btn("ad_cancel", Rect2(210, 1110, 300, 70), T("ANNULER"), Color(0.26, 0.3, 0.36), 26))
		"play":
			b.append({"id": "pause", "rect": PAUSE_RECT, "icon": "pause"})
			b.append({"id": "mute", "rect": MUTE_RECT, "icon": "mute"})
	return b


func button_at(p: Vector2) -> String:
	var arr := ui_buttons()
	for i in range(arr.size() - 1, -1, -1):
		var r: Rect2 = arr[i]["rect"]
		if r.has_point(p):
			return arr[i]["id"]
	return ""


func activate(id: String) -> void:
	if id == "mute":
		toggle_mute()
		return
	if ui_lock > 0.0:
		return
	snd("tap", -4.0)
	if id.begins_with("lvl_"):
		var n := int(id.substr(4))
		if n <= best_day:
			begin_level(n)
		return
	match id:
		"play":
			begin_level(cur_level)
		"levels":
			lvl_page = clampi(floori((cur_level - 1) / float(LEVELS_PER_PAGE)), 0, MAX_PAGES - 1)
			state = "levels"
		"intro":
			start_cine()
		"sound":
			toggle_mute()
		"reset":
			state = "confirm"
		"reset_yes":
			reset_progress()
			state = "settings"
		"reset_no":
			state = "settings"
		"settings":
			state = "settings"
		"lang":
			Lang.code = Lang.next_code()
			save_game()
		"relaxed":
			relaxed = not relaxed
			save_game()
		"stats":
			share_stats = not share_stats
			save_game()
			if share_stats:
				sync_stats(true)
		"cur":
			lvl_page = clampi(floori((cur_level - 1) / float(LEVELS_PER_PAGE)), 0, MAX_PAGES - 1)
		"prev":
			lvl_page = maxi(0, lvl_page - 1)
		"next":
			lvl_page = mini(MAX_PAGES - 1, lvl_page + 1)
		"back":
			state = "menu"
		"resume":
			state = "play"
		"retry":
			try_start()
		"comeback":
			if premium:
				do_comeback()
			else:
				start_ad("comeback", 1, AD_COMEBACK, true)
		"skip":
			start_ad("skip", 2, AD_SKIP, true)
		"shop":
			shop_return = state
			state = "shop"
		"shop_back":
			state = shop_return
		"buy":
			buy_premium()
		"ad_done":
			ad_finish()
		"ad_cancel":
			ad_cancel()
		"tomenu", "home":
			go_menu()
		"pause":
			enter_pause()


func handle_tap() -> void:
	if ui_lock > 0.0:
		return
	match state:
		"intro":
			snd("tap", -4.0)
			try_start()
		"lose":
			snd("tap", -4.0)
			if can_play():
				state = "intro"
			else:
				state = "nohearts"
			ui_lock = 0.4
		"win":
			snd("tap", -4.0)
			next_after_win()
		"cine":
			end_cine()
		"dawn":
			if dawn_t > 0.8:
				finish_dawn()
		"dusk":
			if dusk_t > 2.0:
				dusk_t = DUSK_LEN


# --- Entrées (le toucher est converti en clic de souris par Godot) ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_action()
		return
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var p := get_global_mouse_position()
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			press_id = button_at(p)
			if press_id == "":
				if state == "play":
					set_target(p)
				else:
					handle_tap()
		else:
			if press_id != "" and button_at(p) == press_id:
				activate(press_id)
			press_id = ""
	elif mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if press_id == "" and state == "play":
			set_target(p)


func set_target(p: Vector2) -> void:
	if riding:
		return
	var q := p
	if mirror:
		q = Vector2(pos.x - (p.x - pos.x), p.y)
	q.y += cam_y
	target = Vector2(clampf(q.x, 30.0, W - 30.0), clampf(q.y, top_y, H - 20.0))
	has_target = true


func _process(delta: float) -> void:
	t += delta
	stats_tick(delta)
	ui_lock = maxf(0.0, ui_lock - delta)
	tick_hearts()
	match state:
		"ad":
			ad_left = maxf(0.0, ad_left - delta)
		"nohearts":
			if can_play():
				state = "intro"
				ui_lock = 0.3
		"cine":
			cam_y = 0.0
			cine_update(delta)
		"menu", "levels", "confirm", "settings":
			cam_y = 0.0
			extra = 0.0
			top_y = TOP_BAR
			menu_update(delta)
		"play":
			update_play(delta)
		"dying":
			die_t += delta
			if die_t >= DIE_TIME:
				lose(dead_reason)
		"dusk":
			dusk_update(delta)
		"dawn":
			dawn_update(delta)
		"win":
			win_update(delta)
	update_fx(delta)
	if light_layer != null:
		light_layer.scale = Vector2(cam_zoom, cam_zoom)
		light_layer.position = cam_center * (1.0 - cam_zoom) + cam_zoom * Vector2(0, -cam_y)
		light_layer.queue_redraw()
	queue_redraw()


func win_update(delta: float) -> void:
	win_t += delta
	conf_cd -= delta
	if conf_cd <= 0.0:
		conf_cd = 0.05
		var c: Color = CONFETTI[randi() % CONFETTI.size()]
		particles.append({"p": Vector2(randf_range(0.0, W), -10.0), "v": Vector2(randf_range(-40.0, 40.0), randf_range(80.0, 160.0)),
				"life": 4.5, "max": 4.5, "c": c, "s": 6.0, "g": 30.0, "k": "conf", "r1": 0.0})
		trim_fx()
	for i in 3:
		if i < last_stars and win_t >= 0.3 + i * 0.35:
			fire("star%d" % i, "star", 0.0)


func menu_update(delta: float) -> void:
	# Le bateau se balade tout seul derrière le menu.
	boat_y = lerpf(BOAT_N_Y, BOAT_S_Y, 0.5 + 0.5 * sin(t * 0.45))
	ring_cd -= delta
	if ring_cd <= 0.0:
		ring_cd = 0.4
		spawn_ring(Vector2(BOAT_X, boat_y + 40.0), Color(1, 1, 1), 8.0, 36.0, 0.9)


func dusk_update(delta: float) -> void:
	dusk_t += delta
	var a := clampf(dusk_t / DUSK_LEN, 0.0, 1.0)
	dusk_amt = smoothstep(0.0, 1.0, a)
	cam_zoom = lerpf(1.0, 1.14, a)
	cam_center = Vector2(360, 1120)
	hero_cheer = dusk_t < 1.6
	if dusk_t > 0.4:
		fire("sting", "sting", -4.0)
	if dusk_t > 2.6:
		fire("owl", "owl", -6.0)
	if dusk_t > 3.8:
		fire("crickets", "crickets", -8.0)
	if dusk_t >= DUSK_LEN:
		state = "win"
		win_t = 0.0
		fired = {}
		ui_lock = 0.5
		hero_cheer = false


func dawn_update(delta: float) -> void:
	dawn_t += delta
	var a := clampf(dawn_t / DAWN_LEN, 0.0, 1.0)
	dusk_amt = 1.0 - smoothstep(0.15, 1.0, a)
	cam_zoom = lerpf(1.14, 1.0, smoothstep(0.0, 1.0, a))
	cam_center = Vector2(360, 1120)
	if dawn_t > 0.2 and not fired.has("dawn"):
		fired["dawn"] = true
		snd("dawn", -2.0)
		sfx.set_music_db(-10.0, 1.5)
	if dawn_t >= DAWN_LEN:
		finish_dawn()


# --- Cinématique d'ouverture ---
func cine_update(delta: float) -> void:
	cine_t += delta
	var ct := cine_t
	water_solid = false
	river_push = Vector2.ZERO
	rain = false
	leaves = false
	night = false
	wind = Vector2.ZERO
	dusk_amt = 0.0
	hero_cheer = false
	riding = false
	moving = false
	cam_zoom = 1.0
	cam_center = Vector2(360, 1100)
	fruits = []
	boat_y = BOAT_S_Y
	if ct < 5.6:
		cine_scene = 0
		cam_zoom = lerpf(1.0, 1.22, ct / 5.6)
		cam_center = Vector2(360, 1130)
		pos = Vector2(450, 1150)
		facing = -1.0
	elif ct < 11.0:
		cine_scene = 1
		var u := ct - 5.6
		fire("rumble", "rumble", -2.0)
		var ph := int(u / 1.1) % 5
		if ph != cine_phase:
			cine_phase = ph
			shake = 0.7
			if ph > 0:
				snd("sting", -10.0)
		match ph:
			0:
				water_solid = true
			1:
				river_push = Vector2(0, -150)
			2:
				rain = true
			3:
				leaves = true
				wind = Vector2(60, 0)
			4:
				night = true
		cam_zoom = 1.0 + 0.03 * sin(u * 2.0)
		cam_center = Vector2(360, 700)
		pos = Vector2(360, 860)
		facing = 1.0
		fruits = cine_fruits(ct, true)
	elif ct < 16.4:
		cine_scene = 2
		var u2 := ct - 11.0
		cam_zoom = lerpf(1.0, 1.26, u2 / 5.4)
		cam_center = Vector2(360, 620)
		pos = Vector2(360, 840)
		facing = 1.0
		fruits = cine_fruits(ct, false)
	else:
		cine_scene = 3
		var u3 := ct - 16.4
		cam_zoom = lerpf(1.0, 1.14, clampf(u3 / 4.6, 0.0, 1.0))
		cam_center = Vector2(360, 640)
		fruits = cine_fruits(ct, false)
		facing = 1.0
		if u3 < 1.3:
			pos = Vector2(360, lerpf(840.0, 795.0, u3 / 1.3))
			moving = true
		elif u3 < 4.0:
			riding = true
			fire("board", "board")
			boat_y = lerpf(BOAT_S_Y, BOAT_N_Y, clampf((u3 - 1.5) / 2.3, 0.0, 1.0))
			pos = Vector2(BOAT_X, boat_y + 8.0)
			ring_cd -= delta
			if ring_cd <= 0.0 and u3 > 1.5:
				ring_cd = 0.2
				spawn_ring(Vector2(BOAT_X, boat_y + 48.0), Color(1, 1, 1), 8.0, 38.0, 0.8)
		else:
			boat_y = BOAT_N_Y
			pos = Vector2(BOAT_X, RIVER_TOP - 40.0)
			hero_cheer = true
			fire("bell", "bell", -4.0)
	if ct >= CINE_LEN:
		end_cine()


func cine_fruits(ct: float, jitter: bool) -> Array:
	var base := [Vector2(150, 300), Vector2(260, 390), Vector2(370, 270), Vector2(480, 370),
			Vector2(590, 300), Vector2(210, 450), Vector2(520, 455)]
	var arr: Array = []
	for i in base.size():
		var p: Vector2 = base[i]
		if jitter:
			p += Vector2(sin(ct * 5.0 + i) * 16.0, cos(ct * 6.0 + i * 2.0) * 9.0)
		arr.append({"pos": p, "carried": false, "gold": i == 2})
	return arr


# --- Partie ---
func update_play(delta: float) -> void:
	var cy_t := clampf(pos.y - 560.0, -extra, 0.0)
	cam_y = cy_t if extra <= 0.0 else lerpf(cam_y, cy_t, 1.0 - exp(-7.0 * delta))
	hist_t -= delta
	if hist_t <= 0.0:
		hist_t = 0.5
		record_history()
	time_left -= delta
	board_cd = maxf(0.0, board_cd - delta)
	if time_left <= 0.0:
		time_left = 0.0
		lose("temps")
		return
	var secs := int(ceil(time_left))
	if secs != last_sec:
		last_sec = secs
		if secs <= 10:
			snd("tick", -6.0)

	update_boat(delta)

	if riding:
		pos = Vector2(BOAT_X, boat_y + 8.0)
		vel = Vector2.ZERO
		has_target = false
		moving = false
	else:
		move_player(delta)
		if state != "play":
			return

	update_fruits(delta)
	if state != "play":
		return
	update_strikes(delta)
	if state != "play":
		return
	update_spikes(delta)
	if state != "play":
		return
	update_boulders(delta)
	if state != "play":
		return
	check_deposit()


# Le bateau fait des allers-retours tout seul et s'arrête à chaque quai.
func update_boat(delta: float) -> void:
	if water_solid:
		return
	var dest_y := BOAT_N_Y if boat_to_north else BOAT_S_Y
	if boat_wait > 0.0:
		boat_wait -= delta
		if not riding and board_cd <= 0.0 and pos.distance_to(Vector2(BOAT_X, boat_y)) < BOARD_RADIUS:
			riding = true
			boat_wait = 0.0
			has_target = false
			snd("board")
		return

	var dir := -1.0 if boat_to_north else 1.0
	var speed := clampf(BOAT_SPEED * boat_speed_mult + dir * river_push.y * 0.3, 30.0, 300.0)
	boat_y = move_toward(boat_y, dest_y, speed * delta)
	ring_cd -= delta
	if ring_cd <= 0.0:
		ring_cd = 0.22
		spawn_ring(Vector2(BOAT_X, boat_y - dir * 48.0), Color(1, 1, 1), 8.0, 38.0, 0.8)
	if is_equal_approx(boat_y, dest_y):
		var arrived_north := boat_to_north
		boat_to_north = not boat_to_north
		boat_wait = boat_pause
		snd("bell", -8.0)
		if riding:
			riding = false
			board_cd = boat_pause + 0.4
			has_target = false
			var bank_y := RIVER_BOT + 36.0
			if arrived_north:
				bank_y = RIVER_TOP - 36.0
			pos = Vector2(BOAT_X, bank_y)


func move_player(delta: float) -> void:
	var desired := Vector2.ZERO
	if has_target:
		var d := target - pos
		if d.length() < 8.0:
			has_target = false
		else:
			var spd := BASE_SPEED * speed_mult
			if slippery:
				# Sur la glisse, le personnage ralentit en approchant de sa cible.
				spd *= clampf(d.length() / 140.0, 0.2, 1.0)
			desired = d.normalized() * spd

	if slippery:
		vel = vel.lerp(desired, 1.0 - exp(-delta * 4.0))
	else:
		vel = desired
	moving = vel.length() > 20.0
	if absf(vel.x) > 20.0:
		facing = signf(vel.x)

	pos += (vel + wind) * delta
	pos.x = clampf(pos.x, 30.0, W - 30.0)
	pos.y = clampf(pos.y, top_y, H - 20.0)

	# Pièges cachés
	for i in traps.size():
		var tr: Dictionary = traps[i]
		if tr["k"] == "spike":
			continue
		if pos.distance_to(tr["pos"]) < float(tr["r"]):
			shown[i] = true
			hit_trap = i
			start_dying("ours" if tr["k"] == "bear" else "fosse")
			return
	# Nager = mourir (sauf si l'eau est gelée)
	if not water_solid and pos.y > RIVER_TOP + 14.0 and pos.y < RIVER_BOT - 14.0:
		start_dying()


func update_fruits(delta: float) -> void:
	for f in fruits:
		if f["carried"]:
			continue
		if f.get("fake", false):
			# Faux fruit : identique aux autres, mais il est piégé.
			if not riding and pos.distance_to(f["pos"]) < 46.0:
				start_dying("faux")
				return
			continue
		var fp: Vector2 = f["pos"]
		var old_y := fp.y
		var to_p: Vector2 = pos - fp
		var dist := to_p.length()
		match fruit_mode:
			"flee":
				if dist < 220.0 and dist > 1.0:
					fp -= to_p.normalized() * 150.0 * delta
			"chase":
				if dist < 380.0 and dist > 1.0:
					fp += to_p.normalized() * 85.0 * delta
			"wander":
				f["dir_t"] -= delta
				if f["dir_t"] <= 0.0:
					f["dir_t"] = randf_range(0.8, 2.2)
					f["dir"] = Vector2.RIGHT.rotated(randf() * TAU)
				var wd: Vector2 = f["dir"]
				fp += wd * 55.0 * delta
		fp += wind * delta
		fp.x = clampf(fp.x, 90.0, W - 90.0)
		fp.y = clampf(fp.y, top_y + 20.0, H - 30.0)
		# Les fruits ne tombent jamais dans la rivière.
		if fp.y > RIVER_TOP - 10.0 and fp.y < RIVER_BOT + 10.0:
			fp.y = old_y
		f["pos"] = fp
		if dist < 46.0 and carried < capacity:
			f["carried"] = true
			carried += 1
			pickup_fx(fp, f["gold"])


func pickup_fx(p: Vector2, gold: bool) -> void:
	if gold:
		time_left += GOLD_BONUS
		snd("gold")
		spawn_particles(p, Color("ffe082"), 20, 170.0, 0.9, 4.5, 200.0, 40.0)
		add_floater("+%d s" % int(GOLD_BONUS), p + Vector2(0, -40), Color("ffe082"))
	else:
		snd("pickup")
		spawn_particles(p, Color("ff8a80"), 9, 120.0, 0.55, 3.5, 260.0, 50.0)
		add_floater("+1", p + Vector2(0, -40), Color.WHITE)


func check_deposit() -> void:
	if riding or carried <= 0:
		return
	if pos.distance_to(HUT_POS) < 95.0:
		var n := carried
		deposited += n
		carried = 0
		fruits = fruits.filter(func(f): return not f["carried"])
		var want := mini(goal - deposited + 2, 9)
		var real := 0
		for f in fruits:
			if not f.get("fake", false):
				real += 1
		while real < want:
			spawn_fruit(false)
			real += 1
		snd("deposit")
		spawn_particles(HUT_POS + Vector2(0, -50), Color("ffd166"), 16, 150.0, 0.8, 4.0, 220.0, 60.0)
		add_floater("+%d" % n, HUT_POS + Vector2(0, -120), Color("ffd166"))
		if deposited >= goal:
			win_game()


# --- Guide (affiché seulement après 5 défaites) ---
func nearest_free_fruit() -> Variant:
	var best = null
	var best_d := 1.0e9
	for f in fruits:
		if f["carried"] or f.get("fake", false):
			continue
		var d: float = pos.distance_to(f["pos"])
		if d < best_d:
			best_d = d
			best = f["pos"]
	return best


func guide_target() -> Variant:
	var base = base_target()
	if base == null or riding:
		return base
	for b in boulders:
		var dyb: float = pos.y - float(b["y"])
		if absf(dyb) < 95.0:
			if not b.has("sg"):
				var sg := signf(dyb)
				if absf(dyb) < 8.0:
					sg = -1.0 if pos.y < RIVER_TOP else 1.0
				var ty: float = float(b["y"]) + sg * 125.0
				if (pos.y < RIVER_TOP and ty > RIVER_TOP - 50.0) or (pos.y >= RIVER_TOP and ty < RIVER_BOT + 50.0):
					sg = -sg
				b["sg"] = sg
			var ey: float = float(b["y"]) + float(b["sg"]) * 125.0
			if pos.y < RIVER_TOP:
				ey = clampf(ey, top_y + 10.0, RIVER_TOP - 50.0)
			else:
				ey = clampf(ey, RIVER_BOT + 50.0, H - 30.0)
			return steer(Vector2(pos.x, ey))
	return steer(base)


func base_target() -> Variant:
	if riding:
		var bank_y := RIVER_BOT + 40.0
		if boat_to_north:
			bank_y = RIVER_TOP - 40.0
		return Vector2(BOAT_X, bank_y)
	var dest = null
	var free = nearest_free_fruit()
	if carried > 0 and (carried >= capacity or free == null):
		dest = HUT_POS
	elif free != null:
		dest = free
	else:
		return null
	if water_solid:
		return dest
	var player_north: bool = pos.y < RIVER_TOP
	var dest_north: bool = dest.y < RIVER_TOP
	if player_north != dest_north:
		if player_north:
			return Vector2(BOAT_X, RIVER_TOP - 30.0)
		return Vector2(BOAT_X, RIVER_BOT + 30.0)
	return dest


# --- Dessin : utilitaires ---
func progress_view() -> int:
	match state:
		"menu", "levels", "confirm", "settings":
			return best_day
		"cine":
			return 1
	return level


func villager_count() -> int:
	match state:
		"cine":
			return 4
		"menu", "levels", "confirm", "settings":
			return clampi(best_day - 1, 0, 6)
		"dusk", "win":
			return clampi(level, 0, 6)
	return clampi(level - 1, 0, 6)


func vil_spot(i: int) -> Vector2:
	if state == "cine" and cine_scene >= 1:
		return CINE_VIL[i]
	return VIL_SPOTS[i]


func night_amount() -> float:
	return maxf(1.0 if night else 0.0, dusk_amt)


func firefly_pos(i: int) -> Vector2:
	return Vector2(fposmod(i * 173.0 + sin(t * 0.4 + i) * 60.0, W),
			200.0 + fposmod(i * 211.0, 1000.0) + cos(t * 0.5 + i * 1.7) * 40.0)


func set_xf(offset: Vector2, scl: Vector2) -> void:
	draw_set_transform(cam_zoom * (offset + Vector2(0, -cam_y) - cam_center) + cam_center + cur_shake, 0.0, scl * cam_zoom)


func panel(rect: Rect2, col: Color, radius: int = 16) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)


func panel2(rect: Rect2, col: Color, radius: int, border: Color, bw: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	draw_style_box(sb, rect)


func center_text(font: Font, text: String, y: float, size: int, color: Color = Color.WHITE) -> void:
	var width := 620.0
	draw_multiline_string(font, Vector2((W - width) / 2.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, color)


func outline_text(font: Font, text: String, y: float, size: int, color: Color, outline: int = 12, x: float = 0.0, width: float = W) -> void:
	draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, outline, Color(0.08, 0.14, 0.1, 0.95))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


# Texte dont chaque lettre ondule (logo).
func wave_text(font: Font, text: String, cx: float, y: float, size: int, color: Color, amp: float) -> void:
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := cx - total / 2.0
	for i in text.length():
		var ch := text.substr(i, 1)
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var dy := sin(t * 2.6 + i * 0.55) * amp
		draw_string_outline(font, Vector2(x, y + dy + 5.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 16, Color(0, 0, 0, 0.35))
		draw_string_outline(font, Vector2(x, y + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(0.1, 0.16, 0.1, 0.96))
		draw_string(font, Vector2(x, y + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += cw


# --- Dessin : monde ---
func _draw() -> void:
	var font := ThemeDB.fallback_font
	cur_shake = Vector2.ZERO
	if shake > 0.0:
		cur_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 12.0
	set_xf(Vector2.ZERO, Vector2.ONE)
	draw_world(font)
	draw_strikes()
	draw_boulders()
	draw_fx()
	var cy_keep := cam_y
	cam_y = 0.0
	set_xf(Vector2.ZERO, Vector2.ONE)
	draw_ambient()
	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, clampf(flash, 0.0, 1.0) * 0.7))
	cam_y = cy_keep
	set_xf(Vector2.ZERO, Vector2.ONE)
	if solution_on() and state == "play":
		draw_guide()
	draw_floaters(font)
	draw_set_transform(Vector2.ZERO)
	if state == "cine":
		draw_cine_overlay(font)
		return
	if state in ["intro", "play", "pause", "dying", "dusk", "win", "lose"]:
		draw_hud(font)
	if state in ["menu", "levels", "confirm", "settings", "intro", "pause", "win", "lose", "dusk", "dawn", "ad", "nohearts", "shop"]:
		draw_overlay(font)
	draw_ui_buttons(font)


func draw_world(font: Font) -> void:
	# Herbe
	draw_texture_rect(tex["grass"], Rect2(0, top_y - 400.0, W, RIVER_TOP - top_y + 400.0), true)
	draw_texture_rect(tex["grass"], Rect2(0, RIVER_BOT, W, H - RIVER_BOT), true)
	for fl in flowers:
		draw_texture(tex[fl["kind"]], fl["pos"] - Vector2(14, 24))

	# Rivière (ou glace)
	var wt: Texture2D = tex["ice"] if water_solid else tex["water"]
	var off := fmod(t * 18.0, 256.0)
	for i in range(-1, 4):
		draw_texture(wt, Vector2(i * 256.0 + off, RIVER_TOP))
	if river_push.y < 0.0 and not water_solid:
		for i in 6:
			var cx := 70.0 + i * 116.0
			var cy := RIVER_BOT - 24.0 - fmod(t * 60.0 + i * 41.0, RIVER_BOT - RIVER_TOP - 40.0)
			draw_polyline(PackedVector2Array([Vector2(cx - 14, cy + 9), Vector2(cx, cy - 6), Vector2(cx + 14, cy + 9)]),
				Color(1, 1, 1, 0.4), 4.0)
	var na := night_amount()
	if na > 0.5:
		# Reflets de la lune sur l'eau
		for i in 14:
			var gy := RIVER_TOP + 18.0 + i * ((RIVER_BOT - RIVER_TOP - 36.0) / 14.0)
			var gx := 470.0 + sin(t * 1.3 + i * 0.9) * 50.0 - i * 4.0
			var gw := 38.0 - i * 1.6 + sin(t * 2.0 + i) * 6.0
			draw_line(Vector2(gx - gw, gy), Vector2(gx + gw, gy), Color(0.85, 0.92, 1.0, 0.32 * (na - 0.5) * 2.0), 3.0)
	for i in 3:
		draw_texture(tex["bank_n"], Vector2(i * 256.0, RIVER_TOP - 24.0))
		draw_texture(tex["bank_s"], Vector2(i * 256.0, RIVER_BOT - 24.0))
	draw_texture(tex["landing"], Vector2(BOAT_X - 75.0, RIVER_TOP - 34.0))
	draw_texture(tex["landing"], Vector2(BOAT_X - 75.0, RIVER_BOT - 26.0))

	draw_traps()

	# Bateau
	if not water_solid:
		var rock := sin(t * 2.0) * 1.5
		draw_texture(tex["boat"], Vector2(BOAT_X, boat_y + rock) - BOAT_ANCHOR)

	# Éléments triés par profondeur (y)
	var pv := progress_view()
	var sleeping := na > 0.7 and (state == "win" or (state == "dusk" and dusk_t > 3.0))
	var vil_cheer := (state == "dusk" and dusk_t < 1.6) or (state == "cine" and cine_scene == 1)
	var ents: Array = []
	for d in decor:
		ents.append({"y": d["pos"].y, "kind": d["kind"], "pos": d["pos"]})
	ents.append({"y": HUT_DRAW.y - 40.0, "kind": "hut", "pos": HUT_DRAW})
	if pv >= 4 and state != "cine":
		ents.append({"y": HUT2_DRAW.y - 30.0, "kind": "hut2", "pos": HUT2_DRAW})
	for i in villager_count():
		var sp := vil_spot(i)
		ents.append({"y": sp.y, "kind": "vil", "pos": sp, "i": i})
	for f in fruits:
		if not f["carried"]:
			ents.append({"y": f["pos"].y, "kind": "gold" if f["gold"] else "fruit", "pos": f["pos"]})
	ents.append({"y": pos.y, "kind": "player", "pos": pos})
	ents.sort_custom(func(a, b): return a["y"] < b["y"])
	for e in ents:
		match e["kind"]:
			"tree":
				draw_texture(tex["tree"], e["pos"] - TREE_ANCHOR)
			"bush":
				draw_texture(tex["bush"], e["pos"] - BUSH_ANCHOR)
			"rock":
				draw_texture(tex["rock"], e["pos"] - ROCK_ANCHOR)
			"hut":
				draw_texture(tex["hut"], e["pos"] - HUT_ANCHOR)
			"hut2":
				draw_texture(tex["hut2"], e["pos"] - HUT2_ANCHOR)
			"fruit":
				var bob := sin(t * 3.0 + e["pos"].x * 0.05) * 2.0
				draw_texture(tex["fruit"], e["pos"] - FRUIT_ANCHOR + Vector2(0, bob))
			"gold":
				var gb := sin(t * 3.0 + e["pos"].x * 0.05) * 3.0
				draw_texture(tex["gold"], e["pos"] - FRUIT_ANCHOR + Vector2(0, gb))
				for k in 3:
					var a := t * 3.0 + k * 2.1
					var sp2: Vector2 = e["pos"] + Vector2(cos(a) * 24.0, sin(a) * 12.0 - 14.0 + gb)
					draw_circle(sp2, 2.5 + sin(t * 8.0 + k) * 1.2, Color(1, 1, 0.8, 0.9))
			"vil":
				var i: int = e["i"]
				var key := "vil%d_idle" % (i % 4)
				var voff := Vector2(0, sin(t * 2.0 + i * 1.7) * 1.5)
				if vil_cheer:
					key = "vil%d_cheer" % (i % 4)
					voff.y = -absf(sin(t * 6.0 + i * 1.3)) * 14.0
					if state == "cine":
						voff = Vector2(sin(t * 30.0 + i) * 3.0, 0.0)
				draw_texture(tex[key], e["pos"] - PLAYER_ANCHOR + voff)
				if sleeping:
					for z in 2:
						var zp := fposmod(t * 0.5 + i * 0.3 + z * 0.5, 1.0)
						draw_string(font, e["pos"] + Vector2(18.0 + zp * 14.0, -92.0 - zp * 26.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 20 + z * 6, Color(1, 1, 1, (1.0 - zp) * 0.9))
			"player":
				draw_player()

	draw_smoke()
	draw_critters()


func draw_smoke() -> void:
	var chim := HUT_DRAW - HUT_ANCHOR + Vector2(161, 28)
	for i in 4:
		var ph := fposmod(t * 0.35 + i * 0.25, 1.0)
		var p := chim + Vector2(sin(ph * 6.0 + i) * 8.0 + ph * 22.0, -ph * 72.0)
		draw_circle(p, 6.0 + ph * 12.0, Color(0.92, 0.92, 0.95, (1.0 - ph) * 0.4))
	if progress_view() >= 4 and state != "cine":
		var chim2 := HUT2_DRAW - HUT2_ANCHOR + Vector2(116, 20)
		for i in 3:
			var ph2 := fposmod(t * 0.4 + i * 0.33, 1.0)
			var p2 := chim2 + Vector2(sin(ph2 * 6.0 + i) * 6.0 + ph2 * 16.0, -ph2 * 52.0)
			draw_circle(p2, 5.0 + ph2 * 9.0, Color(0.92, 0.92, 0.95, (1.0 - ph2) * 0.35))


func draw_critters() -> void:
	if night_amount() < 0.2 and not rain:
		for i in 5:
			var ph := i * 1.9
			var base := Vector2(110.0 + i * 125.0, 300.0 + (i % 2) * 120.0)
			if i >= 3:
				base = Vector2(180.0 + (i - 3) * 260.0, 960.0 + (i - 3) * 40.0)
			var p := base + Vector2(sin(t * 0.5 + ph) * 70.0 + sin(t * 1.3 + ph) * 18.0, cos(t * 0.7 + ph * 1.3) * 38.0)
			var flap := absf(sin(t * 13.0 + ph))
			var col := Color("ffb74d") if i % 2 == 0 else Color("f48fb1")
			draw_circle(p + Vector2(-4.0 * flap - 1.0, -1.0), 4.2, col)
			draw_circle(p + Vector2(4.0 * flap + 1.0, -1.0), 4.2, col)
			draw_line(p + Vector2(0, -3), p + Vector2(0, 4), Color(0.2, 0.15, 0.1), 2.0)
	if leaves:
		for i in 14:
			var x := fposmod(i * 131.0 + t * 170.0, W + 120.0) - 60.0
			var y := 200.0 + fposmod(i * 97.0, 1000.0) + sin(t * 2.0 + i) * 28.0
			var rot := t * 3.0 + i
			var pts := PackedVector2Array()
			for v in [Vector2(-8, 0), Vector2(0, -3.5), Vector2(8, 0), Vector2(0, 3.5)]:
				pts.append(Vector2(x, y) + v.rotated(rot))
			draw_colored_polygon(pts, Color("8bc34a") if i % 2 == 0 else Color("ef9a3c"))


func current_tint() -> Color:
	match state:
		"menu", "levels", "confirm", "settings":
			return Color(1.0, 0.8, 0.5, 0.10)
		"cine":
			if cine_scene < 1:
				return DAY_TINTS[0]
			return Color(1, 1, 1, 0.0)
	return DAY_TINTS[level % 4]


func draw_ambient() -> void:
	var na := night_amount()
	if na > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.17, 0.6 * na))
		if na > 0.3:
			for i in 16:
				draw_circle(firefly_pos(i), 2.0, Color(0.9, 1.0, 0.5, 0.9 * clampf((na - 0.3) / 0.7, 0.0, 1.0)))
	if state == "dusk" or state == "dawn":
		var o := sin(clampf(dusk_amt, 0.0, 1.0) * PI) * 0.26
		if o > 0.0:
			draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.5, 0.2, o))
	elif not night:
		var tint: Color = current_tint()
		if tint.a > 0.0:
			draw_rect(Rect2(0, 0, W, H), tint)
	if rain:
		draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.12, 0.2, 0.16))
		for i in 80:
			var x := fposmod(i * 97.31 - t * 70.0, W + 120.0) - 40.0
			var y := fposmod(i * 53.77 + t * 820.0 + i * 13.0, H + 80.0) - 40.0
			draw_line(Vector2(x, y), Vector2(x - 7.0, y + 22.0), Color(0.8, 0.9, 1.0, 0.5), 2.0)


func glow(c: Node2D, center: Vector2, size: float, col: Color) -> void:
	c.draw_texture_rect(tex["glow"], Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), false, col)


# Lueurs additives dessinées sur la couche LightLayer (nuit).
func draw_lights(c: Node2D) -> void:
	var na := night_amount()
	if na <= 0.02 or state == "intro" or state == "menu" or state == "levels" or state == "confirm" or state == "settings" or state == "ad" or state == "nohearts" or state == "shop":
		return
	glow(c, pos + Vector2(0, -30), 440.0, Color(1.0, 0.85, 0.55, 0.4 * na))
	for f in fruits:
		if not f["carried"]:
			if f["gold"]:
				glow(c, f["pos"] + Vector2(0, -12), 250.0, Color(1.0, 0.95, 0.5, 0.8 * na))
			else:
				glow(c, f["pos"] + Vector2(0, -12), 190.0, Color(1.0, 0.78, 0.3, 0.55 * na))
	glow(c, HUT_DRAW - HUT_ANCHOR + Vector2(152, 126), 150.0, Color(1.0, 0.8, 0.35, 0.75 * na))
	if progress_view() >= 4 and state != "cine":
		glow(c, HUT2_DRAW - HUT2_ANCHOR + Vector2(110, 91), 110.0, Color(1.0, 0.8, 0.35, 0.7 * na))
	if not water_solid:
		glow(c, Vector2(BOAT_X, boat_y - 50.0), 90.0, Color(1.0, 0.6, 0.2, 0.3 * na))
	for i in 16:
		var pulse := 0.5 + 0.5 * sin(t * 2.0 + i)
		glow(c, firefly_pos(i), 40.0 + 20.0 * pulse, Color(0.8, 1.0, 0.4, 0.8 * na))


func draw_fx() -> void:
	for q in particles:
		var a: float = clampf(q["life"] / q["max"], 0.0, 1.0)
		var col: Color = q["c"]
		match q["k"]:
			"dot":
				draw_circle(q["p"], q["s"] * (0.4 + 0.6 * a), Color(col.r, col.g, col.b, a))
			"ring":
				var r := lerpf(q["s"], q["r1"], 1.0 - a)
				draw_arc(q["p"], r, 0.0, TAU, 28, Color(col.r, col.g, col.b, a * 0.7), 2.5)
			"conf":
				var s: float = q["s"]
				draw_rect(Rect2(q["p"] - Vector2(s, s * 0.6), Vector2(s * 2.0, s * 1.2)), Color(col.r, col.g, col.b, minf(1.0, a * 2.0)))


func draw_floaters(font: Font) -> void:
	for fl in floaters:
		var a: float = clampf(fl["life"] / fl["max"], 0.0, 1.0)
		var col: Color = fl["c"]
		var p: Vector2 = fl["pos"] + Vector2(-70.0, 0.0)
		draw_string_outline(font, p, fl["text"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, 32, 7, Color(0, 0, 0, a * 0.8))
		draw_string(font, p, fl["text"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, 32, Color(col.r, col.g, col.b, a))


func draw_guide() -> void:
	var g = guide_target()
	if g != null:
		draw_dashed_line(pos, g, Color("ffd166"), 4.0, 14.0)
		var pulse := 26.0 + 6.0 * sin(t * 6.0)
		draw_arc(g, pulse, 0.0, TAU, 32, Color("ffd166"), 5.0)
		draw_circle(g, 8.0, Color("ffd166"))


func draw_player() -> void:
	if state == "dying":
		var ptex: Texture2D = tex["player"]
		var k := clampf(die_t / DIE_TIME, 0.0, 1.0)
		var sc := 1.0 - 0.55 * k
		var origin := pos - PLAYER_ANCHOR * sc + Vector2(0, 26.0 * k)
		draw_texture_rect(ptex, Rect2(origin, ptex.get_size() * sc), false, Color(1, 1, 1, 1.0 - k))
		return
	var key := "player"
	var cheer := hero_cheer
	if cheer:
		key = "player_cheer"
	elif moving and (state == "play" or state == "cine"):
		key = "player_w1" if int(t * 9.0) % 2 == 0 else "player_w2"
	var bob := 0.0
	if cheer:
		bob = -absf(sin(t * 6.0)) * 14.0
	elif moving:
		bob = sin(t * 14.0) * 2.0
	set_xf(Vector2(pos.x, 0.0), Vector2(facing, 1.0))
	draw_texture(tex[key], Vector2(-PLAYER_ANCHOR.x, pos.y - PLAYER_ANCHOR.y + bob))
	set_xf(Vector2.ZERO, Vector2.ONE)
	for i in carried:
		var fx := (i - (carried - 1) / 2.0) * 24.0 - 15.0
		draw_texture_rect(tex["fruit"], Rect2(pos + Vector2(fx, -122.0 + bob), Vector2(30, 34)), false)


# --- Dessin : interface ---
func draw_arrows() -> void:
	if state != "play" or extra <= 0.0:
		return
	var up := 0
	for f in fruits:
		if f["carried"] or f.get("fake", false):
			continue
		var sy: float = f["pos"].y - cam_y
		if sy < TOP_BAR + 6.0:
			var ax := clampf(f["pos"].x, 40.0, W - 40.0)
			var c := Color("ffd166") if f["gold"] else Color("ff8a5b")
			draw_colored_polygon(PackedVector2Array([Vector2(ax, TOP_BAR + 10.0 + sin(t * 6.0) * 4.0), Vector2(ax - 16, TOP_BAR + 34.0), Vector2(ax + 16, TOP_BAR + 34.0)]), c)
			up += 1
	if HUT_POS.y - cam_y > H:
		draw_colored_polygon(PackedVector2Array([Vector2(W / 2.0, H - 12.0 - sin(t * 6.0) * 4.0), Vector2(W / 2.0 - 18, H - 38.0), Vector2(W / 2.0 + 18, H - 38.0)]), Color(0.6, 0.9, 1.0, 0.85))


func draw_hud(font: Font) -> void:
	draw_arrows()
	panel(Rect2(0, 0, W, TOP_BAR), Color(0.05, 0.1, 0.16, 0.8), 0)
	draw_string(font, Vector2(20, 42), T("Jour %d") % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(font, Vector2(W / 2.0 - 190.0, 42), T("Fruits : %d/%d") % [deposited, goal], HORIZONTAL_ALIGNMENT_CENTER, 240, 30, Color("ffd166"))
	var secs := int(ceil(time_left))
	var time_col := Color("ff7b7b") if secs <= 10 else Color.WHITE
	draw_string(font, Vector2(W - 162.0 - 110.0, 42), "%d s" % secs, HORIZONTAL_ALIGNMENT_RIGHT, 110, 30, time_col)

	var x := 12.0
	var nl := maxi(laws.size(), 1)
	var cw := (W - 24.0 - (nl - 1) * 10.0) / nl
	var big := nl <= 2
	for l in laws:
		panel(Rect2(x, 62, cw, 80), Color(1, 1, 1, 0.1), 14)
		panel(Rect2(x, 62, 10, 80), l["color"], 5)
		draw_string(font, Vector2(x + 24.0, 90), T(l["name"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 30.0, 24 if big else 19, Color.WHITE)
		draw_multiline_string(font, Vector2(x + 24.0, 114 if big else 110), T(l["desc"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 30.0, 17 if big else 14, 2, Color(1, 1, 1, 0.85))
		x += cw + 10.0


func draw_ui_buttons(font: Font) -> void:
	for b in ui_buttons():
		if b.has("icon"):
			draw_icon_button(b)
		elif b.has("cell"):
			draw_cell(b, font)
		else:
			draw_button(b, font)


func draw_icon_button(b: Dictionary) -> void:
	var r: Rect2 = b["rect"]
	var c := r.position + r.size / 2.0
	var col := Color(1, 1, 1, 0.95)
	if press_id == b["id"]:
		col = Color("ffd166")
	if b["icon"] == "pause":
		draw_rect(Rect2(c + Vector2(-11, -13), Vector2(8, 26)), col)
		draw_rect(Rect2(c + Vector2(3, -13), Vector2(8, 26)), col)
		return
	draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -6), c + Vector2(-6, -6), c + Vector2(4, -14),
			c + Vector2(4, 14), c + Vector2(-6, 6), c + Vector2(-14, 6)]), col)
	if muted:
		draw_line(c + Vector2(9, -9), c + Vector2(21, 9), Color("ff6b6b"), 3.5)
		draw_line(c + Vector2(21, -9), c + Vector2(9, 9), Color("ff6b6b"), 3.5)
	else:
		draw_arc(c + Vector2(6, 0), 8.0, -0.9, 0.9, 10, col, 2.5)
		draw_arc(c + Vector2(6, 0), 15.0, -0.9, 0.9, 12, col, 2.5)


func draw_button(b: Dictionary, font: Font) -> void:
	var r: Rect2 = b["rect"]
	var pressed: bool = press_id == b["id"]
	var col: Color = b["color"]
	var dy := 6.0 if pressed else 0.0
	panel(Rect2(r.position + Vector2(0, 8), r.size), col.darkened(0.55), 24)
	var body := Rect2(r.position + Vector2(0, dy), r.size)
	panel2(body, col, 24, col.lightened(0.45), 3)
	panel(Rect2(body.position + Vector2(10, 7), Vector2(body.size.x - 20.0, body.size.y * 0.4)), Color(1, 1, 1, 0.17), 18)
	var fsize: int = b["size"]
	var sub: String = b["sub"]
	var cy := body.position.y + body.size.y / 2.0
	if sub != "":
		outline_text(font, b["label"], cy - 2.0, fsize, Color.WHITE, 8, body.position.x, body.size.x)
		draw_string(font, Vector2(body.position.x, cy + 34.0), sub, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 22, Color(1, 1, 1, 0.9))
	else:
		outline_text(font, b["label"], cy + fsize * 0.34, fsize, Color.WHITE, 8, body.position.x, body.size.x)


func draw_cell(b: Dictionary, font: Font) -> void:
	var r: Rect2 = b["rect"]
	var n: int = b["cell"]
	var unlocked := n <= best_day
	var stars: int = int(level_stars[n])
	var pressed: bool = press_id == b["id"]
	var col := tier_color(n) if unlocked else Color(0.3, 0.33, 0.38)
	if unlocked and stars >= 3:
		col = Color("f9a825")
	var dy := 5.0 if pressed else 0.0
	panel(Rect2(r.position + Vector2(0, 7), r.size), col.darkened(0.55), 22)
	var body := Rect2(r.position + Vector2(0, dy), r.size)
	var border := col.lightened(0.45)
	if n == cur_level and unlocked:
		border = Color(1, 1, 1, 0.65 + 0.35 * sin(t * 5.0))
	panel2(body, col, 22, border, 4 if n == cur_level else 3)
	panel(Rect2(body.position + Vector2(10, 7), Vector2(body.size.x - 20.0, body.size.y * 0.36)), Color(1, 1, 1, 0.15), 16)
	var c := body.position + Vector2(body.size.x / 2.0, 0.0)
	if unlocked:
		outline_text(font, str(n), body.position.y + 76.0, 54, Color.WHITE, 8, body.position.x, body.size.x)
		for i in 3:
			var st: Texture2D = tex["star"] if i < stars else tex["star_off"]
			draw_texture_rect(st, Rect2(Vector2(c.x - 57.0 + i * 38.0, body.position.y + 92.0), Vector2(36, 36)), false)
	else:
		draw_rect(Rect2(c + Vector2(-20, 52 + dy), Vector2(40, 34)), Color(0.78, 0.8, 0.85))
		draw_arc(c + Vector2(0, 52 + dy), 14.0, PI, TAU, 16, Color(0.78, 0.8, 0.85), 6.0)
		draw_circle(c + Vector2(0, 69 + dy), 5.0, Color(0.3, 0.33, 0.38))
		draw_string(font, Vector2(body.position.x, body.position.y + 126.0), str(n), HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 24, Color(1, 1, 1, 0.55))


func solution_text() -> String:
	var s := ""
	if water_solid:
		s += T("La rivière est gelée : traverse-la à pied, puis suis la ligne jaune.")
	else:
		s += T("Suis la ligne jaune. Reste près du quai : le bateau t'embarque tout seul. Prends plusieurs fruits par trajet.")
	for l in laws:
		s += "\n\n%s : %s" % [T(l["name"]), T(l["tip"])]
	if traps.size() > 0:
		s += "\n\n" + T("Pièges cachés : les zones rouges sont dangereuses, contourne-les. Surveille aussi les ombres au sol.")
	return s


func draw_solution_panel(font: Font, y: float) -> void:
	panel(Rect2(40, y, W - 80.0, 360), Color(0.1, 0.3, 0.2, 0.92), 20)
	center_text(font, T("SOLUTION"), y + 46.0, 32, Color("ffd166"))
	draw_multiline_string(font, Vector2(64, y + 90.0), solution_text(), HORIZONTAL_ALIGNMENT_LEFT, W - 128.0, 21, -1, Color.WHITE)


func draw_cine_overlay(font: Font) -> void:
	var bar := 140.0
	draw_rect(Rect2(0, 0, W, bar), Color.BLACK)
	draw_rect(Rect2(0, H - bar, W, bar), Color.BLACK)
	draw_rect(Rect2(0, bar - 3.0, W, 3.0), Color(1, 0.82, 0.4, 0.5))
	draw_rect(Rect2(0, H - bar, W, 3.0), Color(1, 0.82, 0.4, 0.5))
	for c in CINE_CAPTIONS:
		var st: float = c[0]
		var en: float = c[1]
		var txt: String = T(c[2])
		if cine_t >= st and cine_t < en:
			var n := int((cine_t - st) * 30.0)
			var shown := txt.substr(0, mini(n, txt.length()))
			var a := clampf((en - cine_t) / 0.5, 0.0, 1.0)
			draw_multiline_string(font, Vector2(20, H - bar + 52.0), shown, HORIZONTAL_ALIGNMENT_CENTER, W - 40.0, 28, 3, Color(1, 1, 1, a))
	if cine_scene == 1:
		var u := cine_t - 5.6
		var ph := int(u / 1.1) % 5
		var lt := fposmod(u, 1.1)
		var pop := 1.0 + 0.25 * clampf(1.0 - lt * 6.0, 0.0, 1.0)
		var bn: Array = CINE_BANNERS[ph]
		var col: Color = bn[1]
		var a2 := clampf(minf(lt * 8.0, (1.1 - lt) * 8.0), 0.0, 1.0)
		panel(Rect2(30, 190, W - 60.0, 90), Color(0, 0, 0, 0.5 * a2), 22)
		draw_string_outline(font, Vector2(0, 250), T(bn[0]), HORIZONTAL_ALIGNMENT_CENTER, W, int(40 * pop), 10, Color(0, 0, 0, a2))
		draw_string(font, Vector2(0, 250), T(bn[0]), HORIZONTAL_ALIGNMENT_CENTER, W, int(40 * pop), Color(col.r, col.g, col.b, a2))
	draw_string(font, Vector2(0, 86), T("Touche pour passer"), HORIZONTAL_ALIGNMENT_RIGHT, W - 28.0, 20, Color(1, 1, 1, 0.6))
	var fa := 0.0
	if cine_t < 0.9:
		fa = 1.0 - cine_t / 0.9
	elif cine_t > CINE_LEN - 0.9:
		fa = (cine_t - (CINE_LEN - 0.9)) / 0.9
	if fa > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, clampf(fa, 0.0, 1.0)))


func draw_menu(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.05, 0.1, 0.25))
	# Rayons de soleil tournants derrière le logo
	var c := Vector2(360, 300)
	for i in 14:
		var a0 := t * 0.12 + i * TAU / 14.0
		var a1 := a0 + TAU / 30.0
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 900.0, c + Vector2(cos(a1), sin(a1)) * 900.0]),
				Color(1.0, 0.95, 0.6, 0.10))
	# Dégradé sombre en haut et en bas
	for i in 10:
		var k := 1.0 - i / 10.0
		draw_rect(Rect2(0, i * 14.0, W, 14.0), Color(0, 0, 0, 0.5 * k))
		draw_rect(Rect2(0, H - (i + 1) * 14.0, W, 14.0), Color(0, 0, 0, 0.5 * k))
	draw_hearts(font, 450.0, 50.0, 30.0)
	# Logo
	wave_text(font, T("LOIS"), 360.0, 270.0, 124, Color("ffd166"), 7.0)
	wave_text(font, T("CAPRICIEUSES"), 360.0, 392.0, 84, Color.WHITE, 5.0)
	panel2(Rect2(100, 440, 520, 50), Color(0.7, 0.15, 0.18, 0.95), 12, Color("ffd166"), 3)
	draw_string(font, Vector2(100, 474), T("La nature change les règles chaque jour !"), HORIZONTAL_ALIGNMENT_CENTER, 520, 22, Color.WHITE)
	# Statistiques
	var line := T("Jour %d atteint  -  %d étoile(s)  -  Score %d") % [best_day, total_stars(), total_score()]
	panel(Rect2(60, 1050, W - 120.0, 56), Color(0, 0, 0, 0.5), 18)
	draw_string(font, Vector2(60, 1086), line, HORIZONTAL_ALIGNMENT_CENTER, W - 120.0, 24, Color(1, 1, 1, 0.95))
	draw_string(font, Vector2(0, 1274), "v4", HORIZONTAL_ALIGNMENT_RIGHT, W - 14.0, 16, Color(1, 1, 1, 0.4))


func draw_settings(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.06, 0.1, 0.86))
	wave_text(font, T("PARAMÈTRES"), 360.0, 300.0, 84, Color("ffd166"), 4.0)
	draw_string(font, Vector2(20, 756), T("Mode détendu : beaucoup plus de temps, pour jouer sans stress."), HORIZONTAL_ALIGNMENT_CENTER, W - 40.0, 17, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(0, 1190), T("Ta progression : jour %d atteint, %d étoile(s), score %d") % [best_day, total_stars(), total_score()],
			HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 1, 1, 0.85))
	draw_string(font, Vector2(0, 1224), T("Sauvegarde automatique sur cet appareil."), HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(0, 1256), T("ID joueur : %s") % short_id(), HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 1, 1, 0.55))


func draw_levels(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.06, 0.1, 0.84))
	draw_hearts(font, 450.0, 40.0, 26.0)
	wave_text(font, T("NIVEAUX"), 360.0, 130.0, 84, Color("ffd166"), 4.0)
	draw_string(font, Vector2(0, 190), T("Étoiles : %d / %d     Score : %d") % [total_stars(), MAX_LEVEL * 3, total_score()],
			HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(0, 950), "%d / %d" % [lvl_page + 1, MAX_PAGES], HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(0, 1060), T("Touche un niveau débloqué pour jouer"), HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 1, 1, 0.55))


func draw_overlay(font: Font) -> void:
	var show_solution := solution_on()
	var blink := fmod(t, 1.2) < 0.8
	match state:
		"menu":
			draw_menu(font)
			return
		"levels":
			draw_levels(font)
			return
		"settings":
			draw_settings(font)
			return
		"confirm":
			draw_settings(font)
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.7))
			panel2(Rect2(70, 420, W - 140.0, 420), Color(0.1, 0.14, 0.2, 0.97), 28, Color("e53935"), 4)
			center_text(font, T("Effacer la progression ?"), 510.0, 38, Color("ffd166"))
			center_text(font, T("Tous tes niveaux, étoiles et scores\nseront supprimés."), 570.0, 26)
			return
		"ad":
			draw_ad(font)
			return
		"nohearts":
			draw_nohearts(font)
			return
		"shop":
			draw_shop(font)
			return
		"pause":
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.7))
			center_text(font, T("PAUSE"), 440.0, 72, Color("ffd166"))
			return
		"dusk":
			draw_dusk_caption(font)
			return
		"dawn":
			var a := clampf(dawn_t / DAWN_LEN, 0.0, 1.0)
			var ta := sin(a * PI)
			draw_string_outline(font, Vector2(0, 600), T("Jour %d") % level, HORIZONTAL_ALIGNMENT_CENTER, W, 110, 16, Color(0, 0, 0, ta * 0.9))
			draw_string(font, Vector2(0, 600), T("Jour %d") % level, HORIZONTAL_ALIGNMENT_CENTER, W, 110, Color(1, 0.86, 0.4, ta))
			draw_string(font, Vector2(0, 664), T("Une nouvelle journée commence..."), HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1, 1, 1, ta))
			return

	var shade := 0.74
	if state == "win":
		shade = 0.3
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, shade))
	draw_hearts(font, 700.0, 178.0, 28.0)

	match state:
		"intro":
			var sh := 12.0 + (70.0 if laws.size() > 2 else 0.0)
			var step := 110.0 if laws.size() > 2 else 130.0
			center_text(font, T("Jour %d") % level, 205.0, 64, Color("ffd166"))
			center_text(font, tier_name(level), 240.0, 22, tier_color(level).lightened(0.45))
			center_text(font, T("Aujourd'hui, les lois de la nature changent :"), 274.0, 26)
			var y := 342.0
			for l in laws:
				center_text(font, T(l["name"]), y, 40 if laws.size() <= 2 else 34, l["color"].lightened(0.3))
				center_text(font, T(l["desc"]), y + 46.0, 26 if laws.size() <= 2 else 23)
				y += step
			var goal_line := T("Rapporte %d fruits à la cabane (%d à la fois) avant la fin du temps.") % [goal, capacity]
			if level >= 2:
				goal_line += T(" Le fruit doré donne +%d s.") % int(GOLD_BONUS)
			center_text(font, goal_line, 590.0 + sh, 26)
			if water_solid:
				center_text(font, T("La rivière est gelée : tu peux la traverser !"), 680.0 + sh, 26, Color("b8e6fa"))
			else:
				center_text(font, T("Attention : nager dans l'eau est mortel. Prends le bateau !"), 680.0 + sh, 26, Color("ff8a80"))
			var prompt_y := 880.0 + sh
			if show_solution:
				draw_solution_panel(font, 740.0 + sh)
				prompt_y = 1160.0 + sh
			if blink:
				center_text(font, T("Touche l'écran pour commencer"), prompt_y, 32, Color("ffd166"))
			var info := T("Village : %d habitant(s)") % villager_count()
			if level >= IMPOSSIBLE_FROM:
				info = T("Même le robot de test n'a jamais réussi ce niveau...")
			if int(level_score[level]) > 0:
				info = T("Meilleur score : %d  -  %d étoile(s)") % [int(level_score[level]), int(level_stars[level])]
			center_text(font, info, prompt_y + 50.0, 24, Color(1, 1, 1, 0.7))
		"win":
			panel(Rect2(50, 290, W - 100.0, 540), Color(0.04, 0.1, 0.16, 0.86), 26)
			if level >= MAX_LEVEL:
				center_text(font, T("Village sauvé !"), 380.0, 66, Color("7ee081"))
			else:
				center_text(font, T("Bravo !"), 380.0, 72, Color("7ee081"))
			for i in 3:
				var appear := 0.3 + i * 0.35
				var sx := W / 2.0 + (i - 1) * 100.0 - 38.0
				if i < last_stars and win_t >= appear:
					var pop := 1.0 + 0.35 * clampf(1.0 - (win_t - appear) * 4.0, 0.0, 1.0)
					var sz := 76.0 * pop
					draw_texture_rect(tex["star"], Rect2(Vector2(sx + 38.0 - sz / 2.0, 440.0 + 38.0 - sz / 2.0), Vector2(sz, sz)), false)
				else:
					draw_texture_rect(tex["star_off"], Rect2(Vector2(sx, 440.0), Vector2(76, 76)), false)
			center_text(font, T("Score : %d") % last_score, 596.0, 38, Color("ffd166"))
			if new_record:
				center_text(font, T("Nouveau record !"), 640.0, 26, Color("7ee081") if blink else Color("b9f6ca"))
			else:
				center_text(font, T("Record : %d") % int(level_score[level]), 640.0, 24, Color(1, 1, 1, 0.75))
			center_text(font, T("Le village a survécu au jour %d.") % level, 704.0, 28)
			if level >= MAX_LEVEL:
				center_text(font, T("Tu as terminé tous les niveaux. Merci d'avoir joué !"), 750.0, 26, Color("ffd166"))
			elif level <= 6:
				center_text(font, T("Un nouvel habitant rejoint le village !"), 750.0, 26, Color("ffd166"))
				center_text(font, T("Demain, de nouvelles lois arrivent..."), 794.0, 24, Color(1, 1, 1, 0.8))
			else:
				center_text(font, T("Demain, de nouvelles lois arrivent..."), 750.0, 26, Color(1, 1, 1, 0.8))
			if blink:
				var cont := T("Touche pour continuer")
				if level >= MAX_LEVEL:
					cont = T("Touche pour revenir au menu")
				center_text(font, cont, 920.0, 32, Color("ffd166"))
		"lose":
			if lose_reason != "temps":
				var msg := death_text(lose_reason)
				center_text(font, msg[0], 258.0, 46, Color("ff6b6b"))
				center_text(font, msg[1], 340.0, 28)
			else:
				center_text(font, T("Temps écoulé"), 260.0, 64, Color("ff6b6b"))
				center_text(font, T("Tu as rapporté %d fruit(s) sur %d.") % [deposited, goal], 340.0, 28)
			center_text(font, T("Défaite n°%d - les mêmes lois reviennent.") % fail_count, 400.0, 26, Color(1, 1, 1, 0.8))
			var by := 850.0 if show_solution else 560.0
			var prompt_y2 := by + (130.0 if premium else 344.0)
			if show_solution:
				draw_solution_panel(font, 460.0)
			elif premium:
				center_text(font, T("Après %d défaites de suite, la solution s'affiche.") % SOLUTION_AFTER, 460.0, 24, Color("ffd166"))
			else:
				center_text(font, T("Avec la version sans pub, la solution s'affiche après %d défaites.") % SOLUTION_AFTER, 460.0, 20, Color("ffd166"))
			if blink:
				center_text(font, T("Touche pour réessayer"), prompt_y2, 32, Color("ffd166"))


func draw_dusk_caption(font: Font) -> void:
	var txt := ""
	var st := 0.0
	var en := 0.0
	if dusk_t >= 0.5 and dusk_t < 3.2:
		txt = T("La nuit tombe sur le village...")
		st = 0.5
		en = 3.2
	elif dusk_t >= 3.3:
		txt = T(DUSK_LINES[level % DUSK_LINES.size()])
		st = 3.3
		en = DUSK_LEN + 0.5
	if txt == "":
		return
	var n := int((dusk_t - st) * 26.0)
	var shown := txt.substr(0, mini(n, txt.length()))
	var a := clampf(minf((dusk_t - st) * 4.0, (en - dusk_t) * 3.0), 0.0, 1.0)
	panel(Rect2(40, 575, W - 80.0, 96), Color(0, 0, 0, 0.55 * a), 26)
	draw_string(font, Vector2(40, 636), shown, HORIZONTAL_ALIGNMENT_CENTER, W - 80.0, 30, Color(1, 1, 1, a))


# --- Cœurs, pubs et version sans pub ---
func solution_on() -> bool:
	return premium and fail_count >= SOLUTION_AFTER


func price_text() -> String:
	match Lang.code:
		"fr":
			return "1,99 $ (environ 1 150 FCFA)"
		"es":
			return "1,99 US$"
	return "$1.99"


func now_s() -> float:
	return Time.get_unix_time_from_system()


func tick_hearts() -> void:
	if premium:
		hearts = MAX_HEARTS
		return
	if hearts >= MAX_HEARTS:
		next_heart = 0.0
		return
	var n := now_s()
	if next_heart <= 0.0 or next_heart > n + HEART_SECS:
		next_heart = n + HEART_SECS
	var changed := false
	while hearts < MAX_HEARTS and n >= next_heart:
		hearts += 1
		next_heart += HEART_SECS
		changed = true
	if hearts >= MAX_HEARTS:
		next_heart = 0.0
	if changed:
		save_game()


func lose_heart() -> void:
	if premium:
		return
	if hearts >= MAX_HEARTS:
		next_heart = now_s() + HEART_SECS
	hearts = maxi(0, hearts - 1)
	save_game()


func heart_wait() -> float:
	return maxf(0.0, next_heart - now_s())


func fmt_time(sec: float) -> String:
	var s := int(ceil(sec))
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func can_play() -> bool:
	return premium or hearts > 0


func try_start() -> void:
	if can_play():
		start_play()
	else:
		state = "nohearts"
		ui_lock = 0.3


func record_history() -> void:
	var fr: Array = []
	for f in fruits:
		fr.append(f.duplicate())
	history.append({"tl": time_left, "pos": pos, "carried": carried, "dep": deposited, "fruits": fr,
			"by": boat_y, "bn": boat_to_north, "bw": boat_wait, "riding": riding})
	while history.size() > 46:
		history.pop_front()


# Retour en arrière : on reprend l'état d'il y a environ 20 secondes.
func do_comeback() -> void:
	if history.is_empty():
		return
	var h: Dictionary = history[0]
	fruits = []
	for f in h["fruits"]:
		fruits.append(f.duplicate())
	time_left = float(h["tl"])
	last_sec = int(ceil(time_left))
	pos = h["pos"]
	carried = int(h["carried"])
	deposited = int(h["dep"])
	boat_y = float(h["by"])
	boat_to_north = bool(h["bn"])
	boat_wait = float(h["bw"])
	riding = bool(h["riding"])
	vel = Vector2.ZERO
	has_target = false
	moving = false
	die_t = 0.0
	fail_count = maxi(0, fail_count - 1)
	history.clear()
	hist_t = 0.0
	particles.clear()
	state = "play"
	snd("bell", -4.0)
	sfx.set_music_db(-10.0, 0.8)


func ad_secs(base: float) -> float:
	return base * (0.2 if TEST_MODE else 1.0)


func start_ad(kind: String, count: int, base: float, cancelable: bool) -> void:
	ad_kind = kind
	ad_n = count
	ad_idx = 1
	ad_base = base
	ad_len_cur = ad_secs(base)
	ad_left = ad_len_cur
	ad_cancelable = cancelable
	state = "ad"
	ui_lock = 0.4
	sfx.set_music_db(-26.0, 0.5)


func ad_finish() -> void:
	if ad_idx < ad_n:
		ad_idx += 1
		ad_len_cur = ad_secs(ad_base)
		ad_left = ad_len_cur
		ui_lock = 0.4
		return
	sfx.set_music_db(-10.0, 0.8)
	match ad_kind:
		"comeback":
			do_comeback()
		"skip":
			win_game(true)
		"inter":
			proceed_after_win()


func ad_cancel() -> void:
	sfx.set_music_db(-10.0, 0.8)
	state = "lose"
	ui_lock = 0.3


func buy_premium() -> void:
	if premium:
		return
	if TEST_MODE:
		# Achat simulé (test). À remplacer par Google Play Billing avant publication.
		premium = true
		hearts = MAX_HEARTS
		next_heart = 0.0
		save_game()
		snd("win", -4.0)


func lose_buttons() -> Array:
	var arr: Array = []
	var by := 850.0 if solution_on() else 560.0
	if not history.is_empty():
		var lab := T("REVENIR 20 s EN ARRIÈRE (gratuit)") if premium else T("REVENIR 20 s EN ARRIÈRE (pub 25 s)")
		arr.append(btn("comeback", Rect2(60, by, 600, 96), lab, Color("1e88e5"), 26))
	if not premium:
		if fail_count >= SKIP_AFTER_DEATHS:
			arr.append(btn("skip", Rect2(60, by + 116.0, 600, 96), T("PASSER LE NIVEAU (2 pubs de 30 s)"), Color("e53935"), 26))
		arr.append(btn("shop", Rect2(60, by + 232.0, 600, 80), T("SANS PUB + CŒURS ILLIMITÉS : %s") % price_text(), Color("f9a825"), 22))
	return arr


func draw_heart(c: Vector2, sz: float, col: Color) -> void:
	draw_circle(c + Vector2(-sz * 0.27, -sz * 0.12), sz * 0.33, col)
	draw_circle(c + Vector2(sz * 0.27, -sz * 0.12), sz * 0.33, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-sz * 0.58, 0.0), c + Vector2(sz * 0.58, 0.0), c + Vector2(0, sz * 0.62)]), col)


func draw_hearts(font: Font, right_x: float, y: float, sz: float) -> void:
	var step := sz * 1.22
	var x0 := right_x - step * MAX_HEARTS + step / 2.0
	for i in MAX_HEARTS:
		var c := Vector2(x0 + i * step, y)
		if premium or i < hearts:
			draw_heart(c + Vector2(0, 2), sz * 1.08, Color(0, 0, 0, 0.45))
			draw_heart(c, sz, Color("ffc107") if premium else Color("ff4d5e"))
			draw_circle(c + Vector2(-sz * 0.3, -sz * 0.22), sz * 0.09, Color(1, 1, 1, 0.7))
		else:
			draw_heart(c, sz, Color(0.25, 0.28, 0.33, 0.9))
	if not premium and hearts < MAX_HEARTS:
		draw_string(font, Vector2(right_x - step * MAX_HEARTS, y + sz + 14.0), T("Cœur : +1 dans %s") % fmt_time(heart_wait()),
				HORIZONTAL_ALIGNMENT_CENTER, step * MAX_HEARTS, 16, Color(1, 1, 1, 0.85))


func draw_nohearts(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.06, 0.88))
	draw_heart(Vector2(360, 330), 190.0, Color(0.3, 0.32, 0.38))
	draw_line(Vector2(330, 250), Vector2(390, 330), Color(0.03, 0.03, 0.06), 8.0)
	draw_line(Vector2(390, 330), Vector2(340, 410), Color(0.03, 0.03, 0.06), 8.0)
	center_text(font, T("Plus de cœurs !"), 560.0, 60, Color("ff6b6b"))
	center_text(font, T("Prochain cœur dans %s") % fmt_time(heart_wait()), 640.0, 36, Color("ffd166"))
	center_text(font, T("Un cœur revient toutes les 5 minutes."), 700.0, 24, Color(1, 1, 1, 0.8))


func draw_shop(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.06, 0.1, 0.9))
	wave_text(font, T("VERSION SANS PUB"), 360.0, 190.0, 64, Color("ffd166"), 4.0)
	panel2(Rect2(50, 250, W - 100.0, 400), Color(0.08, 0.14, 0.2, 0.92), 26, Color("f9a825"), 3)
	var lines := [T("Plus aucune publicité"), T("Cœurs illimités"), T("La solution s'affiche après 5 défaites"), T("Retour en arrière gratuit après une défaite")]
	for i in lines.size():
		var yy := 330.0 + i * 74.0
		draw_circle(Vector2(100, yy - 9.0), 13.0, Color("43a047"))
		draw_polyline(PackedVector2Array([Vector2(93, yy - 9), Vector2(99, yy - 3), Vector2(108, yy - 16)]), Color.WHITE, 3.5)
		draw_multiline_string(font, Vector2(130, yy), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 500.0, 25, 2, Color.WHITE)
	if premium:
		center_text(font, T("Merci ! La version sans pub est activée."), 800.0, 32, Color("7ee081"))
	else:
		center_text(font, T("Un seul paiement, pour toujours."), 700.0, 24, Color(1, 1, 1, 0.8))
		center_text(font, T("Le prix exact est affiché par le Play Store dans ta monnaie."), 920.0, 20, Color(1, 1, 1, 0.6))
	if TEST_MODE:
		center_text(font, T("MODE TEST : l'achat est simulé (aucun paiement)."), 1150.0, 20, Color("ff8a80"))


func draw_ad(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.05, 0.96))
	center_text(font, T("PUBLICITÉ"), 200.0, 60, Color.WHITE)
	var why := T("Pour revenir 20 s en arrière")
	if ad_kind == "skip":
		why = T("Pour passer le niveau")
	elif ad_kind == "inter":
		why = T("Pub obligatoire toutes les 3 victoires")
	center_text(font, why, 250.0, 24, Color("ffd166"))
	panel2(Rect2(80, 310, 560, 360), Color(0.12, 0.16, 0.26), 24, Color(1, 1, 1, 0.25), 3)
	center_text(font, T("ESPACE PUBLICITAIRE\n(exemple)"), 470.0, 36, Color(1, 1, 1, 0.5))
	draw_arc(Vector2(360, 590), 30.0, t * 4.0, t * 4.0 + 4.2, 24, Color("ffd166"), 6.0)
	var frac := 1.0 - ad_left / maxf(ad_len_cur, 0.01)
	panel(Rect2(80, 730, 560, 24), Color(1, 1, 1, 0.15), 12)
	panel(Rect2(80, 730, maxf(24.0, 560.0 * frac), 24), Color("43a047"), 12)
	center_text(font, T("Pub %d / %d") % [ad_idx, ad_n], 810.0, 28)
	if ad_left > 0.0:
		var shown := ad_left / (0.2 if TEST_MODE else 1.0)
		center_text(font, T("Récompense dans %d s") % int(ceil(shown)), 870.0, 32, Color("ffd166"))
	else:
		center_text(font, T("Pub terminée !"), 870.0, 32, Color("7ee081"))
	if TEST_MODE:
		center_text(font, T("Ceci est une pub d'essai (durée raccourcie) : le vrai réseau publicitaire sera branché avant la publication."), 930.0, 18, Color(1, 1, 1, 0.55))


# --- Pièges cachés ---
func trap_params(lv: int) -> Dictionary:
	var d := difficulty(lv)
	var n_traps := 0
	if lv >= 3:
		n_traps = mini(2 + floori(lv / 10.0), 16)
	var fakes := 0
	if lv >= 8:
		fakes = mini(1 + floori((lv - 8) / 18.0), 5)
	var interval := 0.0
	if lv >= 5:
		interval = lerpf(7.0, 2.2, pow(d, 0.8))
	var warn := lerpf(0.95, 0.6, d)
	var ex := map_extra(lv)
	if lv >= 3 and ex > 0.0:
		n_traps = mini(n_traps + floori(ex / 110.0), 34)
	if lv >= 8 and ex > 0.0:
		fakes = mini(fakes + floori(ex / 450.0), 7)
	var b_interval := 0.0
	if lv >= 12:
		b_interval = lerpf(10.0, 4.0, pow(d, 0.8))
	if lv >= IMPOSSIBLE_FROM:
		n_traps = 30
		fakes = 10
		interval = 0.5
		warn = 0.4
		b_interval = 1.5
	return {"n": n_traps, "fakes": fakes, "interval": interval, "warn": warn, "b_interval": b_interval}


func trap_spot_ok(q: Vector2, spacing: float) -> bool:
	if q.distance_to(HUT_POS) < 110.0 or q.distance_to(Vector2(360, 940)) < 90.0:
		return false
	if absf(q.x - BOAT_X) < 80.0:
		if (q.y > RIVER_TOP - 140.0 and q.y < RIVER_TOP) or (q.y > RIVER_BOT and q.y < RIVER_BOT + 140.0):
			return false
	for tr in traps:
		if q.distance_to(tr["pos"]) < spacing:
			return false
	return true


func build_traps() -> void:
	traps.clear()
	fake_spots.clear()
	strikes.clear()
	shown = {}
	hit_trap = -1
	trap_cfg = trap_params(level)
	var r := RandomNumberGenerator.new()
	r.seed = level * 104729 + 7
	var spacing := 150.0 if level < IMPOSSIBLE_FROM else 80.0
	var tries := 0
	while traps.size() < int(trap_cfg["n"]) and tries < 800:
		tries += 1
		var y := r.randf_range(top_y + 60.0, RIVER_TOP - 70.0)
		var south_p := 0.5 if extra <= 0.0 else maxf(0.12, 0.5 * 240.0 / (240.0 + extra) + 0.05)
		if r.randf() < south_p:
			y = r.randf_range(RIVER_BOT + 70.0, H - 60.0)
		var q := Vector2(r.randf_range(50.0, W - 50.0), y)
		if trap_spot_ok(q, spacing):
			var roll := r.randf()
			var kind := "bear"
			if roll < 0.32:
				kind = "pit"
			elif level >= 6 and roll < 0.62:
				kind = "spike"
			traps.append({"k": kind, "pos": q, "r": 34.0 if kind == "spike" else 30.0, "ph": 0, "pt": 0.0})
	tries = 0
	while fake_spots.size() < int(trap_cfg["fakes"]) and tries < 400:
		tries += 1
		var q2 := Vector2(r.randf_range(120.0, W - 120.0), r.randf_range(top_y + 60.0, RIVER_TOP - 70.0))
		var ok := q2.distance_to(Vector2(BOAT_X, RIVER_TOP - 30.0)) > 140.0
		for tr in traps:
			if q2.distance_to(tr["pos"]) < 130.0:
				ok = false
		for sp in fake_spots:
			if q2.distance_to(sp) < 150.0:
				ok = false
		if ok:
			fake_spots.append(q2)
	boulders.clear()
	boulder_t = float(trap_cfg["b_interval"]) * 1.1 if float(trap_cfg["b_interval"]) > 0.0 else 0.0
	strike_rng.seed = level * 31 + 5
	strike_t = float(trap_cfg["interval"]) * 1.2 if float(trap_cfg["interval"]) > 0.0 else 0.0


func update_strikes(delta: float) -> void:
	var interval := float(trap_cfg.get("interval", 0.0))
	if interval > 0.0:
		strike_t -= delta
		if strike_t <= 0.0:
			strike_t = strike_rng.randf_range(0.6, 1.4) * interval
			spawn_strike()
	var i := strikes.size() - 1
	while i >= 0:
		var st: Dictionary = strikes[i]
		st["t"] += delta
		if st["t"] >= st["warn"]:
			strikes.remove_at(i)
			impact(st)
			if state != "play":
				return
		i -= 1


func spawn_strike() -> void:
	if riding:
		return
	var bolt := (rain and strike_rng.randf() < 0.45) or (level >= 30 and strike_rng.randf() < 0.25)
	var aim := pos + vel * 0.35 + Vector2(strike_rng.randf_range(-55.0, 55.0), strike_rng.randf_range(-55.0, 55.0))
	aim.x = clampf(aim.x, 40.0, W - 40.0)
	if pos.y < RIVER_TOP:
		aim.y = clampf(aim.y, top_y + 30.0, RIVER_TOP - 35.0)
	else:
		aim.y = clampf(aim.y, RIVER_BOT + 35.0, H - 30.0)
	strikes.append({"pos": aim, "r": 50.0 if bolt else 44.0, "t": 0.0, "warn": float(trap_cfg["warn"]) + (0.35 if bolt else 0.0) + (0.3 if speed_mult < 0.9 else 0.0), "kind": "bolt" if bolt else "rock"})


func impact(st: Dictionary) -> void:
	var c: Vector2 = st["pos"]
	shake = maxf(shake, 0.5)
	if st["kind"] == "bolt":
		flash = 0.6
		snd("sting", -8.0)
		spawn_particles(c, Color(0.85, 0.92, 1.0), 14, 220.0, 0.5, 3.5, 100.0, 60.0)
	else:
		snd("board", 0.0, 0.55)
		spawn_particles(c, Color(0.7, 0.65, 0.55), 14, 180.0, 0.6, 4.0, 500.0, 90.0)
	if not riding and pos.distance_to(c) < float(st["r"]):
		start_dying("foudre" if st["kind"] == "bolt" else "pierre")


func death_text(r: String) -> Array:
	match r:
		"ours":
			return [T("Piège à ours !"), T("Un piège était caché dans l'herbe...")]
		"fosse":
			return [T("Tu es tombé dans une fosse !"), T("Le sol cachait un trou...")]
		"pierre":
			return [T("Écrasé par une pierre !"), T("Surveille les ombres au sol.")]
		"foudre":
			return [T("Frappé par la foudre !"), T("Le ciel prévient à peine.")]
		"faux":
			return [T("Ce fruit était piégé !"), T("Tous les fruits ne sont pas ce qu'ils semblent.")]
		"pics":
			return [T("Des pics ont surgi du sol !"), T("Le sol réagit quand tu approches...")]
		"rocher":
			return [T("Écrasé par un rocher roulant !"), T("Une bande rouge te prévenait.")]
	return [T("Tu t'es noyé !"), T("L'eau est mortelle : prends le bateau !")]


# --- Guide du robot : évite les pièges connus et esquive les chutes ---
func hazard_circles() -> Array:
	var arr: Array = []
	for tr in traps:
		arr.append({"p": tr["pos"], "r": float(tr["r"]) + 30.0})
	for f in fruits:
		if f.get("fake", false) and not f["carried"]:
			arr.append({"p": f["pos"], "r": 74.0})
	return arr


func clamp_land(c: Vector2) -> Vector2:
	var q := Vector2(clampf(c.x, 40.0, W - 40.0), c.y)
	if pos.y < RIVER_TOP:
		q.y = clampf(q.y, top_y + 15.0, RIVER_TOP - 50.0)
	else:
		q.y = clampf(q.y, RIVER_BOT + 50.0, H - 30.0)
	return q


func spot_safe(c: Vector2) -> bool:
	for h in hazard_circles():
		if c.distance_to(h["p"]) < float(h["r"]):
			return false
	return true


func segment_safe(a: Vector2, b: Vector2) -> bool:
	var seg := b - a
	var l2 := seg.length_squared()
	for h in hazard_circles():
		var tt := 0.0 if l2 < 1.0 else clampf((h["p"] - a).dot(seg) / l2, 0.0, 1.0)
		if (a + seg * tt).distance_to(h["p"]) < float(h["r"]) - 14.0:
			return false
	return true


func fix_wp(w: Vector2) -> Vector2:
	var q := w
	q.x = clampf(q.x, 35.0, W - 35.0)
	if not water_solid:
		if q.y > RIVER_TOP - 40.0 and q.y <= (RIVER_TOP + RIVER_BOT) / 2.0:
			q.y = RIVER_TOP - 40.0
		elif q.y < RIVER_BOT + 40.0 and q.y > (RIVER_TOP + RIVER_BOT) / 2.0:
			q.y = RIVER_BOT + 40.0
	q.y = clampf(q.y, top_y + 10.0, H - 30.0)
	return q


func dodge_target() -> Variant:
	if riding:
		return null
	for st in strikes:
		if pos.distance_to(st["pos"]) < float(st["r"]) + 50.0:
			var best = null
			var best_score := -1.0e9
			for k in 12:
				var a := TAU * k / 12.0
				var c := clamp_land(pos + Vector2(cos(a), sin(a)) * (float(st["r"]) + 70.0))
				if not spot_safe(c) or not segment_safe(pos, c):
					continue
				var sc := c.distance_to(st["pos"])
				if sc > best_score:
					best_score = sc
					best = c
			if best != null:
				return best
	return null


func route_around(dest: Vector2) -> Vector2:
	var circles := hazard_circles()
	var d := dest
	# Un objectif situé dans une zone dangereuse est repoussé vers l'extérieur.
	for c in circles:
		var dd: float = d.distance_to(c["p"])
		if dd < float(c["r"]):
			var out: Vector2 = (d - c["p"]).normalized() if dd > 1.0 else Vector2.UP
			d = c["p"] + out * (float(c["r"]) + 2.0)
	for it in 6:
		var seg := d - pos
		var l2 := seg.length_squared()
		if l2 < 1.0:
			break
		var hit = null
		var best_t := 1.0e9
		for c in circles:
			var tt := clampf((c["p"] - pos).dot(seg) / l2, 0.0, 1.0)
			var cp := pos + seg * tt
			if cp.distance_to(c["p"]) < float(c["r"]) and tt < best_t:
				best_t = tt
				hit = c
		if hit == null:
			break
		var dir := seg.normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var closest := pos + seg * clampf((hit["p"] - pos).dot(seg) / l2, 0.0, 1.0)
		var pref := 1.0 if nrm.dot(closest - hit["p"]) >= 0.0 else -1.0
		var wp := Vector2.ZERO
		var best_cost := 1.0e9
		for sd in [pref, -pref]:
			var cand := fix_wp(hit["p"] + nrm * sd * (float(hit["r"]) + 24.0))
			var cost := pos.distance_to(cand) + cand.distance_to(d)
			if not spot_safe(cand):
				cost += 5000.0
			if cost < best_cost:
				best_cost = cost
				wp = cand
		d = wp
	return d


# --- Dessin des pièges (cachés tant qu'ils n'ont pas servi) ---
func draw_traps() -> void:
	var show_all := solution_on() and state == "play"
	for i in traps.size():
		var tr: Dictionary = traps[i]
		var c: Vector2 = tr["pos"]
		if tr["k"] == "spike":
			var ph := int(tr["ph"])
			if ph >= 1 or shown.has(i) or show_all:
				if ph == 1:
					draw_circle(c, 22.0 + sin(t * 60.0) * 2.0, Color(0.1, 0.07, 0.04, 0.55))
				elif ph == 2 or shown.has(i):
					draw_circle(c, 30.0, Color(0.1, 0.07, 0.04, 0.5))
					for k in 7:
						var sp := c + Vector2(cos(k * TAU / 7.0), sin(k * TAU / 7.0)) * (0.0 if k == 0 else 17.0)
						draw_colored_polygon(PackedVector2Array([sp + Vector2(-6, 6), sp + Vector2(6, 6), sp + Vector2(0, -22)]), Color(0.85, 0.87, 0.92))
				if show_all and ph != 2:
					draw_arc(c, 40.0, 0.0, TAU, 28, Color(1.0, 0.3, 0.3, 0.85), 3.0)
			continue
		if not (shown.has(i) or show_all):
			continue
		if tr["k"] == "bear":
			draw_circle(c + Vector2(0, 5), 30.0, Color(0, 0, 0, 0.3))
			draw_circle(c, 27.0, Color(0.36, 0.37, 0.42))
			draw_circle(c, 20.0, Color(0.16, 0.16, 0.2))
			var closed := i == hit_trap
			if closed:
				draw_line(c + Vector2(-24, 0), c + Vector2(24, 0), Color(0.82, 0.83, 0.88), 6.0)
				for k in 6:
					var tx := -20.0 + k * 8.0
					draw_colored_polygon(PackedVector2Array([c + Vector2(tx, -1), c + Vector2(tx + 4, -9), c + Vector2(tx + 8, -1)]), Color(0.9, 0.9, 0.95))
			else:
				draw_arc(c + Vector2(0, -4), 24.0, PI, TAU, 18, Color(0.82, 0.83, 0.88), 5.0)
				draw_arc(c + Vector2(0, 4), 24.0, 0.0, PI, 18, Color(0.82, 0.83, 0.88), 5.0)
		else:
			draw_circle(c, 33.0, Color(0.38, 0.26, 0.13))
			draw_circle(c, 28.0, Color(0.1, 0.06, 0.03))
			draw_circle(c + Vector2(3, 4), 18.0, Color(0, 0, 0, 0.9))
		if show_all:
			draw_arc(c, 38.0, 0.0, TAU, 28, Color(1.0, 0.3, 0.3, 0.85), 3.0)


func draw_strikes() -> void:
	for st in strikes:
		var k := clampf(st["t"] / st["warn"], 0.0, 1.0)
		var c: Vector2 = st["pos"]
		var r: float = st["r"]
		draw_circle(c, r * (0.35 + 0.65 * k), Color(0, 0, 0, 0.16 + 0.3 * k))
		if st["kind"] == "bolt":
			draw_arc(c, r, 0.0, TAU, 28, Color(0.75, 0.88, 1.0, 0.4 + 0.5 * k), 3.0)
			if k > 0.8 and int(t * 40.0) % 2 == 0:
				draw_polyline(PackedVector2Array([c + Vector2(10, -900), c + Vector2(-14, -500), c + Vector2(12, -250), c + Vector2(-8, -90), c]), Color(1, 1, 1, 0.9), 5.0)
		else:
			draw_arc(c, r, 0.0, TAU, 28, Color(1.0, 0.35, 0.25, 0.4 + 0.5 * k), 3.0)
			var h := (1.0 - k) * (1.0 - k) * 700.0
			draw_texture(tex["rock"], c - ROCK_ANCHOR + Vector2(0, -h))


# Pilotage local du robot : choisit la direction la plus proche de l'objectif
# qui évite les pièges connus, les faux fruits et les chutes annoncées.
func steer_circles() -> Array:
	var arr: Array = []
	for tr in traps:
		arr.append({"p": tr["pos"], "r": float(tr["r"]) + 26.0})
	for f in fruits:
		if f.get("fake", false) and not f["carried"]:
			arr.append({"p": f["pos"], "r": 70.0})
	for st in strikes:
		arr.append({"p": st["pos"], "r": float(st["r"]) + 34.0, "st": st})
	for b in boulders:
		var x := 0.0
		while x <= W + 30.0:
			arr.append({"p": Vector2(x, float(b["y"])), "r": 78.0, "st": b})
			x += 60.0
	return arr


func steer(dest: Vector2) -> Vector2:
	var circles := steer_circles()
	var to := dest - pos
	var dist := to.length()
	var flee := false
	var flee_st = null
	for c in circles:
		if pos.distance_to(c["p"]) < float(c["r"]):
			# On est dans une zone dangereuse : on s'en éloigne d'abord.
			if c.has("st") and c["st"].has("esc"):
				return c["st"]["esc"]
			flee_st = c.get("st", null)
			to = pos - c["p"]
			if flee_st != null and flee_st.has("dir"):
				var dyb: float = pos.y - float(c["p"].y)
				var sg := signf(dyb)
				if absf(dyb) < 8.0:
					sg = -1.0 if pos.y < RIVER_TOP else 1.0
				to = Vector2(0.0, sg)
			if to.length() < 1.0:
				to = Vector2.UP
			dist = 200.0
			flee = true
			break
	if dist < 1.0:
		return dest
	var step := minf(dist, 140.0)
	if flee:
		step = 110.0
	var drift := wind * (step / maxf(BASE_SPEED * speed_mult, 50.0))
	var base_ang := to.angle()
	var offs := [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4, 1.75, -1.75, 2.1, -2.1, 2.5, -2.5, PI]
	var best_t := dest
	var best_s := -99999.0
	for off in offs:
		var tgt: Vector2 = pos + Vector2.from_angle(base_ang + off) * step
		if off == 0.0 and step >= dist and not flee:
			tgt = dest
		var eff: Vector2 = tgt + drift
		if eff.x < 30.0 or eff.x > W - 30.0 or eff.y < top_y + 5.0 or eff.y > H - 20.0:
			continue
		if not water_solid and eff.y > RIVER_TOP - 8.0 and eff.y < RIVER_BOT + 8.0:
			continue
		var ok := true
		var seg := eff - pos
		var l2 := seg.length_squared()
		var worst := 99999.0
		for c in circles:
			var inside: bool = pos.distance_to(c["p"]) < float(c["r"])
			if inside:
				var gain := eff.distance_to(c["p"]) - pos.distance_to(c["p"]) - 5.0
				worst = minf(worst, gain)
				if gain < 0.0:
					ok = false
			else:
				var tt := clampf((c["p"] - pos).dot(seg) / maxf(l2, 1.0), 0.0, 1.0)
				var cl := (pos + seg * tt).distance_to(c["p"]) - float(c["r"])
				worst = minf(worst, cl)
				if cl < 0.0:
					ok = false
		if ok:
			if flee_st != null:
				flee_st["esc"] = tgt
			return tgt
		var sc := worst - absf(off) * 2.0
		if sc > best_s:
			best_s = sc
			best_t = tgt
	if not boulders.is_empty() and not flee:
		return pos
	return best_t


# --- Pics qui surgissent à ton passage + rochers qui roulent ---
func update_spikes(delta: float) -> void:
	for i in traps.size():
		var tr: Dictionary = traps[i]
		if tr["k"] != "spike":
			continue
		var d := pos.distance_to(tr["pos"])
		match int(tr["ph"]):
			0:
				if d < 85.0 and not riding:
					tr["ph"] = 1
					tr["pt"] = 0.0
			1:
				tr["pt"] += delta
				if tr["pt"] >= 0.3:
					tr["ph"] = 2
					tr["pt"] = 0.0
					snd("board", -6.0, 1.4)
			2:
				tr["pt"] += delta
				if not riding and d < float(tr["r"]):
					shown[i] = true
					hit_trap = i
					start_dying("pics")
					return
				if tr["pt"] >= 1.0:
					tr["ph"] = 3
					tr["pt"] = 0.0
			3:
				tr["pt"] += delta
				if tr["pt"] >= 1.5:
					tr["ph"] = 0


func update_boulders(delta: float) -> void:
	var interval := float(trap_cfg.get("b_interval", 0.0))
	if interval > 0.0:
		boulder_t -= delta
		if boulder_t <= 0.0:
			boulder_t = strike_rng.randf_range(0.7, 1.3) * interval
			spawn_boulder()
	var i := boulders.size() - 1
	while i >= 0:
		var b: Dictionary = boulders[i]
		b["t"] += delta
		if b["t"] >= b["warn"]:
			var u: float = b["t"] - b["warn"]
			b["x"] = (-70.0 if b["dir"] > 0.0 else W + 70.0) + float(b["dir"]) * 560.0 * u
			if not riding and pos.distance_to(Vector2(b["x"], b["y"])) < 46.0:
				boulders.remove_at(i)
				start_dying("rocher")
				return
			if b["x"] > W + 100.0 or b["x"] < -100.0:
				boulders.remove_at(i)
		i -= 1


func spawn_boulder() -> void:
	if riding:
		return
	# Pas de rocher quand on attend le bateau au ponton (pas d'échappatoire côté eau).
	if absf(pos.x - BOAT_X) < 110.0 and ((pos.y > RIVER_TOP - 150.0 and pos.y < RIVER_TOP + 10.0) or (pos.y > RIVER_BOT - 10.0 and pos.y < RIVER_BOT + 150.0)):
		return
	var y := pos.y + strike_rng.randf_range(-40.0, 40.0)
	if pos.y < RIVER_TOP:
		y = clampf(y, top_y + 40.0, RIVER_TOP - 45.0)
	else:
		y = clampf(y, RIVER_BOT + 45.0, H - 40.0)
	var dir := 1.0 if strike_rng.randf() < 0.5 else -1.0
	boulders.append({"y": y, "dir": dir, "t": 0.0, "warn": lerpf(1.2, 1.0, difficulty(level)) + (0.3 if speed_mult < 0.9 else 0.0), "x": -999.0})


func draw_boulders() -> void:
	for b in boulders:
		var y: float = b["y"]
		var dir: float = b["dir"]
		if b["t"] < b["warn"]:
			var k: float = b["t"] / b["warn"]
			var pulse := 0.5 + 0.5 * sin(t * 18.0)
			draw_rect(Rect2(0, y - 44.0, W, 88.0), Color(1.0, 0.15, 0.1, 0.1 + 0.18 * pulse * k))
			var ex := 30.0 if dir > 0.0 else W - 30.0
			draw_colored_polygon(PackedVector2Array([Vector2(ex, y - 26.0), Vector2(ex + dir * 40.0, y), Vector2(ex, y + 26.0)]), Color(1, 0.25, 0.2, 0.7 + 0.3 * pulse))
		else:
			var c := Vector2(b["x"], y)
			draw_circle(c + Vector2(0, 30), 36.0, Color(0, 0, 0, 0.3))
			draw_circle(c, 40.0, Color(0.5, 0.48, 0.45))
			draw_circle(c + Vector2(-8, -8), 30.0, Color(0.6, 0.58, 0.54))
			var a := t * 9.0 * dir
			draw_line(c, c + Vector2(cos(a), sin(a)) * 36.0, Color(0.3, 0.28, 0.26), 4.0)
			draw_line(c, c + Vector2(cos(a + 2.1), sin(a + 2.1)) * 30.0, Color(0.3, 0.28, 0.26), 3.0)
