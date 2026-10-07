extends SceneTree
## Screenshots of each part of the game, for checking the look by eye.
## godot --path . -s tests/shots.gd -- --shots=<dir> [--portrait]

var main: Node
var out := "user://shots"
var portrait := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			out = arg.trim_prefix("--shots=")
		if arg == "--portrait":
			portrait = true
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(540, 1170) if portrait else Vector2i(1280, 720))
	main = load("res://main.tscn").instantiate()
	main.saving = false
	root.add_child(main)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s%s.png" % [out, name, "_p" if portrait else ""])


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	await _wait(1.5)
	await _snap("1_title")
	main.start_game()
	_tough()
	await _wait(5.0)
	await _snap("2_wave1")
	main.player.goal_x = 9.0
	await _wait(0.45)
	await _snap("2_run")
	main.levels = {"jump": 1, "dash": 1}
	main.player.apply(main.levels)
	main.player.jump()
	await _wait(0.3)
	await _snap("2_jump")
	await _wait(1.0)
	for x: float in [-37.7, 56.6]:
		main.player.x = x
		main.player.goal_x = x
		await _wait(2.0)
		await _snap("2_at_%d" % int(x))
	main.player.x = 0.0
	main.player.goal_x = 0.0
	# Round the back of town by the shortcut
	main.player.goal_z = -16.3
	await _wait(2.6)
	await _snap("2_back")
	main.player.z = 0.0
	main.player.goal_z = 0.0
	await _wait(1.5)

	# A mid-run city with most of the defenses up
	main.levels = {"flak": 3, "blucifer": 2, "dome": 3, "battery": 2, "tesla": 2, "hail": 2, "twin": 2, "chile": 1, "mech": 1, "drone": 2, "rockets": 1, "cow": 1, "watchtower": 1, "wall": 2, "summit": 1}
	main.player.apply(main.levels)
	main.defenses.sync(main.levels)
	main.wave = 6
	main._next_wave()
	_tough()
	main.hurt_building(main.city.by_id("cash"), 4, Vector3.ZERO)
	main.hurt_building(main.city.by_id("union"), 9, Vector3.ZERO)
	main.hurt_building(main.city.by_id("qwest"), 2, Vector3.ZERO)
	await _wait(5.5)
	await _snap("3_defenses")
	await _wait(1.7)
	await _snap("3b_defenses")

	main.swarm.clear()
	main.shots.clear()
	await _wait(2.8)
	await _snap("4_cards")
	main.pick_card(0)
	main.wave = 9
	main._next_wave()
	_tough()
	await _wait(9.0)
	await _snap("5_boss")
	main.player.hearts = 0
	await _wait(1.6)
	await _snap("6_over")
	quit()


## The robot aims for itself now, so the wave has to outlast the camera.
func _tough() -> void:
	for a in main.swarm.aliens:
		a.hp = 99999.0


func _process(_delta: float) -> bool:
	if main != null and is_instance_valid(main):
		_tough()
	return false
