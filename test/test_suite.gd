extends Node

const Rules := preload("res://scripts/game/word_mahjong_rules.gd")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_deck_and_vowels()
	_test_declared_word_wins()
	_test_real_hand_claims()
	await _test_runtime_loop()
	if _failures.is_empty():
		print("[wordtiles-tests] PASS: %d deck, declaration, claim, UI and live turn checks" % _checks)
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("[wordtiles-tests] " + failure)
		get_tree().quit(1)


func _test_deck_and_vowels() -> void:
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
	for vowel: String in Rules.VOWELS:
		_check(Rules.is_vowel_letter(vowel), "%s is treated as a red vowel" % vowel)
	_check(not Rules.is_vowel_letter("B") and not Rules.is_vowel_letter("Y"), "consonants are not classified as vowels")
	var word_tiles: Array = [Rules.make_tile(900, "C"), Rules.make_tile(901, "A"), Rules.make_tile(902, "T"), Rules.make_tile(903, "", true)]
	_check(Rules.can_form_word("CATS", word_tiles), "a blank can stand for a missing word letter irrespective of tile order")
	_check(not Rules.can_form_word("CAT", word_tiles), "word tile count must equal word length")
	_check(not Rules.is_word_shape_valid("A"), "one-letter words are not allowed")
	_check(not Rules.can_form_pair([Rules.make_tile(910, "A"), Rules.make_tile(911, "A"), Rules.make_tile(912, "A")]), "three identical letters are not a pair or special hand")
	_check(Rules.can_form_pair([Rules.make_tile(913, "A"), Rules.make_tile(914, "", true)], "A"), "a blank can form a specified matching pair")


func _test_declared_word_wins() -> void:
	var verified := {"GAME": true, "WORD": true, "TILE": true, "CAT": true, "TREE": true, "JOURNEY": true, "EAT": true}
	var with_pair := _make_word_hand(["GAME", "WORD", "TILE"], "A", 100)
	var result: Dictionary = Rules.evaluate_declared_words(with_pair, ["GAME", "WORD", "TILE"], verified)
	_check(bool(result.get("ok", false)) and str(result.get("kind", "")) == "words_and_pair", "12 verified word tiles plus one matching pair win")
	var with_wild_pair := _make_word_hand(["GAME", "WORD", "TILE"], "A", 200, true)
	result = Rules.evaluate_declared_words(with_wild_pair, ["GAME", "WORD", "TILE"], verified)
	_check(bool(result.get("ok", false)) and str(result.get("pair_letter", "")) == "A", "a blank may complete the inferred matching pair")
	var all_words := _make_word_hand(["TREE", "EAT", "JOURNEY"], "", 300)
	result = Rules.evaluate_declared_words(all_words, ["TREE", "EAT", "JOURNEY"], verified)
	_check(bool(result.get("ok", false)) and str(result.get("kind", "")) == "words_only", "all 14 tiles made of words need no pair")
	var repeated := _make_word_hand(["CAT", "CAT", "GAME", "TILE"], "", 400)
	result = Rules.evaluate_declared_words(repeated, ["CAT", "CAT", "GAME", "TILE"], verified)
	_check(not bool(result.get("ok", false)), "the same word cannot be repeated in one declared hand")
	result = Rules.evaluate_declared_words(with_pair, ["GAME", "WORD", "TILE"], {})
	_check(not bool(result.get("ok", false)), "words absent from the external verification cache cannot win")
	result = Rules.evaluate_declared_words(with_pair, ["GAME", "", "TILE"], verified, false)
	_check(not bool(result.get("ok", false)), "an empty comma-separated declaration is rejected")
	var short_hand: Array = with_pair.slice(0, 13)
	result = Rules.evaluate_declared_words(short_hand, ["GAME", "WORD", "TILE"], verified)
	_check(not bool(result.get("ok", false)), "a 13-tile hand cannot be declared a win")
	result = Rules.find_winning_declaration(with_wild_pair, verified)
	_check(bool(result.get("ok", false)), "automatic opponent win detection uses the same verified hand rules")


func _test_real_hand_claims() -> void:
	var first := {"name": "青竹", "seat": 1, "hand": _make_waiting_hand(600)}
	var second := {"name": "墨玉", "seat": 2, "hand": _make_waiting_hand(700)}
	var third := {"name": "金雀", "seat": 3, "hand": _make_waiting_hand(800)}
	var cache := {"GAME": true, "WORD": true, "TILE": true}
	var discarded_a := Rules.make_tile(999, "A")
	var winners: Array = Rules.find_claiming_opponents([first, second, third], discarded_a, 3, cache)
	_check(winners.size() == 2 and winners.has("青竹") and winners.has("墨玉"), "two genuinely complete hands can claim the same discard")
	var discarded_blank := Rules.make_tile(1000, "", true)
	var blank_winners: Array = Rules.find_claiming_opponents([first, second, third], discarded_blank, 3, cache)
	_check(blank_winners.size() == 2, "a blank can be claimed only when the actual remaining hand forms a verified win")
	var safe_deck := Rules.build_deck()
	var safe_hand: Array = safe_deck.slice(0, 13)
	var random_bot := {"name": "普通對手", "seat": 1, "hand": safe_hand}
	var no_automatic_win: Array = Rules.find_claiming_opponents([random_bot], discarded_blank, 0, cache)
	_check(no_automatic_win.is_empty(), "a random opening hand does not automatically win on a blank discard")
	var own_discard: Array = Rules.find_claiming_opponents([first, second, third], discarded_a, 1, cache)
	_check(not own_discard.has("青竹") and own_discard.has("墨玉") and own_discard.has("金雀"), "a discarder cannot claim their own tile")
	var fail_closed: Array = Rules.find_claiming_opponents([first, second, third], discarded_a, 3, {})
	_check(fail_closed.is_empty(), "opponent claims require externally verified words")


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
	var wall: Array = main.get("_deck")
	_check(hand.size() == 13, "new round deals 13 player tiles")
	_check(opponents.size() == 3, "single-player table has three simulated opponents")
	_check(opponents.all(func(opponent: Dictionary) -> bool: return (opponent.get("hand", []) as Array).size() == 13), "each simulated opponent starts with 13 tiles")
	_check(opponents.all(func(opponent: Dictionary) -> bool: return not opponent.has("profile")), "bots do not carry fixed prearranged winning profiles")
	_check(wall.size() == 56, "the undealt wall contains 56 tiles after four hands")
	var every_tile: Array = hand.duplicate()
	for opponent: Dictionary in opponents:
		every_tile.append_array(opponent.get("hand", []))
	every_tile.append_array(wall)
	_check(every_tile.size() == 108, "all players and wall are dealt from one complete 108-tile deck")
	var dealt_ids: Dictionary = {}
	var dealt_letters: Dictionary = {}
	var dealt_vowels := 0
	for tile_value: Variant in every_tile:
		var tile: Dictionary = tile_value
		var id := int(tile.get("id", -1))
		_check(not dealt_ids.has(id), "a physical tile is dealt exactly once")
		dealt_ids[id] = true
		if bool(tile.get("wild", false)):
			continue
		var letter := str(tile.get("letter", ""))
		dealt_letters[letter] = int(dealt_letters.get(letter, 0)) + 1
		if Rules.is_vowel_letter(letter):
			dealt_vowels += 1
	_check(dealt_vowels == 20, "all 20 vowel tiles remain in fair shared dealing")
	for letter: String in Rules.LETTERS:
		_check(int(dealt_letters.get(letter, 0)) == 4, "all four %s tiles remain in the shared deal" % letter)
	var vowel_button: Button = main.call("_make_tile_button", Rules.make_tile(7000, "A"), false, false)
	_check(vowel_button.get_theme_color("font_color") == Color("#e98f7b"), "vowel tile face uses red lettering")
	vowel_button.free()
	var original_hand: Array = (main.get("_hand") as Array).duplicate(true)
	var source_id := int(original_hand[0].get("id", -1))
	var target_id := int(original_hand[2].get("id", -1))
	main.call("_reorder_hand_tile", source_id, target_id, false)
	var reordered_hand: Array = main.get("_hand")
	_check(int(reordered_hand[1].get("id", -1)) == source_id and int(reordered_hand[2].get("id", -1)) == target_id, "the player can manually reorder tiles without word groups")
	var safe_deck := Rules.build_deck()
	var safe_hand: Array = safe_deck.slice(0, 13)
	var safe_opponents: Array[Dictionary] = []
	for index: int in 3:
		var bot_hand: Array = _make_waiting_hand(600 + index * 100) if index == 0 else safe_hand.duplicate(true)
		safe_opponents.append({"name": ["青竹", "墨玉", "金雀"][index], "seat": index + 1, "hand": bot_hand})
	main.set("_opponents", safe_opponents)
	main.call("_draw_for_player")
	hand = main.get("_hand")
	_check(hand.size() == 14 and str(main.get("_phase")) == "player_discard", "drawing changes the player hand from 13 to 14")
	main.call("_claim_win")
	_check(bool(main.get("_win_form_open")), "win declaration opens only when the player claims to win")
	var entry: LineEdit = main.get("_win_words_entry")
	entry.text = "GAME,WORD,TILE"
	main.call("_verify_win_submission")
	_check(str(main.get("_phase")) != "result", "a hand mismatch does not end the round")
	main.call("_close_win_form")
	if hand.size() == 14:
		var chosen: Dictionary = hand[0]
		main.call("_on_tile_pressed", int(chosen.get("id", -1)))
		main.call("_discard_selected")
		_check((main.get("_hand") as Array).size() == 13, "discarding returns the player hand to 13")
		_check((main.get("_discards") as Array).size() == 1, "discard is placed in the central discard area")
	main.set("_phase", "result")
	await get_tree().process_frame
	var eat_hand: Array = safe_hand.duplicate(true)
	var eat_tile := Rules.make_tile(8000, "A")
	main.set("_hand", eat_hand)
	main.set("_phase", "claim")
	main.set("_claim_tile", eat_tile)
	main.set("_pending_bot_winners", ["青竹"])
	var one_discard: Array[Dictionary] = [eat_tile]
	main.set("_discards", one_discard)
	main.call("_refresh_all")
	var eat_button: Button = main.get("_eat_button")
	_check(not eat_button.disabled, "free eating remains available even when a bot can claim a genuine win")
	main.call("_eat_discard")
	_check((main.get("_hand") as Array).size() == 14 and str(main.get("_phase")) == "player_discard", "eating any discard is allowed, with a required discard afterward")
	_check((main.get("_pending_bot_winners") as Array).is_empty(), "eating claims the discard; passing instead allows the verified bot win")
	var reveal_tile := Rules.make_tile(8001, "A")
	main.call("_finish_round", ["青竹", "墨玉"], "搶胡", {}, reveal_tile)
	var revealed_bamboo: Array = main.call("_hand_for_result", "青竹")
	var revealed_jade: Array = main.call("_hand_for_result", "墨玉")
	var revealed_bird: Array = main.call("_hand_for_result", "金雀")
	_check(revealed_bamboo.size() == 14 and revealed_jade.size() == 14, "each discard winner is shown with the claimed winning tile")
	_check(revealed_bird.size() == 13 and (main.call("_hand_for_result", "你") as Array).size() == 14, "the result exposes all four players' actual hands")
	var result_text: RichTextLabel = main.get("_result_hands_label")
	_check(result_text.text.contains("全員手牌公開") and result_text.text.contains("青竹") and result_text.text.contains("墨玉") and result_text.text.contains("金雀"), "the result UI visibly lists every player's hand")
	main.free()
	await get_tree().process_frame


func _make_word_hand(words: Array, pair_letter: String, start_id: int, pair_wild: bool = false) -> Array[Dictionary]:
	var hand: Array[Dictionary] = []
	var next_id := start_id
	for word_value: Variant in words:
		var word := str(word_value)
		for index: int in word.length():
			hand.append(Rules.make_tile(next_id, word.substr(index, 1)))
			next_id += 1
	if not pair_letter.is_empty():
		hand.append(Rules.make_tile(next_id, pair_letter))
		next_id += 1
		if pair_wild:
			hand.append(Rules.make_tile(next_id, "", true))
		else:
			hand.append(Rules.make_tile(next_id, pair_letter))
		next_id += 1
	return hand


func _make_waiting_hand(start_id: int) -> Array[Dictionary]:
	var hand: Array[Dictionary] = []
	var next_id := start_id
	for word: String in ["GAME", "WORD", "TILE"]:
		for index: int in word.length():
			hand.append(Rules.make_tile(next_id, word.substr(index, 1)))
			next_id += 1
	hand.append(Rules.make_tile(next_id, "A"))
	return hand


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
