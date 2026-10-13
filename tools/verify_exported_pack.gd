extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	_check(ProjectSettings.get_setting("application/config/name") == "Word Tiles｜英文麻將", "game identity")
	for path: String in [
		"res://assets/share/favicon.png",
		"res://assets/template/fonts/ui_regular.tres",
		"res://assets/template/fonts/ui_bold.tres",
		"res://localization/zh-Hant.json",
		"res://scripts/game/word_mahjong_rules.gd",
		"res://scripts/game/word_dictionary_service.gd",
	]:
		_check(ResourceLoader.exists(path), "pack resource: " + path)
	_check(not ResourceLoader.exists("res://test/test_suite.tscn"), "developer test scene excluded")
	_check(not ResourceLoader.exists("res://tools/capture_native.gd"), "native capture tool excluded")
	_check(not ResourceLoader.exists("res://autoload/global_leaderboard.gd"), "no retired network leaderboard")
	_check(not root.has_node("GlobalLeaderboard"), "no dormant network autoload")
	_check(not ResourceLoader.exists("res://scripts/ui/tuning_panel.gd"), "no duplicate native Tweak panel")
	_check(not DirAccess.dir_exists_absolute("res://assets/template/generated"), "no retired creative assets")
	var font := load("res://assets/template/fonts/ui_regular.tres") as Font
	_check(font != null, "exported body font")
	var catalog_path := "res://localization/zh-Hant.json"
	_check(FileAccess.file_exists(catalog_path), "exported Traditional Chinese catalog")
	if FileAccess.file_exists(catalog_path):
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		for value: String in catalog.values():
			for index: int in value.length():
				var codepoint := value.unicode_at(index)
				if codepoint >= 32:
					_check(font != null and font.has_char(codepoint), "exported glyph: %d" % codepoint)
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "exported main scene")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		_check(str(main.get("_phase")) == "title", "pack boots to the Word Tiles title")
		main.call("_start_round")
		await process_frame
		_check((main.get("_hand") as Array).size() == 13, "pack deals 13 player tiles")
		_check((main.get("_opponents") as Array).size() == 3, "pack creates three simulated opponents")
		_check((main.get("_deck") as Array).size() == 56, "pack wall count after initial deal")
		main.call("_draw_for_player")
		_check((main.get("_hand") as Array).size() == 14, "pack draw produces 14 tiles")
		var selected: Dictionary = (main.get("_hand") as Array)[0]
		main.call("_on_tile_pressed", int(selected.id))
		main.call("_discard_selected")
		_check((main.get("_hand") as Array).size() == 13, "pack discard returns to 13 tiles")
		_check((main.get("_discards") as Array).size() == 1, "pack records a discarded tile")
		main.queue_free()
		await process_frame
	if _failures.is_empty():
		print("[exported-pack] PASS: identity, API/rules resources, icon, Traditional Chinese, title, deal, draw and discard")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("[exported-pack] " + failure)
		quit(1)


func _check(condition: bool, context: String) -> void:
	if not condition and context not in _failures:
		_failures.append(context)
