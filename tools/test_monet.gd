extends SceneTree
# Teste cœurs, retour en arrière, pubs et version sans pub.
func check(name: String, cond: bool) -> void:
	print(("OK   " if cond else "ECHEC"), " ", name)

func _initialize() -> void:
	DirAccess.remove_absolute("user://save.cfg")
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.begin_level(1)
	check("5 coeurs au depart", m.hearts == 5)
	m.start_play()
	for i in 5:
		m.start_play()
		m.lose("temps")
	check("0 coeur apres 5 morts", m.hearts == 0)
	check("attente ~5 min", m.heart_wait() > 290.0 and m.heart_wait() <= 300.0)
	m.state = "lose"
	m.ui_lock = 0
	m.handle_tap()
	check("sans coeur -> ecran nohearts", m.state == "nohearts")
	m.next_heart = Time.get_unix_time_from_system() - 1.0
	m._process(0.016)
	check("1 coeur apres 5 min (et retour a l'intro)", m.hearts == 1 and m.state == "intro")
	# retour en arriere
	m.ui_lock = 0
	m.try_start()
	check("jeu relance", m.state == "play")
	var steps := 0
	while steps < 900 and m.state == "play":
		var g = m.guide_target()
		if g != null:
			m.target = g
			m.has_target = true
		m.update_play(0.033)
		steps += 1
	var tl_before: float = m.time_left
	var hist_n: int = m.history.size()
	m.lose("temps")
	check("historique present (%d)" % hist_n, hist_n > 10)
	m.ui_lock = 0
	m.activate("comeback")
	check("pub de retour lancee", m.state == "ad" and m.ad_kind == "comeback")
	m.ad_left = 0.0
	m.ui_lock = 0
	m.activate("ad_done")
	check("retour en arriere : on rejoue", m.state == "play")
	check("temps regagne (%.1f -> %.1f)" % [tl_before, m.time_left], m.time_left > tl_before + 15.0)
	# passer le niveau : 2 pubs
	m.lose("temps")
	m.fail_count = 3
	m.ui_lock = 0
	var has_skip := false
	for b in m.ui_buttons():
		if b["id"] == "skip":
			has_skip = true
	check("bouton passer le niveau apres 3 morts", has_skip)
	m.activate("skip")
	m.ad_left = 0.0
	m.ui_lock = 0
	m.activate("ad_done")
	check("2e pub enchainee", m.state == "ad" and m.ad_idx == 2)
	m.ad_left = 0.0
	m.ui_lock = 0
	m.activate("ad_done")
	check("niveau passe (dusk) et debloque niveau 2", m.state == "dusk" and m.best_day >= 2)
	# pub obligatoire tous les 3 niveaux
	m.level = 3
	m.state = "win"
	m.ui_lock = 0
	m.next_after_win()
	check("pub obligatoire apres le niveau 3", m.state == "ad" and m.ad_kind == "inter" and not m.ad_cancelable)
	m.ad_left = 0.0
	m.ui_lock = 0
	m.activate("ad_done")
	check("apres la pub : jour 4", m.level == 4 and m.state == "dawn")
	m.level = 2
	m.state = "win"
	m.next_after_win()
	check("pas de pub apres le niveau 2", m.state == "dawn" and m.level == 3)
	# solution seulement en premium
	m.fail_count = 5
	check("pas de solution en gratuit", not m.solution_on())
	m.buy_premium()
	check("premium : coeurs pleins, solution", m.premium and m.hearts == 5 and m.solution_on())
	var h: int = m.hearts
	m.lose("temps")
	check("premium : pas de coeur perdu", m.hearts == h)
	m.level = 3
	m.state = "win"
	m.next_after_win()
	check("premium : pas de pub", m.state == "dawn")
	# sauvegarde
	m.save_game()
	var cfg := ConfigFile.new()
	cfg.load("user://save.cfg")
	check("sauvegarde premium", bool(cfg.get_value("game", "premium", false)))
	DirAccess.remove_absolute("user://save.cfg")
	quit()
