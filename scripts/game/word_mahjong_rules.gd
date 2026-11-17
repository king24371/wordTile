class_name WordMahjongRules
extends RefCounted

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const VOWELS := "AEIOU"
const SIGNS := "ESWN"
const HAND_SIZE := 14
const DECK_SIZE := 124


static func make_tile(id: int, letter: String, wild: bool = false) -> Dictionary:
	return {"id": id, "letter": "" if wild else letter.to_upper(), "wild": wild}


static func make_sign_tile(id: int, sign: String) -> Dictionary:
	var normalized := sign.strip_edges().to_upper()
	return {"id": id, "sign": normalized} if SIGNS.contains(normalized) and normalized.length() == 1 else {}


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
	for sign: String in SIGNS:
		for _copy: int in 4:
			deck.append(make_sign_tile(next_id, sign))
			next_id += 1
	return deck


static func is_sign_tile(tile: Dictionary) -> bool:
	var sign := str(tile.get("sign", "")).to_upper()
	return sign.length() == 1 and SIGNS.contains(sign)


static func is_vowel_letter(letter: String) -> bool:
	var normalized := letter.strip_edges().to_upper()
	return normalized.length() == 1 and VOWELS.contains(normalized)


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
		if is_sign_tile(tile):
			return false
		if bool(tile.get("wild", false)):
			wild_count += 1
			continue
		var tile_letter := str(tile.get("letter", "")).to_upper()
		if not LETTERS.contains(tile_letter) or not needed.has(tile_letter) or int(needed[tile_letter]) <= 0:
			return false
		needed[tile_letter] = int(needed[tile_letter]) - 1
	var unmatched := 0
	for letter: String in needed:
		unmatched += int(needed[letter])
	return unmatched == wild_count


static func can_form_pair(tiles: Array, pair_letter: String = "") -> bool:
	if tiles.size() != 2:
		return false
	var sign_count := 0
	var sign_letter := ""
	for value: Variant in tiles:
		if not value is Dictionary:
			return false
		var tile: Dictionary = value
		if is_sign_tile(tile):
			sign_count += 1
			if sign_letter.is_empty():
				sign_letter = str(tile.sign).to_upper()
			elif sign_letter != str(tile.sign).to_upper():
				return false
	if sign_count > 0:
		if sign_count != tiles.size() or (not pair_letter.is_empty() and pair_letter.to_upper() != sign_letter):
			return false
		return _has_two_distinct_ids(tiles)
	var normalized := pair_letter.strip_edges().to_upper()
	var fixed_letter := ""
	var seen_ids: Dictionary = {}
	var wild_count := 0
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
		var letter := str(tile.get("letter", "")).to_upper()
		if letter.length() != 1 or not LETTERS.contains(letter):
			return false
		if fixed_letter.is_empty():
			fixed_letter = letter
		elif fixed_letter != letter:
			return false
	if fixed_letter.is_empty() and wild_count == 2:
		return normalized.is_empty() or normalized.length() == 1 and LETTERS.contains(normalized)
	if normalized.is_empty():
		normalized = fixed_letter
	if normalized.length() != 1 or not LETTERS.contains(normalized):
		return false
	for value: Variant in tiles:
		var tile: Dictionary = value
		if not bool(tile.get("wild", false)) and str(tile.get("letter", "")).to_upper() != normalized:
			return false
	return true


static func _has_two_distinct_ids(tiles: Array) -> bool:
	if tiles.size() != 2:
		return false
	var first: Dictionary = tiles[0]
	var second: Dictionary = tiles[1]
	var first_id := int(first.get("id", -1))
	var second_id := int(second.get("id", -1))
	return first_id >= 0 and second_id >= 0 and first_id != second_id


static func evaluate_declared_words(hand: Array, raw_words: Array, verified_words: Dictionary, require_verified: bool = true, melds: Array = []) -> Dictionary:
	if raw_words.is_empty():
		return {"ok": false, "reason": "至少要申報一個有效英文單字。"}
	var kan_count := 0
	for meld_value: Variant in melds:
		if meld_value is Dictionary and str(meld_value.get("kind", "")) == "kan":
			kan_count += 1
	if hand.size() - kan_count != HAND_SIZE:
		return {"ok": false, "reason": "和牌的有效牌數必須正好為 14 張（槓子按三張計）。"}
	var hand_ids: Dictionary = {}
	var letter_counts: Dictionary = {}
	var sign_counts: Dictionary = {}
	var wild_count := 0
	for value: Variant in hand:
		if not value is Dictionary:
			return {"ok": false, "reason": "手牌資料無效。"}
		var tile: Dictionary = value
		var tile_id := int(tile.get("id", -1))
		if tile_id < 0 or hand_ids.has(tile_id):
			return {"ok": false, "reason": "手牌必須由不同的實體牌組成。"}
		hand_ids[tile_id] = true
		if tile.has("sign"):
			if not is_sign_tile(tile):
				return {"ok": false, "reason": "手牌中有無效象牌。"}
			var sign := str(tile.sign).to_upper()
			sign_counts[sign] = int(sign_counts.get(sign, 0)) + 1
			continue
		if bool(tile.get("wild", false)):
			wild_count += 1
		else:
			var letter := str(tile.get("letter", "")).to_upper()
			if letter.length() != 1 or not LETTERS.contains(letter):
				return {"ok": false, "reason": "手牌中有無效字母牌。"}
			letter_counts[letter] = int(letter_counts.get(letter, 0)) + 1

	var words: Array[String] = []
	var needed: Dictionary = {}
	var total_word_letters := 0
	var seen_words: Dictionary = {}
	for value: Variant in raw_words:
		var word := str(value).strip_edges().to_upper()
		if word.is_empty():
			return {"ok": false, "reason": "逗號之間不能留空；請填入全部單字。"}
		if not is_word_shape_valid(word):
			return {"ok": false, "reason": "每個單字至少需要兩個英文字母 A–Z。"}
		if require_verified and not bool(verified_words.get(word, false)):
			return {"ok": false, "reason": "%s 尚未由外部字典 API 確認。" % word}
		seen_words[word] = int(seen_words.get(word, 0)) + 1
		words.append(word)
		total_word_letters += word.length()
		for index: int in word.length():
			var letter := word.substr(index, 1)
			needed[letter] = int(needed.get(letter, 0)) + 1

	if total_word_letters > hand.size():
		return {"ok": false, "reason": "申報單字使用的牌數超過手牌。"}
	var missing_for_words := 0
	var remaining_letters: Dictionary = {}
	for letter: String in LETTERS:
		var available := int(letter_counts.get(letter, 0))
		var required := int(needed.get(letter, 0))
		if available < required:
			missing_for_words += required - available
		else:
			remaining_letters[letter] = available - required
	if missing_for_words > wild_count:
		return {"ok": false, "reason": "空白牌數不足以補足申報單字。"}
	var remaining_wilds := wild_count - missing_for_words
	var remaining_tile_count := hand.size() - total_word_letters
	var groups := _partition_nonword_tiles(remaining_letters, remaining_wilds, sign_counts, false, [])
	if not bool(groups.get("ok", false)) or _tile_count(remaining_letters) + remaining_wilds + _tile_count(sign_counts) != remaining_tile_count:
		return {"ok": false, "reason": "未組成單字的牌須全部分成一對或相同象牌的二、三、四張組合。"}
	var duplicate_word_penalty := false
	for count_value: Variant in seen_words.values():
		if int(count_value) > 1:
			duplicate_word_penalty = true
			break
	var result := {
		"ok": true,
		"kind": "words_only" if remaining_tile_count == 0 else "words_and_sets",
		"word_count": words.size(),
		"words": words,
		"pair_letter": str(groups.get("pair", "")),
		"sign_groups": groups.get("sign_groups", []),
		"duplicate_word_penalty": duplicate_word_penalty,
		"han_penalty": 1 if duplicate_word_penalty else 0,
	}
	return result


static func _partition_nonword_tiles(letter_counts: Dictionary, wild_count: int, sign_counts: Dictionary, pair_used: bool, sign_groups: Array) -> Dictionary:
	if _tile_count(letter_counts) + wild_count + _tile_count(sign_counts) == 0:
		return {"ok": true, "pair": "", "sign_groups": sign_groups}
	for sign: String in SIGNS:
		var count := int(sign_counts.get(sign, 0))
		if count == 0:
			continue
		if count >= 4:
			var after_four := sign_counts.duplicate()
			after_four[sign] = count - 4
			var four_group := sign_groups.duplicate(true)
			four_group.append({"kind": "four_kind", "sign": sign})
			var four_result := _partition_nonword_tiles(letter_counts, wild_count, after_four, pair_used, four_group)
			if bool(four_result.get("ok", false)):
				return four_result
		if count >= 3:
			var after_three := sign_counts.duplicate()
			after_three[sign] = count - 3
			var three_group := sign_groups.duplicate(true)
			three_group.append({"kind": "three_kind", "sign": sign})
			var three_result := _partition_nonword_tiles(letter_counts, wild_count, after_three, pair_used, three_group)
			if bool(three_result.get("ok", false)):
				return three_result
		if not pair_used and count >= 2:
			var after_pair := sign_counts.duplicate()
			after_pair[sign] = count - 2
			var pair_result := _partition_nonword_tiles(letter_counts, wild_count, after_pair, true, sign_groups)
			if bool(pair_result.get("ok", false)):
				pair_result["pair"] = sign
				return pair_result
		return {"ok": false}
	for letter: String in LETTERS:
		var count := int(letter_counts.get(letter, 0))
		if count == 0:
			continue
		if not pair_used:
			if count >= 2:
				var after_pair := letter_counts.duplicate()
				after_pair[letter] = count - 2
				var natural_pair := _partition_nonword_tiles(after_pair, wild_count, sign_counts, true, sign_groups)
				if bool(natural_pair.get("ok", false)):
					natural_pair["pair"] = letter
					return natural_pair
			if wild_count > 0:
				var after_wild_pair := letter_counts.duplicate()
				after_wild_pair[letter] = count - 1
				var wild_pair := _partition_nonword_tiles(after_wild_pair, wild_count - 1, sign_counts, true, sign_groups)
				if bool(wild_pair.get("ok", false)):
					wild_pair["pair"] = letter
					return wild_pair
		return {"ok": false}
	if not pair_used and wild_count >= 2:
		var wild_pair_result := _partition_nonword_tiles(letter_counts, wild_count - 2, sign_counts, true, sign_groups)
		if bool(wild_pair_result.get("ok", false)):
			wild_pair_result["pair"] = "空白"
			return wild_pair_result
	return {"ok": false}


static func _tile_count(counts: Dictionary) -> int:
	var total := 0
	for value: Variant in counts.values():
		total += int(value)
	return total


static func find_winning_declaration(hand: Array, verified_words: Dictionary, melds: Array = []) -> Dictionary:
	var kan_count := 0
	for meld_value: Variant in melds:
		if meld_value is Dictionary and str(meld_value.get("kind", "")) == "kan":
			kan_count += 1
	if hand.size() - kan_count != HAND_SIZE:
		return {"ok": false, "reason": "需要 14 張有效牌（槓子按三張計）。"}
	var candidates: Array[String] = []
	for key: Variant in verified_words.keys():
		var word := str(key).strip_edges().to_upper()
		if bool(verified_words.get(key, false)) and is_word_shape_valid(word) and word.length() <= HAND_SIZE:
			candidates.append(word)
	candidates.sort_custom(func(a: String, b: String) -> bool: return a.length() < b.length())
	return _search_word_combinations(hand, candidates, 0, [], 0, verified_words, melds)


static func _search_word_combinations(hand: Array, candidates: Array[String], start_index: int, chosen_words: Array[String], total_length: int, verified_words: Dictionary, melds: Array) -> Dictionary:
	if total_length > 0:
		var attempt := evaluate_declared_words(hand, chosen_words, verified_words, true, melds)
		if bool(attempt.get("ok", false)):
			return attempt
	if total_length >= HAND_SIZE:
		return {"ok": false, "reason": "找不到可用字組。"}
	for index: int in range(start_index, candidates.size()):
		var word := candidates[index]
		var next_length := total_length + word.length()
		if next_length > HAND_SIZE:
			continue
		chosen_words.append(word)
		var result := _search_word_combinations(hand, candidates, index, chosen_words, next_length, verified_words, melds)
		chosen_words.pop_back()
		if bool(result.get("ok", false)):
			return result
	return {"ok": false, "reason": "找不到可用字組。"}


static func find_claiming_opponents(opponents: Array, discard_tile: Dictionary, source_seat: int, verified_words: Dictionary) -> Array[String]:
	var claimers: Array[String] = []
	for value: Variant in opponents:
		if not value is Dictionary:
			continue
		var opponent: Dictionary = value
		var seat := int(opponent.get("seat", -1))
		if seat == source_seat:
			continue
		var candidate_hand: Array = (opponent.get("hand", []) as Array).duplicate(true)
		var melds: Array = opponent.get("melds", [])
		candidate_hand.append_array(_meld_tiles(melds))
		candidate_hand.append(discard_tile)
		var kan_count := 0
		for meld_value: Variant in melds:
			if meld_value is Dictionary and str(meld_value.get("kind", "")) == "kan":
				kan_count += 1
		if candidate_hand.size() - kan_count != HAND_SIZE:
			continue
		var result := find_winning_declaration(candidate_hand, verified_words, melds)
		if bool(result.get("ok", false)):
			claimers.append(str(opponent.get("name", "對手")))
	return claimers


static func _meld_tiles(melds: Array) -> Array:
	var result: Array = []
	for value: Variant in melds:
		if not value is Dictionary:
			continue
		var tiles: Variant = value.get("tiles", [])
		if tiles is Array:
			result.append_array(tiles)
	return result
