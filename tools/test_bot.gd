extends SceneTree
# Un robot joue en suivant le guide de la solution : toutes les paires de lois
# doivent être gagnables dans le temps imparti, à différents jours (difficulté).
# Usage : godot --headless --path . --script tools/test_bot.gd -- <jour> <essais>

func _initialize() -> void:
	DirAccess.remove_absolute("user://save.cfg")
	var args := OS.get_cmdline_user_args()
	var test_day := 1
	var runs := 3
	if args.size() > 0:
		test_day = int(args[0])
	if args.size() > 1:
		runs = int(args[1])
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var all: Array = main.Laws.all()
	var ok := 0
	var total := 0
	var bad: Array = []
	for i in all.size():
		for j in range(i + 1, all.size()):
			if all[i]["group"] == all[j]["group"]:
				continue
			total += 1
			var wins := 0
			for run in runs:
				main.level = test_day
				main.laws = [all[i], all[j]]
				main.apply_laws()
				main.start_play()
				var steps := 0
				while main.state == "play" and steps < 8000:
					var g = main.guide_target()
					if g != null:
						main.target = g
						main.has_target = true
					main.update_play(0.033)
					steps += 1
				while main.state == "dying":
					main._process(0.1)
				if main.state == "dusk" or main.state == "win":
					wins += 1
			if wins * 2 >= runs:
				ok += 1
			if wins < runs:
				bad.append("%s + %s : %d/%d" % [all[i]["id"], all[j]["id"], wins, runs])
	# Niveaux réels 1..160 : le robot joue avec le vrai temps du niveau (3 essais)
	var wins_by_lv := {}
	var zero_lv: Array = []
	var total_w := 0
	var lv_from := 1
	if args.size() > 2:
		lv_from = int(args[2])
	for lv in range(lv_from, 161):
		var a1: Array = main.level_laws(lv)
		var a2: Array = main.level_laws(lv)
		var same: bool = a1.size() == a2.size() and a1[0]["id"] == a2[0]["id"] and a1[1]["id"] == a2[1]["id"] and a1[0]["group"] != a1[1]["group"]
		if not same:
			print("   niveau non déterministe : ", lv)
		var w := 0
		for run in 3:
			main.level = lv
			main.laws = a1
			main.apply_laws()
			main.start_play()
			var st := 0
			while main.state == "play" and st < 8000:
				var g = main.guide_target()
				if g != null:
					main.target = g
					main.has_target = true
				main.update_play(0.033)
				st += 1
			while main.state == "dying":
				main._process(0.1)
			if main.state == "dusk" or main.state == "win":
				w += 1
		wins_by_lv[lv] = w
		if w == 0:
			zero_lv.append(lv)
		if lv < 156:
			total_w += w
	print("NIVEAUX 1..155 : ", total_w, "/465 victoires du robot. Niveaux jamais gagnés : ", zero_lv)
	var imp := 0
	for lv in range(156, 161):
		imp += int(wins_by_lv[lv])
	print("NIVEAUX 156..160 (impossibles) : ", imp, "/15 victoires du robot")
	# Sauvegarde / chargement
	main.level = 3
	main.level_stars[3] = 2
	main.level_score[3] = 1234
	main.best_day = 4
	main.cur_level = 4
	main.save_game()
	main.blank_progress()
	main.best_day = 1
	main.load_save()
	print("SAUVEGARDE : best=", main.best_day, " cur=", main.cur_level, " étoiles3=", main.level_stars[3], " score3=", main.level_score[3])
	main.reset_progress()
	print("RESET : best=", main.best_day, " étoiles3=", main.level_stars[3])
	print("JOUR ", test_day, " (objectif ", main.goal, " fruits, ", main.total_time, " s) : ", ok, "/", total, " paires gagnables")
	for b in bad:
		print("   incomplet : ", b)
	DirAccess.remove_absolute("user://save.cfg")
	quit()
