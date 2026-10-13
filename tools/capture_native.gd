extends SceneTree

# Native-renderer visual evidence only; tools/ is excluded from every playable export.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var capture_path := OS.get_environment("WORDTILES_CAPTURE_PATH")
	if capture_path.is_empty():
		push_error("WORDTILES_CAPTURE_PATH must name an output PNG")
		quit(1)
		return
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		push_error("Main game scene could not be loaded")
		quit(1)
		return
	var main: Control = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if OS.get_environment("WORDTILES_CAPTURE_GAME") == "1":
		main.call("_start_round")
		main.call("_draw_for_player")
	for _frame: int in 8:
		await process_frame
	await create_timer(0.25).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png(capture_path)
	print("[wordtiles-capture] %s (%s)" % [capture_path, error_string(error)])
	main.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
