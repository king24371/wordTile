extends Node

const Rules := preload("res://scripts/game/word_mahjong_rules.gd")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_deck_and_word_matching()
	_test_win_shapes_and_uniqueness()
	_test_multiple_claims()
	await _test_runtime_loop()
	if _failures.is_empty():
		print("[wordtiles-tests] PASS: %d rule, claim, language and live turn checks" % _checks)
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("[wordtiles-tests] " + failure)
		get_tree().quit(1)


func _test_deck_and_word_matching() -> void:
	var deck := Rules.build_deck()
	_check(deck.size() == 108, "deck has exactly 108 tiles")
	var letter_counts: Dictionary = {}
	var blank_count := 0
	var ids: Dictionary = {}
	for tile: Dictionary in deck:
		var tile_id := int(tile.get("id", -1))
		_check(not ids.has(tile_id), "every physical tile has a unique id")
		ids[tile_id] = true
		if bool(tile.get("wild", false)):
			blank_count += 1
		else:
			var letter := str(tile.get("letter", ""))
			letter_counts[letter] = int(letter_counts.get(letter, 0)) + 1
	_check(blank_count == 4, "deck has four blanks")
	_check(letter_counts.size() == 26, "deck contains all 26 letters")
	for letter: String in Rules.LETTERS:
		_check(int(letter_counts.get(letter, 0)) == 4, "%s has four copies" % letter)
	var word_tiles: Array = [Rules.make_tile(900, "C"), Rules.make_tile(901, "A"), Rules.make_tile(902, "T"), Rules.make_tile(903, "", true)]
	_check(Rules.can_form_word("CATS", word_tiles), "a blank can stand for a missing word letter irrespective of tile order")
	_check(not Rules.can_form_word("CAT", word_tiles), "word tile count must equal word length")
	_check(not Rules.is_word_shape_valid("A"), "one-letter words are not allowed")
	_check(not Rules.can_form_pair([Rules.make_tile(910, "A"), Rules.make_tile(911, "A"), Rules.make_tile(912, "A")]), "three identical letters are not a pair or special hand")
	_check(Rules.can_form_pair([Rules.make_tile(913, "A"), Rules.make_tile(914, "", true)], "A"), "a blank can form a specified matching pair")


func _test_win_shapes_and_uniqueness() -> void:
	var verified := {"GAME": true, "WORD": true, "TILE": true, "CAT": true, "TREE": true, "JOURNEY": true}
	var with_pair := _make_grouped_hand(["GAME", "WORD", "TILE"], "A", 100)
	var result: Dictionary = Rules.evaluate_win(with_pair.hand, with_pair.groups, with_pair.pair, verified)
	_check(bool(result.get("ok", false)) and str(result.get("kind", "")) == "words_and_pair", "12 verified word tiles plus one matching pair win")
	var all_words := _make_grouped_hand(["CAT", "TREE", "JOURNEY"], "", 200)
	result = Rules.evaluate_win(all_words.hand, all_words.groups, all_words.pair, verified)
	_check(bool(result.get("ok", false)) and str(result.get("kind", "")) == "words_only", "14 tiles made entirely of words need no pair; shared letters across words are allowed")
	var repeated := _make_grouped_hand(["CAT", "CAT", "GAME", "TILE"], "", 300)
	result = Rules.evaluate_win(repeated.hand, repeated.groups, repeated.pair, {"CAT": true, "GAME": true, "TILE": true})
	_check(not bool(result.get("ok", false)), "the same word cannot be repeated in one winning hand")
	var unverified := _make_grouped_hand(["GAME", "WORD", "TILE"], "A", 400)
	result = Rules.evaluate_win(unverified.hand, unverified.groups, unverified.pair, {})
	_check(not bool(result.get("ok", false)), "words absent from the external verification cache cannot win")
	var short_hand: Array = with_pair.hand.slice(0, 13)
	result = Rules.evaluate_win(short_hand, with_pair.groups, with_pair.pair, verified)
	_check(not bool(result.get("ok", false)), "a 13-tile hand cannot be declared a win")
	var reused: Array = with_pair.groups.duplicate(true)
	var first_ids: Array = reused[0].tile_ids
	var second_ids: Array = reused[1].tile_ids
	second_ids[0] = first_ids[0]
	reused[1].tile_ids = second_ids
	result = Rules.evaluate_win(with_pair.hand, reused, with_pair.pair, verified)
	_check(not bool(result.get("ok", false)), "a physical tile cannot be reused across private groups")


func _test_multiple_claims() -> void:
	var first := _make_waiting_profile("青竹", 1, 600)
	var second := _make_waiting_profile("墨玉", 2, 700)
	var third := _make_waiting_profile("金雀", 3, 800)
	var discarded_a := Rules.make_tile(999, "A")
	var cache := {"GAME": true, "WORD": true, "TILE": true, "MOON": true, "SING": true, "TREE": true}
	var winners: Array = Rules.find_claiming_opponents([first, second, third], discarded_a, 3, cache)
	_check(winners.size() == 2 and winners.has("青竹") and winners.has("墨玉"), "two opponents can win simultaneously on the same discard")
	var discarded_blank := Rules.make_tile(1000, "", true)
	var blank_winners: Array = Rules.find_claiming_opponents([first, second, third], discarded_blank, 3, cache)
	_check(blank_winners.size() == 2, "discarded blanks can be assigned to the opponents' winning letter")
	var self_discard_winners: Array = Rules.find_claiming_opponents([first, second, third], discarded_a, 1, cache)
	_check(not self_discard_winners.has("青竹") and self_discard_winners.has("墨玉"), "a discarder cannot claim its own discard")
	var fail_closed: Array = Rules.find_claiming_opponents([first, second, third], discarded_a, 3, {})
	_check(fail_closed.is_empty(), "opponent claims require API-verified words")


func _test_runtime_loop() -> void:
	_check(I18n.get_locale() == "zh-Hant", "game uses the pinned Traditional Chinese locale")
	I18n.set_locale("en")
	_check(I18n.get_locale() == "zh-Hant", "saved or requested locale changes cannot switch this single-language game")
	var font := load("res://assets/template/fonts/ui_regular.tres") as Font
	_check(font != null, "bundled body font is present")
	if font != null:
		for character: String in ["麻", "將", "單", "字", "摸", "牌", "和", "組"]:
			_check(font.has_char(character.unicode_at(0)), "font covers Traditional Chinese UI glyph %s" % character)
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main game scene loads")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	_check(str(main.get("_phase")) == "title", "game boots to its own title screen")
	main.call("_start_round")
	await get_tree().process_frame
	var hand: Array = main.get("_hand")
	var opponents: Array = main.get("_opponents")
	_check(hand.size() == 13, "new round deals 13 player tiles")
	_check(opponents.size() == 3, "single-player table has three simulated opponents")
	_check(opponents.all(func(opponent: Dictionary) -> bool: return (opponent.get("hand", []) as Array).size() == 13), "each simulated opponent starts with 13 tiles")
	_check((main.get("_deck") as Array).size() == 56, "the undealt wall contains 56 tiles after 4 hands")
	main.call("_draw_for_player")
	hand = main.get("_hand")
	_check(hand.size() == 14 and str(main.get("_phase")) == "player_discard", "drawing changes the player hand from 13 to 14")
	if hand.size() == 14:
		var chosen: Dictionary = hand[0]
		main.call("_on_tile_pressed", int(chosen.id))
		main.call("_discard_selected")
		_check((main.get("_hand") as Array).size() == 13, "discarding returns the player hand to 13")
		_check((main.get("_discards") as Array).size() == 1, "discard is placed in the central discard area")
	main.queue_free()
	await get_tree().process_frame


func _make_grouped_hand(words: Array, pair_letter: String, start_id: int) -> Dictionary:
	var hand: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	var next_id := start_id
	for word_value: Variant in words:
		var word := str(word_value)
		var ids: Array[int] = []
		for index: int in word.length():
			var tile := Rules.make_tile(next_id, word.substr(index, 1))
			hand.append(tile)
			ids.append(next_id)
			next_id += 1
		groups.append({"word": word, "tile_ids": ids})
	var pair: Dictionary = {}
	if not pair_letter.is_empty():
		var pair_ids: Array[int] = []
		for _copy: int in 2:
			hand.append(Rules.make_tile(next_id, pair_letter))
			pair_ids.append(next_id)
			next_id += 1
		pair = {"tile_ids": pair_ids, "letter": pair_letter}
	return {"hand": hand, "groups": groups, "pair": pair}


func _make_waiting_profile(name: String, seat: int, start_id: int) -> Dictionary:
	var grouped := _make_grouped_hand(["GAME", "WORD", "TILE"], "", start_id)
	var wait_id := start_id + 12
	var wait_tile := Rules.make_tile(wait_id, "A")
	grouped.hand.append(wait_tile)
	return {
		"name": name,
		"seat": seat,
		"hand": grouped.hand,
		"profile": {"word_groups": grouped.groups, "wait_tile_id": wait_id, "wait_letter": "A"},
	}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
