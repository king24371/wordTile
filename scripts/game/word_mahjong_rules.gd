class_name WordMahjongRules
extends RefCounted

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const HAND_SIZE := 14


static func make_tile(id: int, letter: String, wild: bool = false) -> Dictionary:
	return {"id": id, "letter": "" if wild else letter.to_upper(), "wild": wild}


static func build_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	var next_id := 0
	for index: int in LETTERS.length():
		var letter := LETTERS.substr(index, 1)
		for _copy: int in 4:
			deck.append(make_tile(next_id, letter))
			next_id += 1
	for _blank: int in 4:
		deck.append(make_tile(next_id, "", true))
		next_id += 1
	return deck


static func is_word_shape_valid(word: String) -> bool:
	var normalized := word.strip_edges().to_upper()
	if normalized.length() < 2:
		return false
	for index: int in normalized.length():
		var codepoint := normalized.unicode_at(index)
		if codepoint < 65 or codepoint > 90:
			return false
	return true


static func can_form_word(word: String, tiles: Array) -> bool:
	var normalized := word.strip_edges().to_upper()
	if not is_word_shape_valid(normalized) or normalized.length() != tiles.size():
		return false
	var needed: Dictionary = {}
	for index: int in normalized.length():
		var letter := normalized.substr(index, 1)
		needed[letter] = int(needed.get(letter, 0)) + 1
	var wild_count := 0
	var seen_ids: Dictionary = {}
	for value: Variant in tiles:
		if not value is Dictionary:
			return false
		var tile: Dictionary = value
		var tile_id := int(tile.get("id", -1))
		if tile_id < 0 or seen_ids.has(tile_id):
			return false
		seen_ids[tile_id] = true
		if bool(tile.get("wild", false)):
			wild_count += 1
			continue
		var tile_letter := str(tile.get("letter", "")).to_upper()
		if not needed.has(tile_letter) or int(needed[tile_letter]) <= 0:
			return false
		needed[tile_letter] = int(needed[tile_letter]) - 1
	var unmatched := 0
	for letter: String in needed:
		unmatched += int(needed[letter])
	return unmatched == wild_count


static func can_form_pair(tiles: Array, pair_letter: String = "") -> bool:
	if tiles.size() != 2:
		return false
	var normalized := pair_letter.strip_edges().to_upper()
	var fixed_letter := ""
	for value: Variant in tiles:
		if not value is Dictionary:
			return false
		var tile: Dictionary = value
		if bool(tile.get("wild", false)):
			continue
		var letter := str(tile.get("letter", "")).to_upper()
		if not LETTERS.contains(letter):
			return false
		if fixed_letter.is_empty():
			fixed_letter = letter
		elif fixed_letter != letter:
			return false
	if normalized.is_empty():
		normalized = fixed_letter
	if normalized.length() != 1 or not LETTERS.contains(normalized):
		return false
	for value: Variant in tiles:
		var tile: Dictionary = value
		if not bool(tile.get("wild", false)) and str(tile.get("letter", "")).to_upper() != normalized:
			return false
	return true


static func evaluate_win(hand: Array, word_groups: Array, pair_group: Dictionary, verified_words: Dictionary) -> Dictionary:
	if hand.size() != HAND_SIZE:
		return {"ok": false, "reason": "和牌必須正好使用 14 張牌。"}
	var hand_by_id: Dictionary = {}
	for value: Variant in hand:
		if not value is Dictionary:
			return {"ok": false, "reason": "手牌資料無效。"}
		var tile: Dictionary = value
		var tile_id := int(tile.get("id", -1))
		if tile_id < 0 or hand_by_id.has(tile_id):
			return {"ok": false, "reason": "每張牌必須是不同的實體牌。"}
		hand_by_id[tile_id] = tile
	if word_groups.is_empty():
		return {"ok": false, "reason": "至少需要一個有效英文單字。"}
	var used_ids: Dictionary = {}
	var seen_words: Dictionary = {}
	var word_tile_count := 0
	for value: Variant in word_groups:
		if not value is Dictionary:
			return {"ok": false, "reason": "單字組資料無效。"}
		var group: Dictionary = value
		var word := str(group.get("word", "")).strip_edges().to_upper()
		if not is_word_shape_valid(word):
			return {"ok": false, "reason": "每個單字至少要有兩個英文字母。"}
		if seen_words.has(word):
			return {"ok": false, "reason": "同一和牌組合不能重複使用相同單字。"}
		if not bool(verified_words.get(word, false)):
			return {"ok": false, "reason": "單字尚未由外部字典 API 確認。"}
		seen_words[word] = true
		var ids: Array = group.get("tile_ids", [])
		if ids.size() != word.length():
			return {"ok": false, "reason": "單字所用牌數與字母數不相符。"}
		var group_tiles := _tiles_for_ids(hand_by_id, ids)
		if group_tiles.size() != ids.size() or not can_form_word(word, group_tiles):
			return {"ok": false, "reason": "單字與所選字母牌或百搭牌不相符。"}
		for id_value: Variant in ids:
			var tile_id := int(id_value)
			if used_ids.has(tile_id):
				return {"ok": false, "reason": "每張牌只能用在一個單字或對子中。"}
			used_ids[tile_id] = true
		word_tile_count += ids.size()
	var pair_ids: Array = pair_group.get("tile_ids", [])
	var kind := "words_only"
	if not pair_ids.is_empty():
		if pair_ids.size() != 2 or not can_form_pair(_tiles_for_ids(hand_by_id, pair_ids), str(pair_group.get("letter", ""))):
			return {"ok": false, "reason": "對子必須由兩張相同字母組成。"}
		for id_value: Variant in pair_ids:
			var tile_id := int(id_value)
			if used_ids.has(tile_id) or not hand_by_id.has(tile_id):
				return {"ok": false, "reason": "每張牌只能用一次，且對子牌必須在手牌中。"}
			used_ids[tile_id] = true
		if word_tile_count != HAND_SIZE - 2:
			return {"ok": false, "reason": "有對子時，其他 12 張牌必須全部組成有效單字。"}
		kind = "words_and_pair"
	elif word_tile_count != HAND_SIZE:
		return {"ok": false, "reason": "沒有對子時，14 張牌都必須組成有效單字。"}
	if used_ids.size() != HAND_SIZE:
		return {"ok": false, "reason": "和牌必須恰好用完 14 張手牌。"}
	return {"ok": true, "kind": kind, "word_count": word_groups.size(), "pair_letter": str(pair_group.get("letter", ""))}


static func find_claiming_opponents(opponents: Array, discard_tile: Dictionary, source_seat: int, verified_words: Dictionary) -> Array[String]:
	var claimers: Array[String] = []
	var discard_letter := str(discard_tile.get("letter", "")).to_upper()
	var discarded_blank := bool(discard_tile.get("wild", false))
	if not discarded_blank and discard_letter.is_empty():
		return claimers
	for value: Variant in opponents:
		if not value is Dictionary:
			continue
		var opponent: Dictionary = value
		if int(opponent.get("seat", -1)) == source_seat:
			continue
		var profile: Dictionary = opponent.get("profile", {})
		var wait_letter := str(profile.get("wait_letter", "")).to_upper()
		if profile.is_empty() or wait_letter.is_empty() or (not discarded_blank and wait_letter != discard_letter):
			continue
		var candidate_hand: Array = opponent.get("hand", []).duplicate()
		candidate_hand.append(discard_tile)
		var pair_ids: Array = [int(profile.get("wait_tile_id", -1)), int(discard_tile.get("id", -1))]
		var pair_letter := wait_letter if discarded_blank else discard_letter
		var pair := {"tile_ids": pair_ids, "letter": pair_letter}
		var result := evaluate_win(candidate_hand, profile.get("word_groups", []), pair, verified_words)
		if bool(result.get("ok", false)):
			claimers.append(str(opponent.get("name", "對手")))
	return claimers


static func _tiles_for_ids(hand_by_id: Dictionary, ids: Array) -> Array:
	var result: Array = []
	for value: Variant in ids:
		var tile_id := int(value)
		if not hand_by_id.has(tile_id):
			return []
		result.append(hand_by_id[tile_id])
	return result
