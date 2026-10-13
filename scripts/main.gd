extends Control

const Rules := preload("res://scripts/game/word_mahjong_rules.gd")
const DictionaryService := preload("res://scripts/game/word_dictionary_service.gd")
const UI_FONT := "res://assets/template/fonts/ui_regular.tres"
const UI_BOLD := "res://assets/template/fonts/ui_bold.tres"
const BOT_SEED_WORDS := ["GAME", "WORD", "TILE", "MOON", "SING", "TREE", "FISH", "BURN", "JULY"]
const BOT_PROFILES := [
	{"name": "青竹", "words": ["GAME", "WORD", "TILE"], "wait_letter": "A"},
	{"name": "墨玉", "words": ["MOON", "SING", "TREE"], "wait_letter": "A"},
	{"name": "金雀", "words": ["FISH", "BURN", "JULY"], "wait_letter": "A"},
]
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
var _opponents: Array[Dictionary] = []
var _discards: Array[Dictionary] = []
var _word_groups: Array[Dictionary] = []
var _pair_group: Dictionary = {}
var _selected_ids: Array[int] = []
var _claim_tile: Dictionary = {}
var _pending_bot_winners: Array[String] = []
var _pending_next_seat := 0
var _round_number := 0
var _phase := "title"
var _status_text := ""
var _dictionary_status := "正在連線外部字典……"
var _bot_seed_completed := 0
var _bot_seed_failed := 0
var _bot_seed_total := 9
var _pending_word_tag := ""
var _pending_word := ""
var _pending_word_ids: Array[int] = []
var _request_sequence := 0
var _last_win: Dictionary = {}
var _last_winners: Array[String] = []
var _last_reason := ""
var _help_open := false

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
var _group_label: Label
var _hand_count_label: Label
var _hand_flow: HFlowContainer
var _discard_grid: GridContainer
var _claim_slot: HBoxContainer
var _claim_tile_button: Button
var _claim_text: Label
var _word_entry: LineEdit
var _pair_entry: LineEdit
var _verify_button: Button
var _pair_button: Button
var _clear_button: Button
var _draw_button: Button
var _discard_button: Button
var _eat_button: Button
var _win_button: Button
var _pass_button: Button
var _bot_panels: Array[Dictionary] = []
var _result_title: Label
var _result_body: Label
var _result_words: Label


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
	_build_title_view()
	_build_game_view()
	_build_result_overlay()
	_build_help_overlay()
	_start_bot_word_checks()
	_show_title()


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
	var intro := _make_label("摸牌、組字、打牌。把 14 張牌完整組成英文單字即可和牌。", 16, MUTED)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var rules := _make_label("108 張牌｜A–Z 各 4 張＋4 張百搭\n可用單字＋一對，或 14 張全組成單字\n與三位單機對手同桌；未和牌不公開組字", 15, TEXT)
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
		_bot_panels.append({"name": name_label, "detail": detail, "seat": index + 1})


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
	var discard_title := _make_label("中央棄牌", 16, CREAM, true)
	discard_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_header.add_child(discard_title)
	var discard_legend := _make_label("最新 16 張", 12, MUTED)
	discard_header.add_child(discard_legend)
	_discard_grid = GridContainer.new()
	_discard_grid.columns = 8
	_discard_grid.add_theme_constant_override("h_separation", 6)
	_discard_grid.add_theme_constant_override("v_separation", 6)
	_discard_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	discard_content.add_child(_discard_grid)
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
	var claim_hint := _make_label("選取這張棄牌，可把它納入單字或對子。", 12, MUTED)
	claim_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_claim_slot.add_child(claim_hint)


func _build_action_area(parent: VBoxContainer) -> void:
	var panel := _make_panel(SURFACE_DARK, GOLD_DARK, Vector2(14.0, 10.0))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var selection_row := HBoxContainer.new()
	selection_row.add_theme_constant_override("separation", 10)
	content.add_child(selection_row)
	var instruction := _make_label("組字：選牌後輸入英文；? 百搭牌可代替任意字母。", 13, MUTED)
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(instruction)
	_group_label = _make_label("私下組字 0 組｜對子 0 組", 13, GOLD)
	selection_row.add_child(_make_chip(_group_label))
	var word_row := HBoxContainer.new()
	word_row.add_theme_constant_override("separation", 8)
	content.add_child(word_row)
	_word_entry = LineEdit.new()
	_word_entry.placeholder_text = "輸入單字，例如 CAT"
	_word_entry.max_length = 14
	_word_entry.custom_minimum_size = Vector2(220.0, 40.0)
	_word_entry.text_changed.connect(func(_text: String) -> void: _refresh_buttons())
	word_row.add_child(_word_entry)
	_verify_button = _make_button("字典查字並組成單字", true, Vector2(198.0, 42.0))
	_verify_button.pressed.connect(_verify_selected_word)
	word_row.add_child(_verify_button)
	var pair_label := _make_label("對子字母", 13, MUTED)
	word_row.add_child(pair_label)
	_pair_entry = LineEdit.new()
	_pair_entry.placeholder_text = "A"
	_pair_entry.max_length = 1
	_pair_entry.custom_minimum_size = Vector2(54.0, 40.0)
	_pair_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_row.add_child(_pair_entry)
	_pair_button = _make_button("組成對子", false, Vector2(112.0, 42.0))
	_pair_button.pressed.connect(_make_selected_pair)
	word_row.add_child(_pair_button)
	_clear_button = _make_button("清除私下組字", false, Vector2(132.0, 42.0))
	_clear_button.pressed.connect(_clear_groups)
	word_row.add_child(_clear_button)
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	content.add_child(turn_row)
	_draw_button = _make_button("摸一張", true, Vector2(110.0, 44.0))
	_draw_button.pressed.connect(_draw_for_player)
	turn_row.add_child(_draw_button)
	_discard_button = _make_button("打出選取牌", false, Vector2(136.0, 44.0))
	_discard_button.pressed.connect(_discard_selected)
	turn_row.add_child(_discard_button)
	_eat_button = _make_button("吃牌", false, Vector2(92.0, 44.0))
	_eat_button.pressed.connect(_eat_discard)
	turn_row.add_child(_eat_button)
	_win_button = _make_button("和牌", true, Vector2(100.0, 44.0))
	_win_button.pressed.connect(_claim_win)
	turn_row.add_child(_win_button)
	_pass_button = _make_button("過牌", false, Vector2(88.0, 44.0))
	_pass_button.pressed.connect(_pass_claim)
	turn_row.add_child(_pass_button)
	var dictionary_hint := _make_label("Datamuse 先查，Free Dictionary API 備援；未確認不計入。", 12, MUTED)
	dictionary_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dictionary_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	_hand_flow = HFlowContainer.new()
	_hand_flow.add_theme_constant_override("h_separation", 6)
	_hand_flow.add_theme_constant_override("v_separation", 4)
	_hand_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_hand_flow)


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
	var panel := _make_panel(SURFACE_DARK, GOLD, Vector2(32.0, 26.0))
	panel.custom_minimum_size = Vector2(520.0, 320.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	_result_title = _make_label("牌局結束", 34, GOLD, true)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_result_title)
	_result_body = _make_label("", 18, CREAM)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_result_body)
	_result_words = _make_label("", 15, MUTED)
	_result_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_result_words)
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
	panel.custom_minimum_size = Vector2(560.0, 360.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := _make_label("玩法速讀", 28, GOLD, true)
	content.add_child(title)
	var rules_text := _make_label("• 起手 13 張；摸牌後 14 張，打出一張回到 13 張。\n• 把牌選起來，輸入對應英文單字；單字至少 2 字母，須由外部字典 API 確認。\n• 同一張牌不能重複使用；不同單字可共用相同字母，但不能重複同一單字。\n• 14 張全組成單字可和；或 12 張組成單字、另加一對相同字母。\n• ? 是百搭牌。吃牌時，棄牌必須加入有效單字或對子；吃後若未和，必須打出一張。\n• 未和牌前組字保持私下；沒有碰、槓。棄牌可以搶胡，也可能多人同時胡。", 15, CREAM)
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


func _make_tile_button(tile: Dictionary, selected: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_font_override("font", load(UI_BOLD) as Font)
	var display := "?" if bool(tile.get("wild", false)) else str(tile.get("letter", "·"))
	button.text = display
	var is_grouped := _tile_is_grouped(int(tile.get("id", -1)))
	var tile_edge := GOLD if selected or is_grouped else GOLD_DARK
	var tile_bg := Color("#f4eedf") if not selected else Color("#f8d994")
	button.add_theme_color_override("font_color", Color("#17352b"))
	button.add_theme_color_override("font_hover_color", Color("#071d18"))
	button.add_theme_stylebox_override("normal", _tile_style(tile_bg, tile_edge, is_grouped))
	button.add_theme_stylebox_override("hover", _tile_style(Color("#fff9e9"), GOLD, is_grouped))
	button.add_theme_stylebox_override("pressed", _tile_style(Color("#e8d19d"), GOLD, is_grouped))
	button.add_theme_stylebox_override("focus", _tile_style(Color("#fff9e9"), TEAL, is_grouped))
	if bool(tile.get("wild", false)):
		button.tooltip_text = "空白百搭牌：在輸入單字時可代表任意字母。"
	elif is_grouped:
		button.tooltip_text = "此牌已列入私下組字；按「清除私下組字」可重新分配。"
	else:
		button.tooltip_text = "選取這張牌來組字、配對或打出。"
	if tile.has("id"):
		button.pressed.connect(_on_tile_pressed.bind(int(tile.id)))
	return button


func _tile_style(background: Color, edge: Color, grouped: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = TEAL if grouped else edge
	style.set_border_width_all(2 if grouped else 1)
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
	_opponents.clear()
	_discards.clear()
	_word_groups.clear()
	_pair_group.clear()
	_selected_ids.clear()
	_claim_tile.clear()
	_pending_bot_winners.clear()
	_last_win.clear()
	_last_winners.clear()
	_pending_word_tag = ""
	_pending_word_ids.clear()
	var profile_one := _reserve_profile(BOT_PROFILES[0])
	var profile_two := _reserve_profile(BOT_PROFILES[1])
	var profile_three := _reserve_profile(BOT_PROFILES[2])
	_hand = _draw_cards(13)
	var first_opponent := profile_one if not profile_one.is_empty() else _make_random_opponent("青竹", 1)
	first_opponent["seat"] = 1
	var second_opponent := profile_two if not profile_two.is_empty() else _make_random_opponent("墨玉", 2)
	second_opponent["seat"] = 2
	var third_opponent := profile_three if not profile_three.is_empty() else _make_random_opponent("金雀", 3)
	third_opponent["seat"] = 3
	_opponents = [first_opponent, second_opponent, third_opponent]
	_phase = "player_draw"
	_status_text = "新局開始。你有 13 張牌，請先摸一張。"
	_help_open = false
	_refresh_all()


func _reserve_profile(profile_spec: Dictionary) -> Dictionary:
	var hand: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	for word_value: Variant in profile_spec.get("words", []):
		var word := str(word_value)
		var ids: Array[int] = []
		for index: int in word.length():
			var tile := _take_letter(word.substr(index, 1))
			if tile.is_empty():
				return {}
			hand.append(tile)
			ids.append(int(tile.id))
		groups.append({"word": word, "tile_ids": ids})
	var wait_letter := str(profile_spec.get("wait_letter", "A"))
	var wait_tile := _take_letter(wait_letter)
	if wait_tile.is_empty():
		return {}
	hand.append(wait_tile)
	return {
		"name": str(profile_spec.get("name", "對手")),
		"hand": hand,
		"profile": {"word_groups": groups, "wait_tile_id": int(wait_tile.id), "wait_letter": wait_letter},
		"seat": -1,
	}


func _make_random_opponent(name: String, seat: int) -> Dictionary:
	return {"name": name, "hand": _draw_cards(13), "profile": {}, "seat": seat}


func _take_letter(letter: String) -> Dictionary:
	for index: int in range(_deck.size() - 1, -1, -1):
		var tile: Dictionary = _deck[index]
		if not bool(tile.get("wild", false)) and str(tile.get("letter", "")) == letter:
			return _deck.pop_at(index)
	return {}


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
	if _deck.is_empty():
		_finish_round([], "牌牆已空，本局流局。")
		return
	_hand.append(_deck.pop_back())
	_phase = "player_discard"
	_status_text = "摸牌完成。組字或整理後，選一張牌打出。"
	_selected_ids.clear()
	_refresh_all()


func _on_tile_pressed(tile_id: int) -> void:
	var tile := _find_tile(tile_id)
	if tile.is_empty():
		return
	if _tile_is_grouped(tile_id):
		_status_text = "這張牌已在私下組字中；先清除組字，再重新分配。"
		_refresh_all()
		return
	if _selected_ids.has(tile_id):
		_selected_ids.erase(tile_id)
	else:
		_selected_ids.append(tile_id)
	_selected_ids.sort()
	_refresh_all()


func _verify_selected_word() -> void:
	if not _grouping_allowed():
		_status_text = "目前不能組字，請等待你的回合或對手的棄牌。"
		_refresh_all()
		return
	var word := _word_entry.text.strip_edges().to_upper()
	var tiles := _selected_tiles()
	if tiles.size() < 2 or not Rules.can_form_word(word, tiles):
		_status_text = "所選牌數需等於單字長度；實體字母要相符，? 可代任意字母。"
		_refresh_all()
		return
	for group: Dictionary in _word_groups:
		if str(group.get("word", "")).to_upper() == word:
			_status_text = "同一手牌不能重複組成相同單字。"
			_refresh_all()
			return
	_request_sequence += 1
	_pending_word_tag = "player_word:" + str(_request_sequence)
	_pending_word = word
	_pending_word_ids = _selected_ids.duplicate()
	_status_text = "正在向外部字典 API 查詢 %s……" % word
	_dictionary.verify_word(word, _pending_word_tag)
	_refresh_all()


func _make_selected_pair() -> void:
	if not _grouping_allowed():
		return
	var tiles := _selected_tiles()
	var pair_letter := _pair_entry.text.strip_edges().to_upper()
	if pair_letter.is_empty():
		for tile: Dictionary in tiles:
			if not bool(tile.get("wild", false)):
				pair_letter = str(tile.get("letter", ""))
				break
	if not Rules.can_form_pair(tiles, pair_letter):
		_status_text = "選取兩張相同字母；若使用百搭牌，請填寫它代表的字母。"
		_refresh_all()
		return
	if not _pair_group.is_empty():
		_status_text = "目前只能有一對；先清除私下組字即可更換。"
		_refresh_all()
		return
	_pair_group = {"tile_ids": _selected_ids.duplicate(), "letter": pair_letter}
	_selected_ids.clear()
	_status_text = "對子已記為私下牌組；尚未和牌前不會公開。"
	_refresh_all()


func _clear_groups() -> void:
	_word_groups.clear()
	_pair_group.clear()
	_selected_ids.clear()
	_status_text = "已清除私下組字，牌仍留在手牌中。"
	_refresh_all()


func _discard_selected() -> void:
	if _phase != "player_discard" or _hand.size() != 14 or _selected_ids.size() != 1:
		return
	var tile_id := _selected_ids[0]
	var tile := _find_in_array(_hand, tile_id)
	if tile.is_empty():
		return
	_remove_groups_using_tile(tile_id)
	_hand.erase(tile)
	_discards.append(tile)
	_selected_ids.clear()
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, tile, 0, _dictionary.get_cache())
	if not _pending_bot_winners.is_empty():
		_finish_round(_pending_bot_winners, "搶胡")
		return
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
	var profile: Dictionary = bot.get("profile", {})
	if not profile.is_empty():
		var self_pair := {"tile_ids": [int(profile.get("wait_tile_id", -1)), int(drawn.get("id", -1))], "letter": str(profile.get("wait_letter", ""))}
		var self_result := Rules.evaluate_win(bot_hand, profile.get("word_groups", []), self_pair, _dictionary.get_cache())
		if bool(self_result.get("ok", false)):
			_finish_round([str(bot.get("name", "對手"))], "自摸", self_result)
			return
	# The simulated opponents discard their draw when no verified win is available.
	bot_hand.erase(drawn)
	bot["hand"] = bot_hand
	_discards.append(drawn)
	_pending_next_seat = (seat + 1) % 4
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, drawn, seat, _dictionary.get_cache())
	_claim_tile = drawn
	_phase = "claim"
	_selected_ids.clear()
	if _pending_bot_winners.is_empty():
		_status_text = "%s 打出 %s。你可以組字／配對吃牌，或過牌。" % [str(bot.get("name", "對手")), _tile_name(drawn)]
	else:
		_status_text = "%s 打出 %s；有對手可搶胡。你仍可用同一張牌申告和牌。" % [str(bot.get("name", "對手")), _tile_name(drawn)]
	_refresh_all()


func _claim_win() -> void:
	if _phase == "claim" and not _claim_tile.is_empty():
		var candidate := _hand.duplicate()
		candidate.append(_claim_tile)
		var result := Rules.evaluate_win(candidate, _word_groups, _pair_group, _dictionary.get_cache())
		if not bool(result.get("ok", false)):
			_status_text = str(result.get("reason", "目前尚未符合和牌條件。"))
			_refresh_all()
			return
		var winners := _pending_bot_winners.duplicate()
		winners.append("你")
		_hand.append(_claim_tile)
		_remove_discard_by_id(int(_claim_tile.id))
		_claim_tile.clear()
		_finish_round(winners, "搶胡", result)
		return
	if _phase == "player_discard":
		var result := Rules.evaluate_win(_hand, _word_groups, _pair_group, _dictionary.get_cache())
		if not bool(result.get("ok", false)):
			_status_text = str(result.get("reason", "目前尚未符合和牌條件。"))
			_refresh_all()
			return
		_finish_round(["你"], "自摸", result)


func _eat_discard() -> void:
	if _phase != "claim" or _claim_tile.is_empty():
		return
	if not _pending_bot_winners.is_empty():
		_status_text = "已有對手以這張棄牌搶胡；此時只能申告同一張牌的和牌或過牌。"
		_refresh_all()
		return
	if not _claim_tile_is_grouped():
		_status_text = "先選取這張棄牌與手牌，驗證成單字或配成對子，再吃牌。"
		_refresh_all()
		return
	var candidate := _hand.duplicate()
	candidate.append(_claim_tile)
	var result := Rules.evaluate_win(candidate, _word_groups, _pair_group, _dictionary.get_cache())
	_hand.append(_claim_tile)
	_remove_discard_by_id(int(_claim_tile.id))
	_claim_tile.clear()
	_selected_ids.clear()
	if bool(result.get("ok", false)):
		_finish_round(["你"], "吃牌後和牌", result)
		return
	_phase = "player_discard"
	_status_text = "吃牌完成。若未和牌，現在必須打出一張牌。"
	_refresh_all()


func _pass_claim() -> void:
	if _phase != "claim":
		return
	if not _claim_tile.is_empty():
		_remove_groups_using_tile(int(_claim_tile.id))
	_claim_tile.clear()
	_selected_ids.clear()
	if not _pending_bot_winners.is_empty():
		_finish_round(_pending_bot_winners, "搶胡")
		return
	var next_seat := _pending_next_seat
	if next_seat == 0:
		_phase = "player_draw"
		_status_text = "輪到你，請摸一張牌。"
		_refresh_all()
	else:
		call_deferred("_run_bot_turn", next_seat)


func _open_claim_window(discard_tile: Dictionary, source_seat: int) -> void:
	_claim_tile = discard_tile.duplicate(true)
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, _claim_tile, source_seat, _dictionary.get_cache())
	_pending_next_seat = (source_seat + 1) % 4
	_phase = "claim"
	_selected_ids.clear()
	_refresh_all()


func _finish_round(winners: Array, reason: String, outcome: Dictionary = {}) -> void:
	_phase = "result"
	_last_winners = []
	for winner_value: Variant in winners:
		var winner := str(winner_value)
		if not _last_winners.has(winner):
			_last_winners.append(winner)
	_last_reason = reason
	_last_win = outcome.duplicate(true)
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
	if _group_label != null:
		_group_label.text = "私下組字 %d 組｜對子 %d 組" % [_word_groups.size(), 0 if _pair_group.is_empty() else 1]
	if _hand_count_label != null:
		_hand_count_label.text = "%d 張" % _hand.size()
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
		if bot.is_empty():
			name_label.text = "等待發牌"
			detail.text = "13 張暗牌"
			continue
		name_label.text = str(bot.get("name", "對手"))
		var bot_hand: Array = bot.get("hand", [])
		var state := "13 張暗牌"
		if _phase == "result" and _last_winners.has(str(bot.get("name", ""))):
			state = "已和牌 · %d 張" % bot_hand.size()
		elif _phase == "bot_turn" and _status_text.begins_with(str(bot.get("name", ""))):
			state = "摸牌中"
		elif not (bot.get("profile", {}) as Dictionary).is_empty():
			state = "觀望中"
		else:
			state = "整理手牌"
		detail.text = state


func _refresh_discards() -> void:
	if _discard_grid == null:
		return
	_clear_container(_discard_grid)
	if _discards.is_empty():
		var empty := _make_label("尚無棄牌", 14, MUTED)
		empty.custom_minimum_size = Vector2(330.0, 58.0)
		_discard_grid.add_child(empty)
		return
	var first := maxi(0, _discards.size() - 16)
	for index: int in range(first, _discards.size()):
		var tile: Dictionary = _discards[index]
		var button := _make_small_tile(tile)
		_discard_grid.add_child(button)


func _make_small_tile(tile: Dictionary) -> Control:
	var label := _make_label(_tile_name(tile), 19, Color("#17352b"), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(38.0, 48.0)
	var panel := PanelContainer.new()
	var style := _tile_style(Color("#f0e7d3"), GOLD_DARK, false)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	return panel


func _refresh_hand() -> void:
	if _hand_flow == null:
		return
	_clear_container(_hand_flow)
	var sorted_hand := _hand.duplicate()
	sorted_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("wild", false)) != bool(b.get("wild", false)):
			return not bool(a.get("wild", false))
		return str(a.get("letter", "")) < str(b.get("letter", ""))
	)
	for tile: Dictionary in sorted_hand:
		var tile_id := int(tile.get("id", -1))
		var button := _make_tile_button(tile, _selected_ids.has(tile_id))
		_hand_flow.add_child(button)


func _refresh_claim_slot() -> void:
	if _claim_slot == null:
		return
	var active := _phase == "claim" and not _claim_tile.is_empty()
	_claim_tile_button.visible = active
	if active:
		_claim_tile_button.text = _tile_name(_claim_tile)
		_claim_tile_button.custom_minimum_size = Vector2(56.0, 66.0)
		# The claim tile is not added to the hand until the claim is accepted.
		_claim_text.text = "同一棄牌可供搶胡／吃牌。" if _pending_bot_winners.is_empty() else "可搶胡：%s" % "、".join(_pending_bot_winners)
	else:
		_claim_text.text = ""


func _on_claim_tile_button_pressed() -> void:
	if not _claim_tile.is_empty():
		_on_tile_pressed(int(_claim_tile.get("id", -1)))


func _refresh_buttons() -> void:
	if _draw_button == null:
		return
	_draw_button.disabled = _phase != "player_draw"
	_discard_button.disabled = _phase != "player_discard" or _hand.size() != 14 or _selected_ids.size() != 1
	_verify_button.disabled = not _grouping_allowed() or _selected_ids.size() < 2 or not Rules.is_word_shape_valid(_word_entry.text)
	_pair_button.disabled = not _grouping_allowed() or _selected_ids.size() != 2 or not _pair_group.is_empty()
	_clear_button.disabled = _word_groups.is_empty() and _pair_group.is_empty()
	_eat_button.disabled = _phase != "claim" or not _pending_bot_winners.is_empty() or not _claim_tile_is_grouped()
	_pass_button.disabled = _phase != "claim"
	var win_allowed := false
	if _phase == "player_discard":
		win_allowed = bool(Rules.evaluate_win(_hand, _word_groups, _pair_group, _dictionary.get_cache()).get("ok", false))
	elif _phase == "claim" and not _claim_tile.is_empty():
		var candidate := _hand.duplicate()
		candidate.append(_claim_tile)
		win_allowed = bool(Rules.evaluate_win(candidate, _word_groups, _pair_group, _dictionary.get_cache()).get("ok", false))
	_win_button.disabled = not win_allowed


func _refresh_result() -> void:
	if _result_title == null or _phase != "result":
		return
	if _last_winners.is_empty():
		_result_title.text = "流局"
		_result_body.text = _last_reason
	else:
		_result_title.text = "和牌！" if _last_winners.size() == 1 else "多人同時和牌！"
		_result_body.text = "和牌者：%s\n方式：%s" % ["、".join(_last_winners), _last_reason]
	if _last_winners.has("你") and not _word_groups.is_empty():
		var words: Array[String] = []
		for group: Dictionary in _word_groups:
			words.append(str(group.get("word", "")).to_upper())
		var suffix := ""
		if not _pair_group.is_empty():
			suffix = "；另有 %s 對子" % str(_pair_group.get("letter", ""))
		_result_words.text = "本局單字：%s%s" % ["、".join(words), suffix]
	else:
		_result_words.text = "14 張牌須全部分配至有效單字，或有效單字加一對。"


func _on_dictionary_validation_finished(tag: String, word: String, is_valid: bool, message: String) -> void:
	if tag.begins_with("bot_seed:"):
		_bot_seed_completed += 1
		if not is_valid:
			_bot_seed_failed += 1
		if _bot_seed_completed >= _bot_seed_total:
			if _bot_seed_failed == 0:
				_dictionary_status = "字典連線正常：已查核單機對手牌型用字。"
			else:
				_dictionary_status = "字典暫時無法確認部分對手用字；該對手牌型不會判為有效。"
		_refresh_all()
		return
	if tag != _pending_word_tag:
		return
	_pending_word_tag = ""
	if not is_valid:
		_status_text = "%s %s" % [message, "請確認拼字或稍後重試。"]
		_refresh_all()
		return
	var available := _available_tiles()
	var tiles: Array = []
	for tile: Dictionary in available:
		if _pending_word_ids.has(int(tile.get("id", -1))):
			tiles.append(tile)
	if tiles.size() != _pending_word_ids.size() or not Rules.can_form_word(word, tiles):
		_status_text = "字典已確認，但牌局狀態已改變；請重新選牌。"
		_refresh_all()
		return
	if _group_uses_any(_pending_word_ids):
		_status_text = "其中有牌已分配到其他私下牌組。"
		_refresh_all()
		return
	_word_groups.append({"word": word, "tile_ids": _pending_word_ids.duplicate()})
	_selected_ids.clear()
	_status_text = "%s 已由外部字典確認，並記為私下單字組。" % word
	_pending_word_ids.clear()
	_pending_word = ""
	_refresh_all()


func _grouping_allowed() -> bool:
	return _phase in ["player_draw", "player_discard", "claim"] and _pending_word_tag.is_empty()


func _selected_tiles() -> Array:
	var result: Array = []
	for tile: Dictionary in _available_tiles():
		if _selected_ids.has(int(tile.get("id", -1))):
			result.append(tile)
	return result


func _available_tiles() -> Array:
	var result: Array = _hand.duplicate()
	if _phase == "claim" and not _claim_tile.is_empty() and _find_in_array(result, int(_claim_tile.get("id", -1))).is_empty():
		result.append(_claim_tile)
	return result


func _find_tile(tile_id: int) -> Dictionary:
	var found := _find_in_array(_hand, tile_id)
	if not found.is_empty():
		return found
	if _phase == "claim" and int(_claim_tile.get("id", -1)) == tile_id:
		return _claim_tile
	return {}


func _find_in_array(cards: Array, tile_id: int) -> Dictionary:
	for value: Variant in cards:
		if value is Dictionary and int(value.get("id", -1)) == tile_id:
			return value
	return {}


func _tile_is_grouped(tile_id: int) -> bool:
	for group: Dictionary in _word_groups:
		if (group.get("tile_ids", []) as Array).has(tile_id):
			return true
	return (not _pair_group.is_empty()) and (_pair_group.get("tile_ids", []) as Array).has(tile_id)


func _group_uses_any(ids: Array) -> bool:
	for value: Variant in ids:
		if _tile_is_grouped(int(value)):
			return true
	return false


func _claim_tile_is_grouped() -> bool:
	if _claim_tile.is_empty():
		return false
	return _tile_is_grouped(int(_claim_tile.get("id", -1)))


func _remove_groups_using_tile(tile_id: int) -> void:
	var retained: Array[Dictionary] = []
	for group: Dictionary in _word_groups:
		if not (group.get("tile_ids", []) as Array).has(tile_id):
			retained.append(group)
	_word_groups = retained
	if not _pair_group.is_empty() and (_pair_group.get("tile_ids", []) as Array).has(tile_id):
		_pair_group.clear()


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
	return "?" if bool(tile.get("wild", false)) else str(tile.get("letter", "·"))


func _turn_description() -> String:
	match _phase:
		"player_draw": return "你的回合 · 摸牌"
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
