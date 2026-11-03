extends SceneTree
func _initialize() -> void:
	DirAccess.remove_absolute("user://save.cfg")
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	var id1: String = m.player_id
	m.level = 3
	m.laws = m.level_laws(3)
	m.apply_laws()
	m.start_play()
	m.win_game()
	for i in 40:
		await create_timer(0.1).timeout
	m.save_game()
	m.player_id = ""
	m.load_save()
	print("ID_STABLE ", id1 == m.player_id, " ", id1.length(), " wins=", m.wins_total)
	m.share_stats = false
	m.sync_cd = 0.0
	m.sync_stats(true)
	quit()
