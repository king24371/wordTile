extends Control

const Rules := preload("res://scripts/game/word_mahjong_rules.gd")
const DictionaryService := preload("res://scripts/game/word_dictionary_service.gd")
const HandTileButton := preload("res://scripts/ui/hand_tile_button.gd")
const UI_FONT := "res://assets/template/fonts/ui_regular.tres"
const UI_BOLD := "res://assets/template/fonts/ui_bold.tres"
const SIGN_FACE_PATHS := {
	"E": "res://assets/share/Fire.png",
	"S": "res://assets/share/Wing.png",
	"W": "res://assets/share/Water.png",
	"N": "res://assets/share/Land.png",
}
const BOT_SEED_WORDS := ["GAME", "WORD", "TILE", "MOON", "SING", "TREE", "FISH", "BURN", "JULY", "PAIR", "RUG", "FAT", "VICE"]
const BOT_NAMES := ["青竹", "墨玉", "金雀"]
const BG := Color("#08231e")
const SURFACE := Color("#10372e")
const SURFACE_DARK := Color("#0b2c25")
const BORDER := Color("#416b57")
const GOLD := Color("#dfbd78")
const GOLD_DARK := Color("#9b7740")
const CREAM := Color("#f4eedf")
const TEXT := Color("#f5f4ec")
const MUTED := Color("#b6c9bb")
const TEAL := Color("#86c6a6")
const RED := Color("#e98f7b")
const TILE_WIDTH := 66.0
const TILE_HEIGHT := 92.0

var _dictionary: Node
var _rng := RandomNumberGenerator.new()
var _deck: Array[Dictionary] = []
var _hand: Array[Dictionary] = []
var _melds: Array[Dictionary] = []
var _opponents: Array[Dictionary] = []
var _discards: Array[Dictionary] = []
var _selected_ids: Array[int] = []
var _word_groups: Array[Dictionary] = []
var _box_selected_ids: Array[int] = []
var _pending_group_ids: Array[int] = []
var _active_group_request_id := 0
var _group_checks_remaining := 0
var _grouping_claim_tile: Dictionary = {}
var _grouping_claim_source := -1
var _group_request_sequence := 0
var _box_selecting := false
var _box_start := Vector2.ZERO
var _box_end := Vector2.ZERO
var _selection_box: Panel
var _claim_tile: Dictionary = {}
var _claim_source_seat := -1
var _pending_bot_winners: Array[String] = []
var _pending_next_seat := 0
var _round_number := 0
var _phase := "title"
var _status_text := ""
var _dictionary_status := "正在連線外部字典……"
var _bot_seed_completed := 0
var _bot_seed_failed := 0
var _bot_seed_total := BOT_SEED_WORDS.size()
var _last_win: Dictionary = {}
var _last_win_tile: Dictionary = {}
var _last_winners: Array[String] = []
var _last_reason := ""
var _help_open := false
var _eat_han_penalty := 0
var _has_eaten := false
var _riichi_declared := false
var _riichi_wait_types: Array[String] = []
var _fixet_prompt_wait_types: Array[String] = []
var _fixet_prompt_active := false
var _fixet_prompt_hand_ids: Array[int] = []
var _fixet_scan_active := false
var _fixet_scan_id := 0
var _fixet_scan_hand_ids: Array[int] = []
var _fixet_scan_wait_types: Array[String] = []
var _fixet_scan_patterns_remaining := 0
var _fixet_scan_words_remaining := 0
var _fixet_pattern_contexts: Dictionary = {}

var _theme_resource: Theme
var _title_view: Control
var _game_view: Control
var _result_overlay: Control
var _help_overlay: Control
var _start_button: Button
var _status_label: Label
var _dictionary_label: Label
var _wall_label: Label
var _turn_label: Label
var _hand_count_label: Label
var _meld_label: Label
var _hand_flow: HFlowContainer
var _meld_flow: HFlowContainer
var _discard_rows: Array[HFlowContainer] = []
var _discard_row_labels: Array[Label] = []
var _discard_legend_label: Label
var _claim_slot: HBoxContainer
var _claim_tile_button: Button
var _claim_text: Label
var _discard_button: Button
var _eat_button: Button
var _pong_button: Button
var _kan_button: Button
var _riichi_button: Button
var _riichi_skip_button: Button
var _win_button: Button
var _complete_win_button: Button
var _cancel_win_button: Button
var _bot_panels: Array[Dictionary] = []
var _result_title: Label
var _result_body: Label
var _result_words: Label
var _result_hands_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_theme_resource = Theme.new()
	_theme_resource.default_font = load(UI_FONT) as Font
	_theme_resource.default_font_size = 16
	_theme_resource.set_color("font_color", "Label", TEXT)
	_theme_resource.set_color("font_color", "Button", TEXT)
	_theme_resource.set_color("font_hover_color", "Button", Color.WHITE)
	_theme_resource.set_color("font_disabled_color", "Button", Color("#718578"))
	theme = _theme_resource
	var background := ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_dictionary = DictionaryService.new()
	_dictionary.name = "WordDictionary"
	add_child(_dictionary)
	_dictionary.validation_finished.connect(_on_dictionary_validation_finished)
	_dictionary.pattern_search_finished.connect(_on_dictionary_pattern_search_finished)
	_build_title_view()
	_build_game_view()
	_build_result_overlay()
	_build_help_overlay()
	_start_bot_word_checks()
	_show_title()


func _input(event: InputEvent) -> void:
	if _phase in ["title", "result"] or _hand_flow == null or not _pending_group_ids.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if _hand_flow.get_global_rect().has_point(mouse_event.position):
				_box_selecting = true
				_box_start = mouse_event.position
				_box_end = _box_start
				_box_selected_ids.clear()
				_selection_box.visible = true
				_update_selection_box()
				get_viewport().set_input_as_handled()
		elif _box_selecting:
			_box_selecting = false
			_selection_box.visible = false
			_finish_box_selection()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _box_selecting:
		_box_end = (event as InputEventMouseMotion).position
		_update_selection_box()
		get_viewport().set_input_as_handled()


func _update_selection_box() -> void:
	if _selection_box == null:
		return
	var top_left := Vector2(minf(_box_start.x, _box_end.x), minf(_box_start.y, _box_end.y))
	var bottom_right := Vector2(maxf(_box_start.x, _box_end.x), maxf(_box_start.y, _box_end.y))
	_selection_box.position = top_left - _game_view.global_position
	_selection_box.size = bottom_right - top_left
	var bounds := Rect2(top_left, bottom_right - top_left)
	var current: Array[int] = []
	for child: Node in _hand_flow.get_children():
		if child is Control and bounds.intersects((child as Control).get_global_rect()) and child is Button and child.get_script() == HandTileButton:
			current.append(int(child.get("tile_id")))
	if not _same_id_set(current, _box_selected_ids):
		_box_selected_ids = current
		_refresh_hand()


func _finish_box_selection() -> void:
	var top_left := Vector2(minf(_box_start.x, _box_end.x), minf(_box_start.y, _box_end.y))
	var bounds := Rect2(top_left - Vector2(3.0, 3.0), (_box_end - _box_start).abs() + Vector2(6.0, 6.0))
	var selected: Array[int] = []
	for child: Node in _hand_flow.get_children():
		if child is Control and bounds.intersects((child as Control).get_global_rect()):
			var tile_id := int(child.get("tile_id")) if child is Button and child.get_script() == HandTileButton else -1
			if tile_id >= 0:
				selected.append(tile_id)
	if selected.is_empty():
		_box_selected_ids.clear()
		_refresh_hand()
		return
	for index: int in _word_groups.size():
		var group_ids: Array = _word_groups[index].get("ids", [])
		if _same_id_set(selected, group_ids):
			_word_groups.remove_at(index)
			_box_selected_ids.clear()
			_status_text = "已解除單字固定；可重新整理並框選。"
			_refresh_all()
			return
	for tile_id: int in selected:
		if _is_tile_locked(tile_id):
			_box_selected_ids.clear()
			_status_text = "選取範圍碰到已固定單字；請框選其他牌，或框住整組解除固定。"
			_refresh_all()
			return
	_box_selected_ids = selected
	_verify_box_selection()
	_refresh_all()


func _same_id_set(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for value: Variant in first:
		if not second.has(value):
			return false
	return true


func _is_tile_locked(tile_id: int) -> bool:
	for group: Dictionary in _word_groups:
		var group_ids: Array = group.get("ids", [])
		if group_ids.has(tile_id):
			return true
	return false


func _remove_groups_for_tiles(tiles: Array) -> void:
	var removed_ids: Array[int] = []
	for tile: Dictionary in tiles:
		removed_ids.append(int(tile.get("id", -1)))
	for index: int in range(_word_groups.size() - 1, -1, -1):
		var group_ids: Array = _word_groups[index].get("ids", [])
		var overlaps := false
		for tile_id: int in removed_ids:
			if group_ids.has(tile_id):
				overlaps = true
				break
		if overlaps:
			_word_groups.remove_at(index)


func can_move_tile(tile_id: int) -> bool:
	return not _is_tile_locked(tile_id) and not _pending_group_ids.has(tile_id)


func _verify_box_selection() -> void:
	if _box_selected_ids.size() < 2:
		_box_selected_ids.clear()
		_status_text = "單字至少要框選兩張牌。"
		return
	var chosen: Array[Dictionary] = []
	var spelled := ""
	for tile_id: int in _box_selected_ids:
		var tile := _find_in_array(_hand, tile_id)
		if tile.is_empty():
			_box_selected_ids.clear()
			_status_text = "選取的牌已不存在。"
			return
		chosen.append(tile)
		if not Rules.is_sign_tile(tile) and not bool(tile.get("wild", false)):
			spelled += str(tile.get("letter", ""))
	if chosen.size() == 2 and Rules.can_form_pair(chosen):
		_word_groups.append({"ids": _box_selected_ids.duplicate(), "word": "", "kind": "pair"})
		_box_selected_ids.clear()
		_status_text = "對子已確認並固定。"
		return
	if Rules.is_sign_tile(chosen[0]):
		var same_sign := true
		for tile: Dictionary in chosen:
			if not Rules.is_sign_tile(tile) or str(tile.get("sign", "")) != str(chosen[0].get("sign", "")):
				same_sign = false
		if same_sign and chosen.size() in [3, 4]:
			_word_groups.append({"ids": _box_selected_ids.duplicate(), "word": "", "kind": "sign_set"})
			_box_selected_ids.clear()
			_status_text = "象牌組合已確認並固定。"
			return
		_box_selected_ids.clear()
		_status_text = "象牌只能框成對子、三條或四條。"
		return
	var cache: Dictionary = _dictionary.get_cache()
	for value: Variant in cache.keys():
		var word := str(value).to_upper()
		if bool(cache[value]) and Rules.can_form_word(word, chosen):
			_add_verified_group(_box_selected_ids, word)
			return
	var pattern := ""
	var has_blank := false
	for tile: Dictionary in chosen:
		if bool(tile.get("wild", false)):
			pattern += "?"
			has_blank = true
		else:
			pattern += str(tile.get("letter", ""))
	if has_blank and pattern.length() == chosen.size():
		_group_request_sequence += 1
		_active_group_request_id = _group_request_sequence
		_pending_group_ids = _box_selected_ids.duplicate()
		_group_checks_remaining = -1
		_dictionary.search_pattern(pattern, "group_pattern:%d" % _group_request_sequence)
		_status_text = "正在尋找符合 %s 的單字……" % pattern
		return
	if spelled.length() == chosen.size() and Rules.is_word_shape_valid(spelled):
		_group_request_sequence += 1
		_active_group_request_id = _group_request_sequence
		_pending_group_ids = _box_selected_ids.duplicate()
		_group_checks_remaining = 1
		_dictionary.verify_word(spelled, "group_check:%d:%s" % [_group_request_sequence, spelled])
		_status_text = "正在查核 %s……" % spelled
		return
	_box_selected_ids.clear()
	_status_text = "這組牌無法組成已確認的單字；空白牌需有字典中可匹配的單字。"


func _add_verified_group(ids: Array, word: String) -> void:
	_word_groups.append({"ids": ids.duplicate(), "word": word, "kind": "word"})
	_box_selected_ids.clear()
	_pending_group_ids.clear()
	_active_group_request_id = 0
	_group_checks_remaining = 0
	_status_text = "%s 已驗證並固定。" % word


func _build_title_view() -> void:
	_title_view = Control.new()
	_title_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_view)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_view.add_child(center)
	var panel := _make_panel(SURFACE_DARK, GOLD_DARK, Vector2(34.0, 30.0))
	panel.custom_minimum_size = Vector2(620.0, 574.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/share/favicon-256.png") as Texture2D
	icon.custom_minimum_size = Vector2(116.0, 116.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var wordmark := _make_label("WORD TILES", 48, GOLD, true)
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(wordmark)
	var subtitle := _make_label("英文麻將", 23, CREAM, true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	var intro := _make_label("自動摸牌、自由排牌；右鍵框選牌組並自動驗字。", 16, MUTED)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var rules := _make_label("124 張牌｜A–Z 各 4 張、4 張空白、E/S/W/N 象牌各 4 張
象牌不可組單字，可成對子、三條、四條
14 張全組成有效單字，或單字加對子／象牌組合
重複單字固定減一飜", 15, TEXT)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rules)
	_dictionary_label = _make_label(_dictionary_status, 13, TEAL)
	_dictionary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dictionary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_dictionary_label)
	_start_button = _make_button("開始一局", true, Vector2(260.0, 52.0))
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.pressed.connect(_start_round)
	content.add_child(_start_button)
	var note := _make_label("單字由 Datamuse 查核、Free Dictionary API 備援；無有效回應就不計入。", 12, MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

func _build_game_view() -> void:
	_game_view = Control.new()
	_game_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_view.visible = false
	add_child(_game_view)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 24)
	for side: String in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_game_view.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_build_header(column)
	_build_opponent_row(column)
	_build_table_area(column)
	_build_action_area(column)
	_build_player_hand(column)
	_selection_box = Panel.new()
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.visible = false
	_selection_box.z_index = 50
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.2, 0.55, 1.0, 0.18)
	box_style.border_color = Color(0.35, 0.72, 1.0, 0.95)
	box_style.set_border_width_all(2)
	_selection_box.add_theme_stylebox_override("panel", box_style)
	_game_view.add_child(_selection_box)


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var title := _make_label("WORD TILES  /  英文麻將", 21, GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_turn_label = _make_label("等待開局", 16, CREAM, true)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_make_chip(_turn_label, GOLD_DARK))
	_wall_label = _make_label("牌牆 0", 14, MUTED)
	row.add_child(_make_chip(_wall_label))
	var help_button := _make_button("玩法", false, Vector2(84.0, 40.0))
	help_button.pressed.connect(_toggle_help)
	row.add_child(help_button)
	var title_button := _make_button("返回標題", false, Vector2(112.0, 40.0))
	title_button.pressed.connect(_show_title)
	row.add_child(title_button)


func _build_opponent_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 74.0
	parent.add_child(row)
	for index: int in 3:
		var panel := _make_panel(SURFACE, BORDER, Vector2(16.0, 10.0))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		panel.add_child(content)
		var seat := _make_label("對手 %02d" % (index + 1), 13, MUTED, true)
		content.add_child(seat)
		var name_label := _make_label("等待發牌", 17, CREAM, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(name_label)
		var detail := _make_label("13 張暗牌", 13, TEAL)
		content.add_child(detail)
		var exposed_flow := HFlowContainer.new()
		exposed_flow.add_theme_constant_override("h_separation", 2)
		content.add_child(exposed_flow)
		_bot_panels.append({"name": name_label, "detail": detail, "melds": exposed_flow, "seat": index + 1})


func _build_table_area(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 174.0
	parent.add_child(row)
	var discard_panel := _make_panel(SURFACE_DARK, BORDER, Vector2(16.0, 12.0))
	discard_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(discard_panel)
	var discard_content := VBoxContainer.new()
	discard_content.add_theme_constant_override("separation", 8)
	discard_panel.add_child(discard_content)
	var discard_header := HBoxContainer.new()
	discard_content.add_child(discard_header)
	var discard_title := _make_label("全員牌河", 16, CREAM, true)
	discard_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_header.add_child(discard_title)
	_discard_legend_label = _make_label("0 張", 12, MUTED)
	discard_header.add_child(_discard_legend_label)
	var discard_rows_box := VBoxContainer.new()
	discard_rows_box.add_theme_constant_override("separation", 2)
	discard_content.add_child(discard_rows_box)
	for seat: int in 4:
		var discard_row := HBoxContainer.new()
		discard_row.add_theme_constant_override("separation", 6)
		discard_rows_box.add_child(discard_row)
		var seat_label := _make_label("你" if seat == 0 else "對手 %02d" % seat, 12, TEAL, true)
		seat_label.custom_minimum_size.x = 62.0
		seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		discard_row.add_child(seat_label)
		_discard_row_labels.append(seat_label)
		var tile_flow := HFlowContainer.new()
		tile_flow.add_theme_constant_override("h_separation", 3)
		tile_flow.add_theme_constant_override("v_separation", 2)
		tile_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_flow.custom_minimum_size.y = 38.0
		discard_row.add_child(tile_flow)
		_discard_rows.append(tile_flow)
	var side_panel := _make_panel(SURFACE, BORDER, Vector2(18.0, 12.0))
	side_panel.custom_minimum_size.x = 284.0
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(side_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side_panel.add_child(side)
	var current_title := _make_label("牌局狀態", 13, GOLD, true)
	side.add_child(current_title)
	_status_label = _make_label("開始後可摸牌。", 15, CREAM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_status_label)
	_claim_text = _make_label("", 13, TEAL)
	_claim_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_claim_text)
	_claim_slot = HBoxContainer.new()
	_claim_slot.add_theme_constant_override("separation", 8)
	side.add_child(_claim_slot)
	_claim_tile_button = _make_tile_button({}, false)
	_claim_tile_button.visible = false
	_claim_tile_button.pressed.connect(_on_claim_tile_button_pressed)
	_claim_slot.add_child(_claim_tile_button)
	var claim_hint := _make_label("符合條件的吃、碰、槓或榮和操作會在這裡出現。", 12, MUTED)
	claim_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_claim_slot.add_child(claim_hint)


func _build_action_area(parent: VBoxContainer) -> void:
	var panel := _make_panel(SURFACE_DARK, GOLD_DARK, Vector2(14.0, 10.0))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var instruction := _make_label("左鍵拖曳排列手牌；右鍵框選牌組，放開後自動驗字。藍色為選取中，綠色為已確認並固定。", 13, MUTED)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instruction)
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	content.add_child(turn_row)
	_discard_button = _make_button("打出選取牌", true, Vector2(136.0, 44.0))
	_discard_button.pressed.connect(_discard_selected)
	turn_row.add_child(_discard_button)
	_eat_button = _make_button("吃牌", false, Vector2(92.0, 44.0))
	_eat_button.pressed.connect(_eat_discard)
	turn_row.add_child(_eat_button)
	_pong_button = _make_button("碰象牌", false, Vector2(100.0, 44.0))
	_pong_button.pressed.connect(_pong_discard)
	turn_row.add_child(_pong_button)
	_kan_button = _make_button("槓象牌", false, Vector2(100.0, 44.0))
	_kan_button.pressed.connect(_kan_action)
	turn_row.add_child(_kan_button)
	_riichi_button = _make_button("立直", false, Vector2(88.0, 44.0))
	_riichi_button.tooltip_text = "未吃碰槓，且目前只聽一或兩種牌時，可在摸牌前宣告 Fixet。"
	_riichi_button.pressed.connect(_declare_fixet)
	turn_row.add_child(_riichi_button)
	_riichi_skip_button = _make_button("取消", false, Vector2(82.0, 44.0))
	_riichi_skip_button.pressed.connect(_skip_fixet_prompt)
	turn_row.add_child(_riichi_skip_button)
	_win_button = _make_button("榮和", true, Vector2(92.0, 44.0))
	_win_button.pressed.connect(_claim_win)
	turn_row.add_child(_win_button)
	_complete_win_button = _make_button("和牌", true, Vector2(92.0, 44.0))
	_complete_win_button.pressed.connect(_confirm_grouped_win)
	turn_row.add_child(_complete_win_button)
	_cancel_win_button = _make_button("取消", false, Vector2(82.0, 44.0))
	_cancel_win_button.pressed.connect(_cancel_grouped_win)
	turn_row.add_child(_cancel_win_button)
	var dictionary_hint := _make_label("單字會在框選後自動查核。", 12, MUTED)
	dictionary_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dictionary_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dictionary_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_row.add_child(dictionary_hint)

func _build_player_hand(parent: VBoxContainer) -> void:
	var panel := _make_panel(SURFACE, GOLD_DARK, Vector2(16.0, 10.0))
	panel.custom_minimum_size.y = 142.0
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _make_label("你的手牌", 15, CREAM, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_hand_count_label = _make_label("13 張", 13, GOLD)
	header.add_child(_hand_count_label)
	_meld_label = _make_label("", 12, TEAL)
	header.add_child(_meld_label)
	_hand_flow = HFlowContainer.new()
	_hand_flow.add_theme_constant_override("h_separation", 6)
	_hand_flow.add_theme_constant_override("v_separation", 4)
	_hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_hand_flow)
	_meld_flow = HFlowContainer.new()
	_meld_flow.add_theme_constant_override("h_separation", 4)
	_meld_flow.visible = false
	content.add_child(_meld_flow)


func _build_result_overlay() -> void:
	_result_overlay = Control.new()
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.visible = false
	_result_overlay.z_index = 20
	add_child(_result_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.03, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)
	var panel := _make_panel(SURFACE_DARK, GOLD, Vector2(28.0, 22.0))
	panel.custom_minimum_size = Vector2(780.0, 540.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	_result_title = _make_label("牌局結束", 32, GOLD, true)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_result_title)
	_result_body = _make_label("", 17, CREAM)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_result_body)
	_result_words = _make_label("", 14, MUTED)
	_result_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_result_words)
	_result_hands_label = RichTextLabel.new()
	_result_hands_label.bbcode_enabled = true
	_result_hands_label.fit_content = true
	_result_hands_label.scroll_active = false
	_result_hands_label.custom_minimum_size = Vector2(700.0, 130.0)
	_result_hands_label.add_theme_font_size_override("normal_font_size", 13)
	content.add_child(_result_hands_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var again := _make_button("再玩一局", true, Vector2(150.0, 46.0))
	again.pressed.connect(_start_round)
	actions.add_child(again)
	var back := _make_button("返回標題", false, Vector2(130.0, 46.0))
	back.pressed.connect(_show_title)
	actions.add_child(back)


func _build_help_overlay() -> void:
	_help_overlay = Control.new()
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.visible = false
	_help_overlay.z_index = 15
	add_child(_help_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.03, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(center)
	var panel := _make_panel(SURFACE_DARK, GOLD, Vector2(30.0, 24.0))
	panel.custom_minimum_size = Vector2(600.0, 390.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := _make_label("玩法速讀", 28, GOLD, true)
	content.add_child(title)
	var rules_text := _make_label("• 一副 124 張：A–Z 各四張、四張空白、E/S/W/N 象牌各四張。
• 起手 13 張；你的回合自動摸牌，打牌回到 13 張。
• 右鍵框選單字，放開後自動查字；合法字組會固定成綠色。
• 對子與象牌組合也可框選固定；框住已固定牌組可解除。
• 全手牌分組完成後，按和牌確認或取消。
• 只能吃上家字牌；吃牌後須打出一張。象牌不能吃。
• 象牌可碰、槓；槓後從牌牆補一張，再打出一張。
• Fixet 聽一或兩種牌時會在摸牌前提示。", 14, CREAM)
	rules_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(rules_text)
	var close := _make_button("返回牌局", true, Vector2(160.0, 44.0))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(_toggle_help)
	content.add_child(close)

func _make_panel(background: Color, edge: Color, padding: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_label(text_value: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", load(UI_BOLD) as Font)
	return label


func _make_button(text_value: String, accent: bool, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("718578"))
	var base := GOLD if accent else SURFACE
	var edge := GOLD_DARK if accent else BORDER
	button.add_theme_stylebox_override("normal", _button_style(base, edge))
	button.add_theme_stylebox_override("hover", _button_style(base.lightened(0.08), GOLD))
	button.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.12), GOLD))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#17352d"), Color("#29453b")))
	return button


func _button_style(background: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _make_chip(label: Label, accent: Color = BORDER) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SURFACE_DARK, 0.94)
	style.border_color = Color(accent, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	chip.add_theme_stylebox_override("panel", style)
	chip.add_child(label)
	return chip


func _make_tile_button(tile: Dictionary, selected: bool, draggable: bool = false, highlight: Color = Color.TRANSPARENT) -> Button:
	var button: Button
	if draggable:
		var hand_button = HandTileButton.new()
		hand_button.tile_id = int(tile.get("id", -1))
		hand_button.hand_owner_id = get_instance_id()
		hand_button.main_controller = self
		button = hand_button
	else:
		button = Button.new()
	button.custom_minimum_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_font_override("font", load(UI_BOLD) as Font)
	_set_tile_face(button, tile)
	var tile_edge := GOLD if selected else GOLD_DARK
	var tile_bg := Color("#f4eedf") if not selected else Color("#f8d994")
	if highlight.a > 0.0:
		tile_edge = highlight
		tile_bg = highlight.lightened(0.48)
	button.add_theme_color_override("font_color", _tile_text_color(tile))
	button.add_theme_color_override("font_hover_color", _tile_text_color(tile).darkened(0.12))
	button.add_theme_stylebox_override("normal", _tile_style(tile_bg, tile_edge, highlight.a > 0.0))
	button.add_theme_stylebox_override("hover", _tile_style(Color("#fff9e9"), highlight if highlight.a > 0.0 else GOLD, false))
	button.add_theme_stylebox_override("pressed", _tile_style(Color("#e8d19d"), GOLD, false))
	button.add_theme_stylebox_override("focus", _tile_style(Color("#fff9e9"), TEAL, false))
	if bool(tile.get("wild", false)):
		button.tooltip_text = "空白百搭牌：可代表任意字母。"
	else:
		button.tooltip_text = "拖曳排列；點選後可在你的棄牌回合打出。"
	if tile.has("id"):
		button.pressed.connect(_on_tile_pressed.bind(int(tile.id)))
	return button


func _set_tile_face(button: Button, tile: Dictionary) -> void:
	# face_image can be a resource path; sign can select one of the four element faces.
	for child: Node in button.get_children():
		if child is TextureRect or child is Label:
			button.remove_child(child)
			child.queue_free()
	var texture := _tile_face_texture(tile)
	var display := _tile_face_text(tile)
	button.text = "" if texture != null and not display.is_empty() else display
	if texture == null:
		return
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = 5.0
	image.offset_top = 5.0
	image.offset_right = -5.0
	image.offset_bottom = -5.0
	button.add_child(image)
	if display.is_empty():
		return
	var face_label := Label.new()
	face_label.text = display
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face_label.add_theme_font_override("font", load(UI_BOLD) as Font)
	face_label.add_theme_font_size_override("font_size", 24)
	face_label.add_theme_color_override("font_color", _tile_text_color(tile))
	face_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.92))
	face_label.add_theme_constant_override("outline_size", 3)
	face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(face_label)


func _tile_face_texture(tile: Dictionary) -> Texture2D:
	var texture_value: Variant = tile.get("face_texture")
	if texture_value is Texture2D:
		return texture_value
	var path := str(tile.get("face_image", ""))
	if path.is_empty():
		var sign := str(tile.get("sign", "")).to_upper()
		path = str(SIGN_FACE_PATHS.get(sign, ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _tile_face_text(tile: Dictionary) -> String:
	if tile.has("face_text"):
		return str(tile.face_text)
	if bool(tile.get("wild", false)):
		return "?"
	if tile.has("sign"):
		return ""
	return str(tile.get("letter", "·"))


func _tile_text_color(tile: Dictionary) -> Color:
	if bool(tile.get("wild", false)):
		return GOLD_DARK
	if tile.has("sign"):
		return Color("#17352b")
	return RED if Rules.is_vowel_letter(str(tile.get("letter", ""))) else Color("#17352b")

func _tile_style(background: Color, edge: Color, grouped: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(3 if grouped else 1)
	style.set_corner_radius_all(9)
	style.border_width_bottom = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _show_title() -> void:
	_help_open = false
	_phase = "title"
	_title_view.visible = true
	_game_view.visible = false
	_result_overlay.visible = false
	_help_overlay.visible = false
	_refresh_title_dictionary_text()


func _toggle_help() -> void:
	_help_open = not _help_open
	_help_overlay.visible = _help_open and _phase != "title" and _phase != "result"


func _start_bot_word_checks() -> void:
	for word: String in BOT_SEED_WORDS:
		_dictionary.verify_word(word, "bot_seed:" + word)


func _refresh_title_dictionary_text() -> void:
	if _dictionary_label != null:
		_dictionary_label.text = _dictionary_status


func _start_round() -> void:
	_round_number += 1
	_deck = Rules.build_deck()
	_deck.shuffle()
	_hand.clear()
	_melds.clear()
	_opponents.clear()
	_discards.clear()
	_selected_ids.clear()
	_word_groups.clear()
	_box_selected_ids.clear()
	_pending_group_ids.clear()
	_active_group_request_id = 0
	_grouping_claim_tile.clear()
	_grouping_claim_source = -1
	_fixet_prompt_wait_types.clear()
	_fixet_prompt_active = false
	_fixet_prompt_hand_ids.clear()
	_fixet_scan_active = false
	_fixet_scan_hand_ids.clear()
	_fixet_scan_wait_types.clear()
	_fixet_pattern_contexts.clear()
	_claim_tile.clear()
	_claim_source_seat = -1
	_pending_bot_winners.clear()
	_last_win.clear()
	_last_win_tile.clear()
	_last_winners.clear()
	_last_reason = ""
	_eat_han_penalty = 0
	_has_eaten = false
	_riichi_declared = false
	_riichi_wait_types.clear()
	_hand = _draw_cards(13)
	for index: int in BOT_NAMES.size():
		_opponents.append(_make_random_opponent(BOT_NAMES[index], index + 1))
	_phase = "player_draw"
	_status_text = "新局開始。你的回合會自動摸牌。"
	_help_open = false
	_refresh_all()
	call_deferred("_begin_player_turn")

func _make_random_opponent(name: String, seat: int) -> Dictionary:
	return {"name": name, "hand": _draw_cards(13), "melds": [], "seat": seat}



func _draw_cards(count: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for _index: int in count:
		if _deck.is_empty():
			break
		cards.append(_deck.pop_back())
	return cards


func _draw_for_player() -> void:
	if _phase != "player_draw":
		return
	_fixet_prompt_wait_types.clear()
	_fixet_prompt_active = false
	_fixet_prompt_hand_ids.clear()
	if _deck.is_empty():
		_finish_round([], "牌牆已空，本局流局。")
		return
	_hand.append(_deck.pop_back())
	_phase = "player_discard"
	_status_text = "已自動摸牌。左鍵選牌後打出；右鍵框選並驗證牌組。"
	_selected_ids.clear()
	_refresh_all()


func _begin_player_turn() -> void:
	if _phase != "player_draw":
		return
	if _fixet_scan_active:
		if _same_id_set(_current_hand_ids(), _fixet_scan_hand_ids):
			_refresh_all()
			return
		_fixet_scan_active = false
		_fixet_pattern_contexts.clear()
	if _fixet_prompt_active:
		if _same_id_set(_current_hand_ids(), _fixet_prompt_hand_ids):
			_refresh_all()
			return
		_fixet_prompt_active = false
		_fixet_prompt_wait_types.clear()
		_fixet_prompt_hand_ids.clear()
	if not _pending_group_ids.is_empty():
		_status_text = "正在完成單字查核；查完後再判定 Fixet 與摸牌。"
		_refresh_all()
		return
	if _riichi_declared or not _melds.is_empty() or _has_eaten:
		_draw_for_player()
		return
	_fixet_prompt_wait_types = _fixet_wait_types(_hand)
	if _fixet_prompt_wait_types.size() > 2:
		_draw_for_player()
		return
	if not _start_dynamic_fixet_scan():
		if _fixet_prompt_wait_types.size() in [1, 2]:
			_fixet_prompt_active = true
			_fixet_prompt_hand_ids = _current_hand_ids()
			_status_text = "摸牌前提示：目前聽 %s。宣告 Fixet，或按取消繼續摸牌。" % "、".join(_fixet_prompt_wait_types)
			_refresh_all()
		else:
			_draw_for_player()


func _start_dynamic_fixet_scan() -> bool:
	var grouped: Dictionary = {}
	for group: Dictionary in _word_groups:
		for tile_id: Variant in group.get("ids", []):
			grouped[int(tile_id)] = true
	var loose: Array[Dictionary] = []
	for tile: Dictionary in _hand:
		if not grouped.has(int(tile.get("id", -1))) and not Rules.is_sign_tile(tile):
			loose.append(tile)
	if loose.size() < 2 or loose.size() > 6:
		return false
	var patterns: Dictionary = {}
	for index: int in Rules.LETTERS.length():
		var letter := Rules.LETTERS.substr(index, 1)
		if _remaining_copy_count(letter, false) <= 0:
			continue
		var symbols := _loose_pattern_symbols(loose)
		for position: int in symbols.size() + 1:
			var inserted := symbols.duplicate()
			inserted.insert(position, letter)
			var pattern := "".join(inserted)
			patterns[pattern] = letter
	if patterns.is_empty():
		return false
	_fixet_scan_id += 1
	_fixet_scan_active = true
	_fixet_scan_hand_ids = _current_hand_ids()
	_fixet_scan_wait_types = _fixet_prompt_wait_types.duplicate()
	_fixet_scan_patterns_remaining = patterns.size()
	_fixet_pattern_contexts.clear()
	_status_text = "正在查詢外部字典，確認摸牌前的 Fixet 聽牌……"
	_refresh_all()
	for pattern: String in patterns:
		var tag := "fixet_pattern:%d:%s:%s" % [_fixet_scan_id, str(patterns[pattern]), pattern]
		_fixet_pattern_contexts[tag] = {"letter": str(patterns[pattern]), "pattern": pattern}
		_dictionary.search_pattern(pattern, tag)
	return true


func _loose_pattern_symbols(tiles: Array[Dictionary]) -> Array[String]:
	var symbols: Array[String] = []
	for tile: Dictionary in tiles:
		symbols.append("?" if bool(tile.get("wild", false)) else str(tile.get("letter", "")).to_upper())
	return symbols


func _skip_fixet_prompt() -> void:
	if _phase != "player_draw" or not _fixet_prompt_active:
		return
	_fixet_prompt_wait_types.clear()
	_fixet_prompt_active = false
	_fixet_prompt_hand_ids.clear()
	_draw_for_player()


func _current_hand_ids() -> Array[int]:
	var ids: Array[int] = []
	for tile: Dictionary in _hand:
		ids.append(int(tile.get("id", -1)))
	return ids


func _resume_player_turn_if_ready() -> void:
	if _phase == "player_draw" and _pending_group_ids.is_empty() and not _fixet_prompt_active and not _fixet_scan_active:
		call_deferred("_begin_player_turn")

func _on_tile_pressed(tile_id: int) -> void:
	if _phase != "player_discard" or _is_tile_locked(tile_id) or _pending_group_ids.has(tile_id):
		return
	var tile := _find_in_array(_hand, tile_id)
	if tile.is_empty():
		return
	if _selected_ids.has(tile_id):
		_selected_ids.clear()
	else:
		_selected_ids = [tile_id]
	_refresh_all()


func _reorder_hand_tile(source_tile_id: int, target_tile_id: int, insert_after: bool) -> void:
	if _phase in ["title", "result"] or source_tile_id == target_tile_id or _is_tile_locked(source_tile_id) or _is_tile_locked(target_tile_id):
		return
	var source_index := -1
	for index: int in _hand.size():
		if int(_hand[index].get("id", -1)) == source_tile_id:
			source_index = index
			break
	if source_index < 0:
		return
	var moving: Dictionary = _hand.pop_at(source_index)
	var target_index := -1
	for index: int in _hand.size():
		if int(_hand[index].get("id", -1)) == target_tile_id:
			target_index = index
			break
	if target_index < 0:
		_hand.insert(source_index, moving)
		return
	_hand.insert(target_index + (1 if insert_after else 0), moving)
	_refresh_all()







func _record_discard(tile: Dictionary, seat: int) -> void:
	var entry := tile.duplicate(true)
	entry["discarder_seat"] = seat
	_discards.append(entry)


func _discard_selected() -> void:
	if _phase != "player_discard" or _effective_hand_count() != Rules.HAND_SIZE or _selected_ids.size() != 1:
		return
	var tile_id := _selected_ids[0]
	var tile := _find_in_array(_hand, tile_id)
	if tile.is_empty():
		return
	_hand.erase(tile)
	_record_discard(tile, 0)
	_selected_ids.clear()
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, tile, 0, _dictionary.get_cache())
	if not _pending_bot_winners.is_empty():
		_remove_discard_by_id(int(tile.id))
		_finish_round(_pending_bot_winners, "榮和", {}, tile)
		return
	if _riichi_declared:
		_status_text = "你立直並打出 %s，等待 %s。" % [_tile_name(tile), "、".join(_riichi_wait_types)]
	else:
		_status_text = "你打出 %s。對手輪流摸牌。" % _tile_name(tile)
	_refresh_all()
	call_deferred("_run_bot_turn", 1)

func _run_bot_turn(seat: int) -> void:
	if _phase == "result" or _phase == "title":
		return
	if _deck.is_empty():
		_finish_round([], "牌牆已空，本局流局。")
		return
	_phase = "bot_turn"
	_status_text = "%s 正在摸牌……" % _opponent_name(seat)
	_refresh_all()
	await get_tree().create_timer(0.36, false).timeout
	if _phase == "result" or _phase == "title":
		return
	var bot := _opponent_by_seat(seat)
	if bot.is_empty():
		_finish_round([], "對局資料有誤，本局結束。")
		return
	var drawn: Dictionary = _deck.pop_back()
	var bot_hand: Array = bot.get("hand", [])
	bot_hand.append(drawn)
	bot["hand"] = bot_hand
	var bot_melds: Array = bot.get("melds", [])
	var bot_win_hand := _hand_with_melds(bot_hand, bot_melds)
	var self_result := Rules.find_winning_declaration(bot_win_hand, _dictionary.get_cache(), bot_melds)
	if bool(self_result.get("ok", false)):
		_finish_round([str(bot.get("name", "對手"))], "自摸和", self_result)
		return
	bot_hand.erase(drawn)
	bot["hand"] = bot_hand
	_record_discard(drawn, seat)
	_pending_next_seat = (seat + 1) % 4
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, drawn, seat, _dictionary.get_cache())
	_claim_tile = drawn
	_claim_source_seat = seat
	_phase = "claim"
	_selected_ids.clear()
	if _pending_bot_winners.is_empty():
		_status_text = "%s 打出 %s。可吃上家字牌、碰／槓象牌；3 秒內未操作會自動跳過。" % [str(bot.get("name", "對手")), _tile_name(drawn)]
	else:
		_status_text = "%s 打出 %s；有對手實際符合榮和牌型。你可於 3 秒內榮和、吃／碰／槓，否則自動跳過。" % [str(bot.get("name", "對手")), _tile_name(drawn)]
	_refresh_all()
	call_deferred("_auto_resolve_claim", int(drawn.get("id", -1)))

func _claim_win() -> void:
	if _phase != "claim" or _claim_tile.is_empty():
		return
	_grouping_claim_tile = _claim_tile.duplicate(true)
	_grouping_claim_source = _claim_source_seat
	_hand.append(_grouping_claim_tile.duplicate(true))
	_remove_discard_by_id(int(_grouping_claim_tile.get("id", -1)))
	_claim_tile.clear()
	_claim_source_seat = -1
	_phase = "claim_grouping"
	_box_selected_ids.clear()
	_status_text = "請框選並驗證全部牌組；完成後即可榮和。"
	_refresh_all()


func _all_hand_tiles_grouped() -> bool:
	if _hand.is_empty():
		return false
	var covered: Dictionary = {}
	var has_word := false
	var words: Array[String] = []
	for group: Dictionary in _word_groups:
		if str(group.get("kind", "")) == "word":
			has_word = true
			words.append(str(group.get("word", "")))
		for value: Variant in group.get("ids", []):
			var tile_id := int(value)
			if covered.has(tile_id):
				return false
			covered[tile_id] = true
	if covered.size() != _hand.size() or not has_word:
		return false
	for tile: Dictionary in _hand:
		if not covered.has(int(tile.get("id", -1))):
			return false
	if _effective_hand_count() != Rules.HAND_SIZE:
		return false
	var layout := Rules.evaluate_declared_words(_hand_with_melds(_hand, _melds), words, _dictionary.get_cache(), true, _melds)
	return bool(layout.get("ok", false))


func _confirm_grouped_win() -> void:
	if not _all_hand_tiles_grouped():
		return
	var words: Array[String] = []
	for group: Dictionary in _word_groups:
		if str(group.get("kind", "")) == "word":
			words.append(str(group.get("word", "")))
	var candidate := _hand_with_melds(_hand, _melds)
	var result := Rules.evaluate_declared_words(candidate, words, _dictionary.get_cache(), true, _melds)
	if not bool(result.get("ok", false)):
		_status_text = str(result.get("reason", "牌組未能組成有效和牌。"))
		_refresh_all()
		return
	result["han_penalty"] = int(result.get("han_penalty", 0)) + _eat_han_penalty
	result["squares_lost"] = int(result["han_penalty"])
	result["eat_han_penalty"] = _eat_han_penalty
	result["parvis"] = _melds.is_empty()
	result["clean_parvis"] = _melds.is_empty()
	result["fixet"] = _riichi_declared
	result["fixet_wait_types"] = _riichi_wait_types.duplicate()
	var claimed := _grouping_claim_tile.duplicate(true)
	var winners: Array[String] = ["你"]
	if not _grouping_claim_tile.is_empty():
		for winner: String in _pending_bot_winners:
			if not winners.has(winner):
				winners.append(winner)
	_finish_round(winners, "榮和" if not claimed.is_empty() else "自摸和", result, claimed)


func _cancel_grouped_win() -> void:
	_word_groups.clear()
	_box_selected_ids.clear()
	_pending_group_ids.clear()
	if not _grouping_claim_tile.is_empty():
		var claimed_id := int(_grouping_claim_tile.get("id", -1))
		var claimed_hand_tile := _find_in_array(_hand, claimed_id)
		if not claimed_hand_tile.is_empty():
			_hand.erase(claimed_hand_tile)
		_record_discard(_grouping_claim_tile, _grouping_claim_source)
		_claim_tile = _grouping_claim_tile.duplicate(true)
		_claim_source_seat = _grouping_claim_source
		_grouping_claim_tile.clear()
		_grouping_claim_source = -1
		_phase = "claim"
		_status_text = "已取消榮和，牌仍可吃／碰／槓；稍後會自動跳過。"
		_refresh_all()
		call_deferred("_auto_resolve_claim", int(_claim_tile.get("id", -1)))
		return
	_status_text = "已取消和牌宣告；可重新框選牌組。"
	_refresh_all()


func _eat_discard() -> void:
	if _riichi_declared or _phase != "claim" or _claim_tile.is_empty() or _claim_source_seat != 3 or Rules.is_sign_tile(_claim_tile):
		return
	if not _has_confirmed_word_group(_hand):
		_eat_han_penalty += 1
	_has_eaten = true
	_hand.append(_claim_tile.duplicate(true))
	_remove_discard_by_id(int(_claim_tile.get("id", -1)))
	_claim_tile.clear()
	_claim_source_seat = -1
	_pending_bot_winners.clear()
	_selected_ids.clear()
	_phase = "player_discard"
	_status_text = "你已吃進上家字牌。若未和牌，現在必須打出一張牌。"
	_refresh_all()


func _pong_discard() -> void:
	if _riichi_declared:
		return
	_claim_sign_set("pong", 2)


func _kan_action() -> void:
	if _riichi_declared:
		return
	if _phase == "claim":
		_claim_sign_set("kan", 3)
		return
	if _phase != "player_discard" or _deck.is_empty():
		return
	for meld_index: int in _melds.size():
		var meld: Dictionary = _melds[meld_index]
		if str(meld.get("kind", "")) != "pong":
			continue
		var sign := str(meld.get("sign", ""))
		var matching_pong_upgrade := _matching_sign_tiles(_hand, sign)
		if matching_pong_upgrade.is_empty():
			continue
		var upgrade_tile: Dictionary = matching_pong_upgrade[0]
		_remove_groups_for_tiles([upgrade_tile])
		_hand.erase(upgrade_tile)
		var upgraded_tiles: Array = meld.get("tiles", [])
		upgraded_tiles.append(upgrade_tile)
		meld["tiles"] = upgraded_tiles
		meld["kind"] = "kan"
		_melds[meld_index] = meld
		_hand.append(_deck.pop_back())
		_selected_ids.clear()
		_status_text = "你將 %s 碰升槓並補牌；請再打出一張。" % sign
		_refresh_all()
		return
	for sign: String in Rules.SIGNS:
		var matching := _matching_sign_tiles(_hand, sign)
		if matching.size() < 4:
			continue
		var chosen: Array = matching.slice(0, 4)
		_remove_groups_for_tiles(chosen)
		for tile: Dictionary in chosen:
			_hand.erase(tile)
		_melds.append({"kind": "kan", "sign": sign, "tiles": chosen, "source_seat": 0, "concealed": true})
		_hand.append(_deck.pop_back())
		_selected_ids.clear()
		_status_text = "你暗槓了 %s 象牌，已從牌牆補牌；請再打出一張。" % sign
		_refresh_all()
		return


func _claim_sign_set(kind: String, needed_in_hand: int) -> void:
	if _phase != "claim" or _claim_tile.is_empty() or not Rules.is_sign_tile(_claim_tile):
		return
	if kind == "kan" and _deck.is_empty():
		_status_text = "牌牆已空，無法槓牌補牌。"
		_refresh_all()
		return
	var sign := str(_claim_tile.get("sign", "")).to_upper()
	var matching := _matching_sign_tiles(_hand, sign)
	if matching.size() < needed_in_hand:
		return
	var meld_tiles: Array[Dictionary] = []
	var chosen_from_hand: Array[Dictionary] = []
	for index: int in needed_in_hand:
		var tile: Dictionary = matching[index]
		chosen_from_hand.append(tile)
	_remove_groups_for_tiles(chosen_from_hand)
	for tile: Dictionary in chosen_from_hand:
		_hand.erase(tile)
		meld_tiles.append(tile)
	var claimed := _claim_tile.duplicate(true)
	meld_tiles.append(claimed)
	_melds.append({"kind": kind, "sign": sign, "tiles": meld_tiles, "source_seat": _claim_source_seat, "concealed": false})
	_remove_discard_by_id(int(claimed.get("id", -1)))
	_claim_tile.clear()
	_claim_source_seat = -1
	_pending_bot_winners.clear()
	_selected_ids.clear()
	if kind == "kan":
		_hand.append(_deck.pop_back())
		_status_text = "你槓了 %s 象牌並補牌，現在必須打出一張。" % sign
	else:
		_status_text = "你碰了 %s 象牌，現在必須打出一張。" % sign
	_phase = "player_discard"
	_refresh_all()


func _declare_fixet() -> void:
	if _phase == "player_draw" and not _fixet_prompt_wait_types.is_empty() and _melds.is_empty() and not _has_eaten and not _riichi_declared:
		_riichi_declared = true
		_riichi_wait_types = _fixet_prompt_wait_types.duplicate()
		_fixet_prompt_wait_types.clear()
		_status_text = "你宣告 Fixet，等待 %s；即將自動摸牌。" % "、".join(_riichi_wait_types)
		_draw_for_player()


func _fixet_wait_types(hand_after_discard: Array) -> Array[String]:
	var waits: Array[String] = []
	var verified: Dictionary = _dictionary.get_cache()
	if not _has_confirmed_word_group(hand_after_discard):
		return waits
	for index: int in Rules.LETTERS.length():
		var letter := Rules.LETTERS.substr(index, 1)
		if _remaining_copy_count(letter, false) <= 0:
			continue
		var candidate: Array = hand_after_discard.duplicate(true)
		candidate.append(Rules.make_tile(2000 + index, letter))
		if bool(Rules.find_winning_declaration(candidate, verified).get("ok", false)):
			waits.append(letter)
			if waits.size() > 2:
				return waits
	if _remaining_copy_count("", true) > 0:
		var blank_candidate: Array = hand_after_discard.duplicate(true)
		blank_candidate.append(Rules.make_tile(3000, "", true))
		if bool(Rules.find_winning_declaration(blank_candidate, verified).get("ok", false)):
			waits.append("空白")
	return waits


func _remaining_copy_count(letter: String, wild: bool) -> int:
	var seen := 0
	var tile_pools: Array = [_hand, _deck, _discards]
	for opponent: Dictionary in _opponents:
		tile_pools.append(opponent.get("hand", []))
		for meld: Dictionary in opponent.get("melds", []):
			tile_pools.append(meld.get("tiles", []))
	for meld: Dictionary in _melds:
		tile_pools.append(meld.get("tiles", []))
	for pool_value: Variant in tile_pools:
		if not pool_value is Array:
			continue
		for tile_value: Variant in pool_value:
			if not tile_value is Dictionary:
				continue
			var tile: Dictionary = tile_value
			if Rules.is_sign_tile(tile):
				continue
			if bool(tile.get("wild", false)) == wild and (wild or str(tile.get("letter", "")).to_upper() == letter):
				seen += 1
	return maxi(0, 4 - seen)


func _matching_sign_tiles(tiles: Array, sign: String) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	for value: Variant in tiles:
		if value is Dictionary and str(value.get("sign", "")).to_upper() == sign:
			matching.append(value)
	return matching


func _hand_with_melds(hand: Array, melds: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in hand:
		if value is Dictionary:
			result.append(value)
	for meld_value: Variant in melds:
		if not meld_value is Dictionary:
			continue
		var meld_tiles: Variant = meld_value.get("tiles", [])
		if meld_tiles is Array:
			for tile_value: Variant in meld_tiles:
				if tile_value is Dictionary:
					result.append(tile_value)
	return result


func _has_confirmed_word_group(tiles: Array) -> bool:
	var cache: Dictionary = _dictionary.get_cache()
	for value: Variant in cache.keys():
		var word := str(value).to_upper()
		if not bool(cache[value]) or not Rules.is_word_shape_valid(word):
			continue
		var needed: Dictionary = {}
		for index: int in word.length():
			var letter := word.substr(index, 1)
			needed[letter] = int(needed.get(letter, 0)) + 1
		var available: Dictionary = {}
		var wild_count := 0
		for tile_value: Variant in tiles:
			if not tile_value is Dictionary:
				continue
			var tile: Dictionary = tile_value
			if Rules.is_sign_tile(tile):
				continue
			if bool(tile.get("wild", false)):
				wild_count += 1
			else:
				var letter := str(tile.get("letter", "")).to_upper()
				available[letter] = int(available.get(letter, 0)) + 1
		var missing := 0
		for letter: String in Rules.LETTERS:
			missing += maxi(0, int(needed.get(letter, 0)) - int(available.get(letter, 0)))
		if missing <= wild_count:
			return true
	return false

func _pass_claim() -> void:
	if _phase != "claim":
		return
	if not _claim_tile.is_empty() and not _pending_bot_winners.is_empty():
		var winning_tile := _claim_tile.duplicate(true)
		_remove_discard_by_id(int(winning_tile.get("id", -1)))
		_claim_tile.clear()
		_claim_source_seat = -1
		_finish_round(_pending_bot_winners, "榮和", {}, winning_tile)
		return
	_claim_tile.clear()
	_claim_source_seat = -1
	_selected_ids.clear()
	var next_seat := _pending_next_seat
	if next_seat == 0:
		_phase = "player_draw"
		_refresh_all()
		call_deferred("_begin_player_turn")
	else:
		call_deferred("_run_bot_turn", next_seat)

func _open_claim_window(discard_tile: Dictionary, source_seat: int) -> void:
	_claim_tile = discard_tile.duplicate(true)
	_claim_source_seat = source_seat
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, _claim_tile, source_seat, _dictionary.get_cache())
	_pending_next_seat = (source_seat + 1) % 4
	_phase = "claim"
	_selected_ids.clear()
	_refresh_all()
	call_deferred("_auto_resolve_claim", int(discard_tile.get("id", -1)))


func _auto_resolve_claim(tile_id: int) -> void:
	await get_tree().create_timer(3.0, false).timeout
	if _phase == "claim" and int(_claim_tile.get("id", -1)) == tile_id:
		_pass_claim()


func _finish_round(winners: Array, reason: String, outcome: Dictionary = {}, winning_tile: Dictionary = {}) -> void:
	_phase = "result"
	_claim_source_seat = -1
	_last_winners = []
	for winner_value: Variant in winners:
		var winner := str(winner_value)
		if not _last_winners.has(winner):
			_last_winners.append(winner)
	_last_reason = reason
	_last_win = outcome.duplicate(true)
	_last_win_tile = winning_tile.duplicate(true)
	_help_open = false
	_refresh_all()

func _refresh_all() -> void:
	if not is_node_ready():
		return
	_title_view.visible = _phase == "title"
	_game_view.visible = _phase != "title"
	_result_overlay.visible = _phase == "result"
	_help_overlay.visible = _help_open and _phase != "title" and _phase != "result"
	if _status_label != null:
		_status_label.text = _status_text
	if _wall_label != null:
		_wall_label.text = "牌牆 %d" % _deck.size()
	if _turn_label != null:
		_turn_label.text = _turn_description()
	if _hand_count_label != null:
		_hand_count_label.text = "%d 張" % _effective_hand_count()
	if _meld_label != null:
		var meld_names: Array[String] = []
		for meld: Dictionary in _melds:
			meld_names.append("%s %s" % ["碰" if str(meld.get("kind", "")) == "pong" else "槓", str(meld.get("sign", ""))])
		_meld_label.text = "副露：" + "、".join(meld_names) if not meld_names.is_empty() else ""
	_refresh_title_dictionary_text()
	_refresh_opponents()
	_refresh_discards()
	_refresh_hand()
	_refresh_claim_slot()
	_refresh_buttons()
	_refresh_result()

func _refresh_opponents() -> void:
	for entry: Dictionary in _bot_panels:
		var seat := int(entry.get("seat", -1))
		var bot := _opponent_by_seat(seat)
		var name_label: Label = entry.get("name")
		var detail: Label = entry.get("detail")
		var exposed_flow: HFlowContainer = entry.get("melds")
		_clear_container(exposed_flow)
		if bot.is_empty():
			name_label.text = "等待發牌"
			detail.text = "13 張暗牌"
			continue
		name_label.text = str(bot.get("name", "對手"))
		var bot_hand: Array = bot.get("hand", [])
		var melds: Array = bot.get("melds", [])
		if _phase == "result" and _last_winners.has(str(bot.get("name", ""))):
			detail.text = "已和牌 · %d 張" % _hand_for_result(str(bot.get("name", ""))).size()
		elif _phase == "bot_turn" and _status_text.begins_with(str(bot.get("name", ""))):
			detail.text = "摸牌中"
		else:
			detail.text = "%d 暗牌 · %d 副露" % [bot_hand.size(), melds.size()] if not melds.is_empty() else "%d 張暗牌" % bot_hand.size()
		exposed_flow.visible = not melds.is_empty()
		for meld: Dictionary in melds:
			for tile: Dictionary in meld.get("tiles", []):
				exposed_flow.add_child(_make_small_tile(tile))

func _refresh_discards() -> void:
	if _discard_rows.size() != 4:
		return
	for seat: int in 4:
		_clear_container(_discard_rows[seat])
		_discard_row_labels[seat].text = "你" if seat == 0 else _opponent_name(seat)
	_discard_legend_label.text = "%d 張" % _discards.size()
	for tile: Dictionary in _discards:
		var seat := clampi(int(tile.get("discarder_seat", 0)), 0, 3)
		_discard_rows[seat].add_child(_make_small_tile(tile))


func _make_small_tile(tile: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := _tile_style(Color("#f0e7d3"), GOLD_DARK, false)
	panel.add_theme_stylebox_override("panel", style)
	var texture := _tile_face_texture(tile)
	var display := _tile_face_text(tile)
	if texture == null:
		var label := _make_label(display, 19, _tile_text_color(tile), true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		panel.add_child(label)
		return panel
	var face := Control.new()
	face.custom_minimum_size = Vector2(30.0, 36.0)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_child(image)
	if not display.is_empty():
		var face_label := Label.new()
		face_label.text = display
		face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face_label.add_theme_font_override("font", load(UI_BOLD) as Font)
		face_label.add_theme_font_size_override("font_size", 13)
		face_label.add_theme_color_override("font_color", _tile_text_color(tile))
		face_label.add_theme_color_override("font_outline_color", Color.WHITE)
		face_label.add_theme_constant_override("outline_size", 2)
		face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.add_child(face_label)
	panel.add_child(face)
	return panel

func _refresh_hand() -> void:
	if _hand_flow == null:
		return
	_clear_container(_hand_flow)
	for tile: Dictionary in _hand:
		var tile_id := int(tile.get("id", -1))
		var highlight := Color.TRANSPARENT
		if _is_tile_locked(tile_id):
			highlight = Color("#57c878")
		elif _box_selected_ids.has(tile_id) or _pending_group_ids.has(tile_id):
			highlight = Color("#419cff")
		var button := _make_tile_button(tile, _selected_ids.has(tile_id), true, highlight)
		_hand_flow.add_child(button)
	_clear_container(_meld_flow)
	_meld_flow.visible = not _melds.is_empty()
	for meld: Dictionary in _melds:
		var kind_label := _make_label("槓" if str(meld.get("kind", "")) == "kan" else "碰", 12, TEAL, true)
		kind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_meld_flow.add_child(kind_label)
		for tile: Dictionary in meld.get("tiles", []):
			_meld_flow.add_child(_make_small_tile(tile))

func _refresh_claim_slot() -> void:
	if _claim_slot == null:
		return
	var active := _phase == "claim" and not _claim_tile.is_empty()
	_claim_tile_button.visible = active
	_claim_tile_button.disabled = true
	if active:
		_set_tile_face(_claim_tile_button, _claim_tile)
		_claim_tile_button.add_theme_color_override("font_color", _tile_text_color(_claim_tile))
		_claim_tile_button.custom_minimum_size = Vector2(56.0, 66.0)
		var eat_hint := "可吃上家字牌；象牌可碰或槓。" if _claim_source_seat == 3 else "可碰或槓象牌；吃牌只限上家。"
		if Rules.is_sign_tile(_claim_tile):
			eat_hint = "象牌只能碰或槓；不能吃。"
		if _pending_bot_winners.is_empty():
			_claim_text.text = "%s 3 秒未操作會自動跳過；輪到你摸牌前再檢查 Fixet。" % eat_hint
		else:
			_claim_text.text = "實際符合榮和：%s。%s3 秒未操作會由對手榮和。" % ["、".join(_pending_bot_winners), eat_hint]
	else:
		_claim_text.text = ""

func _on_claim_tile_button_pressed() -> void:
	if _phase == "claim":
		_status_text = "吃牌只限上家字牌；象牌可碰或槓。此牌%s；未操作時會自動跳過。" % ("來自上家" if _claim_source_seat == 3 else "不是上家打出的")
		_refresh_all()

func _refresh_buttons() -> void:
	if _discard_button == null:
		return
	if _fixet_prompt_active and _phase == "player_draw" and not _same_id_set(_current_hand_ids(), _fixet_prompt_hand_ids):
		_fixet_prompt_active = false
		_fixet_prompt_wait_types.clear()
		_fixet_prompt_hand_ids.clear()
		call_deferred("_begin_player_turn")
	_discard_button.visible = _phase == "player_discard" and _effective_hand_count() == Rules.HAND_SIZE and _selected_ids.size() == 1 and not _is_tile_locked(_selected_ids[0]) and not _pending_group_ids.has(_selected_ids[0])
	_eat_button.visible = not _riichi_declared and _phase == "claim" and _claim_source_seat == 3 and not Rules.is_sign_tile(_claim_tile)
	var claim_sign := str(_claim_tile.get("sign", "")).to_upper()
	var matching_count := _matching_sign_tiles(_hand, claim_sign).size() if not claim_sign.is_empty() else 0
	_pong_button.visible = not _riichi_declared and _phase == "claim" and matching_count >= 2
	_kan_button.text = "槓象牌" if _phase == "claim" else "暗槓"
	var has_concealed_kan := false
	if _phase == "player_discard":
		for meld: Dictionary in _melds:
			if str(meld.get("kind", "")) == "pong" and not _matching_sign_tiles(_hand, str(meld.get("sign", ""))).is_empty():
				has_concealed_kan = true
				break
		for sign: String in Rules.SIGNS:
			if _matching_sign_tiles(_hand, sign).size() >= 4:
				has_concealed_kan = true
				break
	var can_kan := not _riichi_declared and ((_phase == "claim" and matching_count >= 3 and not _deck.is_empty()) or (_phase == "player_discard" and has_concealed_kan and not _deck.is_empty()))
	_kan_button.visible = can_kan
	_riichi_button.visible = _phase == "player_draw" and _fixet_prompt_active and not _fixet_prompt_wait_types.is_empty() and _melds.is_empty() and not _has_eaten and not _riichi_declared
	_riichi_skip_button.visible = _riichi_button.visible
	var can_ron := false
	if _phase == "claim" and not _claim_tile.is_empty():
		var claim_candidate := _hand_with_melds(_hand, _melds)
		claim_candidate.append(_claim_tile)
		can_ron = bool(Rules.find_winning_declaration(claim_candidate, _dictionary.get_cache(), _melds).get("ok", false))
	_win_button.visible = can_ron
	var grouped_win := _phase in ["player_discard", "claim_grouping"] and _all_hand_tiles_grouped()
	_complete_win_button.visible = grouped_win
	_cancel_win_button.visible = grouped_win


func _effective_hand_count() -> int:
	return _hand.size() + _melds.size() * 3

func _refresh_result() -> void:
	if _result_title == null or _phase != "result":
		return
	if _last_winners.is_empty():
		_result_title.text = "流局"
		_result_body.text = _last_reason
		_result_words.text = ""
		_result_hands_label.text = ""
		return
	_result_title.text = "和牌！" if _last_winners.size() == 1 else "多人同時和牌！"
	_result_body.text = "和牌者：%s
方式：%s" % ["、".join(_last_winners), _last_reason]
	if bool(_last_win.get("clean_parvis", false)):
		_result_body.text += "\n門前清"
	if bool(_last_win.get("fixet", false)):
		_result_body.text += "\n立直：等待 %s" % "、".join(_last_win.get("fixet_wait_types", []))
	var declared_words: Array[String] = []
	for value: Variant in _last_win.get("words", []):
		declared_words.append(str(value))
	if declared_words.is_empty():
		_result_words.text = "牌型須全部分配至有效單字、對子或象牌組合。"
	else:
		var pair_suffix := ""
		if str(_last_win.get("kind", "")) in ["words_and_pair", "words_and_sets"] and not str(_last_win.get("pair_letter", "")).is_empty():
			pair_suffix = "；另有 %s 對子" % str(_last_win.get("pair_letter", ""))
		var penalty := int(_last_win.get("han_penalty", 0))
		var penalty_parts: Array[String] = []
		if bool(_last_win.get("duplicate_word_penalty", false)):
			penalty_parts.append("重複單字 −1 飜")
		if int(_last_win.get("eat_han_penalty", 0)) > 0:
			penalty_parts.append("詐吃 −%d 飜" % int(_last_win.eat_han_penalty))
		var penalty_text := "；" + "、".join(penalty_parts) if not penalty_parts.is_empty() else ("；減 %d 飜" % penalty if penalty > 0 else "")
		var sign_groups: Array[String] = []
		for group_value: Variant in _last_win.get("sign_groups", []):
			if not group_value is Dictionary:
				continue
			var group: Dictionary = group_value
			var set_name := "三條" if str(group.get("kind", "")) == "three_kind" else "四條"
			sign_groups.append("%s %s" % [str(group.get("sign", "")), set_name])
		var groups_text := "；象牌組合：" + "、".join(sign_groups) if not sign_groups.is_empty() else ""
		_result_words.text = "和牌單字：%s%s%s%s" % [", ".join(declared_words), pair_suffix, groups_text, penalty_text]
	var hand_lines: Array[String] = []
	var player_hand := _hand_for_result("你")
	hand_lines.append("[b]你（%d 張）[/b]  %s" % [player_hand.size(), _hand_to_bbcode(player_hand)])
	for bot: Dictionary in _opponents:
		var bot_name := str(bot.get("name", "對手"))
		var shown_hand := _hand_for_result(bot_name)
		hand_lines.append("[b]%s（%d 張）[/b]  %s" % [bot_name, shown_hand.size(), _hand_to_bbcode(shown_hand)])
	_result_hands_label.text = "[b]全員手牌公開[/b]
" + "
".join(hand_lines)

func _on_dictionary_pattern_search_finished(tag: String, pattern: String, words: Array[String], message: String) -> void:
	if tag.begins_with("fixet_pattern:"):
		if not _fixet_scan_active or not _fixet_pattern_contexts.has(tag):
			return
		var context: Dictionary = _fixet_pattern_contexts[tag]
		_fixet_pattern_contexts.erase(tag)
		var letter := str(context.get("letter", ""))
		var grouped: Dictionary = {}
		for group: Dictionary in _word_groups:
			for tile_id: Variant in group.get("ids", []):
				grouped[int(tile_id)] = true
		var loose: Array[Dictionary] = []
		for tile: Dictionary in _hand:
			if not grouped.has(int(tile.get("id", -1))) and not Rules.is_sign_tile(tile):
				loose.append(tile)
		var hypothetical := Rules.make_tile(500000 + _fixet_scan_id, letter)
		loose.append(hypothetical)
		for word: String in words:
			if not Rules.can_form_word(word, loose):
				continue
			if _dictionary.has_result(word):
				if _dictionary.is_verified_valid(word):
					_register_fixet_wait_if_winning(letter)
			else:
				_fixet_scan_words_remaining += 1
				_dictionary.verify_word(word, "fixet_word:%d:%s" % [_fixet_scan_id, letter])
		_fixet_scan_patterns_remaining -= 1
		_finish_dynamic_fixet_scan_if_ready()
		return
	if not tag.begins_with("group_pattern:"):
		return
	var request_id := int(tag.trim_prefix("group_pattern:"))
	if request_id != _active_group_request_id or _pending_group_ids.is_empty():
		return
	var chosen: Array[Dictionary] = []
	for tile_id: int in _pending_group_ids:
		var tile := _find_in_array(_hand, tile_id)
		if tile.is_empty():
			_pending_group_ids.clear()
			_active_group_request_id = 0
			return
		chosen.append(tile)
	var candidates: Array[String] = []
	for word: String in words:
		if Rules.can_form_word(word, chosen):
			if _dictionary.is_verified_valid(word):
				_add_verified_group(_pending_group_ids, word)
				_refresh_all()
				_resume_player_turn_if_ready()
				return
			candidates.append(word)
	if candidates.is_empty():
		_pending_group_ids.clear()
		_active_group_request_id = 0
		_group_checks_remaining = 0
		_status_text = message if not message.is_empty() else "沒有找到符合所選牌與空白牌的合法單字。"
		_refresh_all()
		_resume_player_turn_if_ready()
		return
	_group_checks_remaining = candidates.size()
	for word: String in candidates:
		_dictionary.verify_word(word, "group_check:%d:%s" % [request_id, word])
	_status_text = "找到 %d 個候選單字，正在逐一查核……" % candidates.size()
	_refresh_all()


func _on_dictionary_validation_finished(tag: String, word: String, is_valid: bool, _message: String) -> void:
	if tag.begins_with("fixet_word:"):
		var parts := tag.split(":")
		if parts.size() >= 3 and _fixet_scan_active and int(parts[1]) == _fixet_scan_id:
			if is_valid:
				_register_fixet_wait_if_winning(parts[2])
			_fixet_scan_words_remaining = maxi(0, _fixet_scan_words_remaining - 1)
			_finish_dynamic_fixet_scan_if_ready()
		return
	if tag.begins_with("group_check:"):
		var tag_parts := tag.split(":")
		if tag_parts.size() < 3 or int(tag_parts[1]) != _active_group_request_id or _pending_group_ids.is_empty():
			return
		if is_valid:
			_add_verified_group(_pending_group_ids, word)
			_refresh_all()
			_resume_player_turn_if_ready()
		else:
			_group_checks_remaining -= 1
			if _group_checks_remaining <= 0:
				_pending_group_ids.clear()
				_active_group_request_id = 0
				_box_selected_ids.clear()
				_status_text = "這組牌未查到合法單字；可調整排列後再次框選。"
				_refresh_all()
				_resume_player_turn_if_ready()
		return
	if tag.begins_with("bot_seed:"):
		_bot_seed_completed += 1
		if not is_valid:
			_bot_seed_failed += 1
		if _bot_seed_completed >= _bot_seed_total:
			if _bot_seed_failed == 0:
				_dictionary_status = "字典連線正常：已查核單機對手候選單字。"
			else:
				_dictionary_status = "外部字典暫時無法確認部分對手候選詞；不會以未確認單字判胡。"
		_refresh_all()
		return


func _register_fixet_wait_if_winning(letter: String) -> void:
	if _fixet_scan_wait_types.has(letter) or _remaining_copy_count(letter, false) <= 0:
		return
	var candidate := _hand.duplicate(true)
	candidate.append(Rules.make_tile(500000 + _fixet_scan_id, letter))
	if bool(Rules.find_winning_declaration(candidate, _dictionary.get_cache()).get("ok", false)):
		_fixet_scan_wait_types.append(letter)


func _finish_dynamic_fixet_scan_if_ready() -> void:
	if not _fixet_scan_active or _fixet_scan_patterns_remaining > 0 or _fixet_scan_words_remaining > 0:
		return
	_fixet_scan_active = false
	_fixet_prompt_wait_types = _fixet_scan_wait_types.duplicate()
	_fixet_scan_hand_ids.clear()
	if _fixet_prompt_wait_types.size() in [1, 2]:
		_fixet_prompt_active = true
		_fixet_prompt_hand_ids = _current_hand_ids()
		_status_text = "摸牌前提示：目前聽 %s。宣告 Fixet，或按取消繼續摸牌。" % "、".join(_fixet_prompt_wait_types)
	else:
		_draw_for_player()
	_refresh_all()







func _find_tile(tile_id: int) -> Dictionary:
	return _find_in_array(_hand, tile_id)

func _find_in_array(cards: Array, tile_id: int) -> Dictionary:
	for value: Variant in cards:
		if value is Dictionary and int(value.get("id", -1)) == tile_id:
			return value
	return {}










func _hand_for_result(player_name: String) -> Array:
	var result: Array = []
	var melds: Array = []
	if player_name == "你":
		result = _hand.duplicate(true)
		melds = _melds
	else:
		var bot := _opponent_by_name(player_name)
		if not bot.is_empty():
			result = (bot.get("hand", []) as Array).duplicate(true)
			melds = bot.get("melds", [])
	result.append_array(_hand_with_melds([], melds))
	if _last_winners.has(player_name) and not _last_win_tile.is_empty():
		var already_present := false
		for tile_value: Variant in result:
			if tile_value is Dictionary and int(tile_value.get("id", -1)) == int(_last_win_tile.get("id", -2)):
				already_present = true
				break
		if not already_present:
			result.append(_last_win_tile.duplicate(true))
	return result


func _hand_to_bbcode(hand: Array) -> String:
	var labels: Array[String] = []
	for value: Variant in hand:
		if not value is Dictionary:
			continue
		var tile: Dictionary = value
		var label := _tile_name(tile)
		var color := GOLD_DARK if bool(tile.get("wild", false)) else (RED if Rules.is_vowel_letter(str(tile.get("letter", ""))) else CREAM)
		labels.append("[color=#%s]%s[/color]" % [color.to_html(false), label])
	return "  ".join(labels)


func _opponent_by_name(player_name: String) -> Dictionary:
	for opponent: Dictionary in _opponents:
		if str(opponent.get("name", "")) == player_name:
			return opponent
	return {}


func _remove_discard_by_id(tile_id: int) -> void:
	for index: int in range(_discards.size() - 1, -1, -1):
		if int(_discards[index].get("id", -1)) == tile_id:
			_discards.remove_at(index)
			return


func _claimable_winners(discard_tile: Dictionary, source_seat: int) -> Array[String]:
	return Rules.find_claiming_opponents(_opponents, discard_tile, source_seat, _dictionary.get_cache())


func _opponent_by_seat(seat: int) -> Dictionary:
	for opponent: Dictionary in _opponents:
		if int(opponent.get("seat", -1)) == seat:
			return opponent
	return {}


func _opponent_name(seat: int) -> String:
	var opponent := _opponent_by_seat(seat)
	return str(opponent.get("name", "對手"))


func _tile_name(tile: Dictionary) -> String:
	if tile.has("face_text"):
		return str(tile.face_text)
	if tile.has("sign"):
		return str(tile.sign)
	return "?" if bool(tile.get("wild", false)) else str(tile.get("letter", "·"))


func _turn_description() -> String:
	match _phase:
		"player_draw": return "你的回合 · 自動摸牌"
		"player_discard": return "你的回合 · 打牌"
		"bot_turn": return "對手回合"
		"claim": return "回應棄牌"
		"result": return "本局結束"
		_: return "等待開局"


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_word_list_cache_for_test() -> Dictionary:
	return _dictionary.get_cache()
