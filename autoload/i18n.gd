extends Node

signal locale_changed(locale: String)

const CATALOG_PATHS := {"zh-Hant": "res://localization/zh-Hant.json"}

var _catalogs: Dictionary = {}
var _locale := "zh-Hant"


func _ready() -> void:
	_catalogs["zh-Hant"] = _load_catalog(CATALOG_PATHS["zh-Hant"])
	# This game ships one authored language; saved and OS/browser locale never override it.
	_locale = "zh-Hant"


static func detect_locale(_os_locale: String) -> String:
	return "zh-Hant"


static func resolve_locale(_saved: String, _os_locale: String) -> String:
	return "zh-Hant"


func _load_catalog(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("I18n: missing catalog " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("I18n: invalid catalog " + path)
		return {}
	return parsed


func text(key: String, replacements: Dictionary = {}) -> String:
	var active: Dictionary = _catalogs.get("zh-Hant", {})
	var result := str(active.get(key, key))
	for token: Variant in replacements:
		result = result.replace("{%s}" % str(token), str(replacements[token]))
	return result


func t(key: String, replacements: Dictionary = {}) -> String:
	return text(key, replacements)


func get_locale() -> String:
	return _locale


func set_locale(locale: String) -> void:
	if locale != "zh-Hant" or locale == _locale:
		return
	_locale = "zh-Hant"
	locale_changed.emit(_locale)


func toggle_locale() -> void:
	# Intentionally a no-op: the game has no exposed language selector.
	return


func catalog_keys(locale: String) -> Array:
	return (_catalogs.get("zh-Hant", {}) as Dictionary).keys() if locale == "zh-Hant" else []
