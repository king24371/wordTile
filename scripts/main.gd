extends Control

const Rules := preload("res://scripts/game/word_mahjong_rules.gd")
const DictionaryService := preload("res://scripts/game/word_dictionary_service.gd")
const HandTileButton := preload("res://scripts/ui/hand_tile_button.gd")
const UI_FONT := "res://assets/template/fonts/ui_regular.tres"
const UI_BOLD := "res://assets/template/fonts/ui_bold.tres"
const BOT_SEED_WORDS := ["GAME", "WORD", "TILE", "MOON", "SING", "TREE", "FISH", "BURN", "JULY"]
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
var _opponents: Array[Dictionary] = []
var _discards: Array[Dictionary] = []
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
var _bot_seed_total := BOT_SEED_WORDS.size()
var _win_form_open := false
var _win_context := ""
var _win_candidate_hand: Array[Dictionary] = []
var _win_words_to_verify: Array[String] = []
var _win_results: Dictionary = {}
var _win_errors: Array[String] = []
var _win_pending_count := 0
var _win_request_sequence := 0
var _active_win_request_prefix := ""
var _last_win: Dictionary = {}
var _last_win_tile: Dictionary = {}
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
var _hand_count_label: Label
var _hand_flow: HFlowContainer
var _discard_grid: GridContainer
var _claim_slot: HBoxContainer
var _claim_tile_button: Button
var _claim_text: Label
var _draw_button: Button
var _discard_button: Button
var _eat_button: Button
var _win_button: Button
var _pass_button: Button
var _bot_panels: Array[Dictionary] = []
var _result_title: Label
var _result_body: Label
var _result_words: Label
var _result_hands_label: RichTextLabel
var _win_overlay: Control
var _win_words_entry: LineEdit
var _win_status_label: Label
var _win_verify_button: Button


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
	_build_win_overlay()
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
	var intro := _make_label("摸牌、自由排牌、打牌；和牌時輸入全部英文單字驗字。", 16, MUTED)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var rules := _make_label("108 張牌｜A–Z 各 4 張＋4 張百搭
A、E、I、O、U 母音牌為紅色
14 張全組成有效單字，或 12 字母單字加一對
胡牌時以逗號分隔輸入全部單字", 15, TEXT)
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
	var instruction := _make_label("拖曳手牌自由排列；點選一張牌可打出。只有宣告和牌時才輸入全部單字，以逗號分隔驗證。", 13, MUTED)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instruction)
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
	_win_button = _make_button("和牌／驗字", true, Vector2(132.0, 44.0))
	_win_button.pressed.connect(_claim_win)
	turn_row.add_child(_win_button)
	_pass_button = _make_button("過牌", false, Vector2(88.0, 44.0))
	_pass_button.pressed.connect(_pass_claim)
	turn_row.add_child(_pass_button)
	var dictionary_hint := _make_label("外部字典只在你申報和牌時逐字查核。", 12, MUTED)
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


func _build_win_overlay() -> void:
	_win_overlay = Control.new()
	_win_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.visible = false
	_win_overlay.z_index = 25
	add_child(_win_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.03, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_overlay.add_child(center)
	var panel := _make_panel(SURFACE_DARK, GOLD, Vector2(28.0, 24.0))
	panel.custom_minimum_size = Vector2(620.0, 270.0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := _make_label("申報和牌", 28, GOLD, true)
	content.add_child(title)
	var hint := _make_label("請輸入手牌中所有單字，以逗號分隔（例如 GAME,WORD,TILE）。
14 張全為單字，或 12 張單字加一對相同字母。", 14, CREAM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	_win_words_entry = LineEdit.new()
	_win_words_entry.placeholder_text = "輸入全部單字，例如 GAME,WORD,TILE"
	_win_words_entry.max_length = 200
	_win_words_entry.custom_minimum_size.y = 42.0
	content.add_child(_win_words_entry)
	_win_status_label = _make_label("每個單字都會由外部字典 API 查核。", 14, MUTED)
	_win_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_win_status_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var cancel := _make_button("取消", false, Vector2(104.0, 42.0))
	cancel.pressed.connect(_close_win_form)
	actions.add_child(cancel)
	_win_verify_button = _make_button("查字並確認胡牌", true, Vector2(180.0, 42.0))
	_win_verify_button.pressed.connect(_verify_win_submission)
	actions.add_child(_win_verify_button)

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
	var rules_text := _make_label("• 起手 13 張；摸牌或吃牌後 14 張，打出一張回到 13 張。
• 可拖曳手牌自由排序；點選一張牌後打出。
• 遇到對手棄牌，可自由選擇吃牌；吃牌後若未和，必須打出一張。
• 申報和牌時才以逗號輸入全部單字，外部字典逐一查核；單字不可重複。
• 14 張全組成有效單字可和；或 12 張單字加一對相同字母。
• A、E、I、O、U 母音牌為紅色；? 是空白百搭。
• 其餘玩家和牌時，結算畫面會揭示全部玩家手牌。無碰、槓。", 14, CREAM)
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


func _make_tile_button(tile: Dictionary, selected: bool, draggable: bool = false) -> Button:
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
	var display := "?" if bool(tile.get("wild", false)) else str(tile.get("letter", "·"))
	button.text = display
	var tile_edge := GOLD if selected else GOLD_DARK
	var tile_bg := Color("#f4eedf") if not selected else Color("#f8d994")
	button.add_theme_color_override("font_color", _tile_text_color(tile))
	button.add_theme_color_override("font_hover_color", _tile_text_color(tile).darkened(0.12))
	button.add_theme_stylebox_override("normal", _tile_style(tile_bg, tile_edge, false))
	button.add_theme_stylebox_override("hover", _tile_style(Color("#fff9e9"), GOLD, false))
	button.add_theme_stylebox_override("pressed", _tile_style(Color("#e8d19d"), GOLD, false))
	button.add_theme_stylebox_override("focus", _tile_style(Color("#fff9e9"), TEAL, false))
	if bool(tile.get("wild", false)):
		button.tooltip_text = "空白百搭牌：可代表任意字母。"
	else:
		button.tooltip_text = "拖曳排列；點選後可在你的棄牌回合打出。"
	if tile.has("id"):
		button.pressed.connect(_on_tile_pressed.bind(int(tile.id)))
	return button


func _tile_text_color(tile: Dictionary) -> Color:
	if bool(tile.get("wild", false)):
		return GOLD_DARK
	return RED if Rules.is_vowel_letter(str(tile.get("letter", ""))) else Color("#17352b")

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
	_selected_ids.clear()
	_claim_tile.clear()
	_pending_bot_winners.clear()
	_last_win.clear()
	_last_win_tile.clear()
	_last_winners.clear()
	_last_reason = ""
	_win_form_open = false
	_win_context = ""
	_win_candidate_hand.clear()
	_win_words_to_verify.clear()
	_win_results.clear()
	_win_errors.clear()
	_active_win_request_prefix = ""
	_hand = _draw_cards(13)
	for index: int in BOT_NAMES.size():
		_opponents.append(_make_random_opponent(BOT_NAMES[index], index + 1))
	_phase = "player_draw"
	_status_text = "新局開始。你有 13 張牌，請先摸一張；手牌中的母音 A、E、I、O、U 為紅色。"
	_help_open = false
	_refresh_all()

func _make_random_opponent(name: String, seat: int) -> Dictionary:
	return {"name": name, "hand": _draw_cards(13), "seat": seat}



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
	_status_text = "摸牌完成。可拖曳整理手牌，點選一張打出；和牌時才需輸入單字。"
	_selected_ids.clear()
	_refresh_all()

func _on_tile_pressed(tile_id: int) -> void:
	if _phase != "player_discard":
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
	if _phase in ["title", "result"] or source_tile_id == target_tile_id:
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







func _discard_selected() -> void:
	if _phase != "player_discard" or _hand.size() != 14 or _selected_ids.size() != 1:
		return
	var tile_id := _selected_ids[0]
	var tile := _find_in_array(_hand, tile_id)
	if tile.is_empty():
		return
	_hand.erase(tile)
	_discards.append(tile)
	_selected_ids.clear()
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, tile, 0, _dictionary.get_cache())
	if not _pending_bot_winners.is_empty():
		_remove_discard_by_id(int(tile.id))
		_finish_round(_pending_bot_winners, "搶胡", {}, tile)
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
	var self_result := Rules.find_winning_declaration(bot_hand, _dictionary.get_cache())
	if bool(self_result.get("ok", false)):
		_finish_round([str(bot.get("name", "對手"))], "自摸", self_result)
		return
	bot_hand.erase(drawn)
	bot["hand"] = bot_hand
	_discards.append(drawn)
	_pending_next_seat = (seat + 1) % 4
	_pending_bot_winners = Rules.find_claiming_opponents(_opponents, drawn, seat, _dictionary.get_cache())
	_claim_tile = drawn
	_phase = "claim"
	_selected_ids.clear()
	if _pending_bot_winners.is_empty():
		_status_text = "%s 打出 %s。你可自由吃牌、申報和牌或過牌。" % [str(bot.get("name", "對手")), _tile_name(drawn)]
	else:
		_status_text = "%s 打出 %s；有對手實際符合搶胡牌型。你仍可用同一張牌申報和牌或過牌。" % [str(bot.get("name", "對手")), _tile_name(drawn)]
	_refresh_all()

func _claim_win() -> void:
	if _phase == "player_discard":
		_open_win_form("self")
	elif _phase == "claim" and not _claim_tile.is_empty():
		_open_win_form("claim")


func _open_win_form(context: String) -> void:
	var candidate: Array[Dictionary] = []
	for tile: Dictionary in _hand:
		candidate.append(tile)
	if context == "claim":
		if _claim_tile.is_empty():
			return
		candidate.append(_claim_tile)
	if candidate.size() != Rules.HAND_SIZE:
		_status_text = "申報和牌需要正好 14 張牌。"
		_refresh_all()
		return
	_win_form_open = true
	_win_context = context
	_win_candidate_hand = candidate
	_win_words_entry.text = ""
	_win_status_label.text = "請以逗號分隔手牌中的所有單字；每個單字都會用外部字典 API 查核。"
	_win_verify_button.disabled = false
	_win_overlay.visible = true
	_win_words_entry.grab_focus()
	_refresh_all()


func _close_win_form() -> void:
	_win_form_open = false
	_win_context = ""
	_active_win_request_prefix = ""
	_win_pending_count = 0
	_win_candidate_hand.clear()
	_win_words_to_verify.clear()
	_win_results.clear()
	_win_errors.clear()
	if _win_overlay != null:
		_win_overlay.visible = false
	_refresh_all()


func _verify_win_submission() -> void:
	if not _win_form_open or _win_pending_count > 0:
		return
	var words: Array[String] = []
	for value: String in _win_words_entry.text.split(",", true):
		words.append(value.strip_edges().to_upper())
	var layout := Rules.evaluate_declared_words(_win_candidate_hand, words, {}, false)
	if not bool(layout.get("ok", false)):
		_win_status_label.text = str(layout.get("reason", "單字與手牌不符。"))
		return
	_win_request_sequence += 1
	_active_win_request_prefix = "win_check:%d:" % _win_request_sequence
	_win_words_to_verify = words.duplicate()
	_win_results.clear()
	_win_errors.clear()
	_win_pending_count = words.size()
	_win_verify_button.disabled = true
	_win_status_label.text = "正在向外部字典查核 %d 個單字……" % words.size()
	for word: String in words:
		_dictionary.verify_word(word, _active_win_request_prefix + word)


func _complete_win_submission() -> void:
	var successful := true
	for word: String in _win_words_to_verify:
		if not bool(_win_results.get(word, false)):
			successful = false
	if not successful:
		_win_status_label.text = "字典未確認：%s。請修正單字或確認連線後重試。" % "；".join(_win_errors)
		_win_verify_button.disabled = false
		return
	var result := Rules.evaluate_declared_words(_win_candidate_hand, _win_words_to_verify, _dictionary.get_cache())
	if not bool(result.get("ok", false)):
		_win_status_label.text = str(result.get("reason", "申報單字與手牌不符。"))
		_win_verify_button.disabled = false
		return
	var context := _win_context
	_win_form_open = false
	_win_context = ""
	_win_overlay.visible = false
	if context == "claim":
		var claimed_tile := _claim_tile.duplicate(true)
		var winners := _pending_bot_winners.duplicate()
		if not winners.has("你"):
			winners.append("你")
		_hand.append(claimed_tile)
		_remove_discard_by_id(int(claimed_tile.get("id", -1)))
		_claim_tile.clear()
		_finish_round(winners, "搶胡", result, claimed_tile)
	else:
		_finish_round(["你"], "自摸", result)

func _eat_discard() -> void:
	if _phase != "claim" or _claim_tile.is_empty():
		return
	_hand.append(_claim_tile.duplicate(true))
	_remove_discard_by_id(int(_claim_tile.get("id", -1)))
	_claim_tile.clear()
	_pending_bot_winners.clear()
	_selected_ids.clear()
	_phase = "player_discard"
	_status_text = "你已自由吃進這張牌。若未和牌，現在必須打出一張牌。"
	_refresh_all()

func _pass_claim() -> void:
	if _phase != "claim":
		return
	if not _claim_tile.is_empty() and not _pending_bot_winners.is_empty():
		var winning_tile := _claim_tile.duplicate(true)
		_remove_discard_by_id(int(winning_tile.get("id", -1)))
		_claim_tile.clear()
		_finish_round(_pending_bot_winners, "搶胡", {}, winning_tile)
		return
	_claim_tile.clear()
	_selected_ids.clear()
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


func _finish_round(winners: Array, reason: String, outcome: Dictionary = {}, winning_tile: Dictionary = {}) -> void:
	_phase = "result"
	_win_form_open = false
	_win_context = ""
	_active_win_request_prefix = ""
	_win_pending_count = 0
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
	_win_overlay.visible = _win_form_open and _phase != "title" and _phase != "result"
	if _status_label != null:
		_status_label.text = _status_text
	if _wall_label != null:
		_wall_label.text = "牌牆 %d" % _deck.size()
	if _turn_label != null:
		_turn_label.text = _turn_description()
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
		if _phase == "result" and _last_winners.has(str(bot.get("name", ""))):
			detail.text = "已和牌 · %d 張" % _hand_for_result(str(bot.get("name", ""))).size()
		elif _phase == "bot_turn" and _status_text.begins_with(str(bot.get("name", ""))):
			detail.text = "摸牌中"
		else:
			detail.text = "%d 張暗牌" % bot_hand.size()

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
	var label := _make_label(_tile_name(tile), 19, _tile_text_color(tile), true)
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
	for tile: Dictionary in _hand:
		var tile_id := int(tile.get("id", -1))
		var button := _make_tile_button(tile, _selected_ids.has(tile_id), true)
		_hand_flow.add_child(button)

func _refresh_claim_slot() -> void:
	if _claim_slot == null:
		return
	var active := _phase == "claim" and not _claim_tile.is_empty()
	_claim_tile_button.visible = active
	_claim_tile_button.disabled = true
	if active:
		_claim_tile_button.text = _tile_name(_claim_tile)
		_claim_tile_button.add_theme_color_override("font_color", _tile_text_color(_claim_tile))
		_claim_tile_button.custom_minimum_size = Vector2(56.0, 66.0)
		if _pending_bot_winners.is_empty():
			_claim_text.text = "此棄牌可自由吃牌；過牌將輪到下一位。"
		else:
			_claim_text.text = "實際符合搶胡：%s。仍可吃牌；過牌會讓對手和牌。" % "、".join(_pending_bot_winners)
	else:
		_claim_text.text = ""

func _on_claim_tile_button_pressed() -> void:
	if _phase == "claim":
		_status_text = "可自由吃進這張棄牌；若對手符合搶胡，選擇過牌才會讓對手和牌。"
		_refresh_all()

func _refresh_buttons() -> void:
	if _draw_button == null:
		return
	_draw_button.disabled = _phase != "player_draw" or _win_form_open
	_discard_button.disabled = _phase != "player_discard" or _hand.size() != 14 or _selected_ids.size() != 1 or _win_form_open
	_eat_button.disabled = _phase != "claim" or _win_form_open
	_pass_button.disabled = _phase != "claim" or _win_form_open
	var can_declare := (_phase == "player_discard" and _hand.size() == Rules.HAND_SIZE) or (_phase == "claim" and not _claim_tile.is_empty() and _hand.size() == Rules.HAND_SIZE - 1)
	_win_button.disabled = not can_declare or _win_form_open

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
	var declared_words: Array[String] = []
	for value: Variant in _last_win.get("words", []):
		declared_words.append(str(value))
	if declared_words.is_empty():
		_result_words.text = "14 張牌須全部分配至有效單字，或有效單字加一對。"
	else:
		var pair_suffix := ""
		if str(_last_win.get("kind", "")) == "words_and_pair":
			pair_suffix = "；另有 %s 對子" % str(_last_win.get("pair_letter", ""))
		_result_words.text = "和牌單字：%s%s" % [", ".join(declared_words), pair_suffix]
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

func _on_dictionary_validation_finished(tag: String, word: String, is_valid: bool, message: String) -> void:
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
	if _active_win_request_prefix.is_empty() or not tag.begins_with(_active_win_request_prefix):
		return
	_win_results[word] = is_valid
	if not is_valid:
		_win_errors.append("%s（%s）" % [word, message])
	_win_pending_count -= 1
	if _win_pending_count <= 0:
		_active_win_request_prefix = ""
		_complete_win_submission()
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
	if player_name == "你":
		result = _hand.duplicate(true)
	else:
		var bot := _opponent_by_name(player_name)
		if not bot.is_empty():
			result = (bot.get("hand", []) as Array).duplicate(true)
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
