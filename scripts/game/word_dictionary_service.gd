class_name WordDictionaryService
extends Node

signal validation_finished(tag: String, word: String, is_valid: bool, message: String)

const Rules := preload("res://scripts/game/word_mahjong_rules.gd")
const DATAMUSE_ROOT := "https://api.datamuse.com/words?sp="
const DICTIONARY_API_ROOT := "https://api.dictionaryapi.dev/api/v2/entries/en/"
const MAX_CONCURRENT_REQUESTS := 4
const REQUEST_TIMEOUT_SECONDS := 8.0

var _cache: Dictionary = {}
var _queue: Array[String] = []
var _tags_by_word: Dictionary = {}
var _active_requests: Dictionary = {}


func verify_word(raw_word: String, tag: String = "") -> void:
	var word := raw_word.strip_edges().to_upper()
	if not Rules.is_word_shape_valid(word):
		call_deferred("_emit_result", tag, word, false, "單字必須至少有兩個英文字母。")
		return
	if _cache.has(word):
		var cached_ok := bool(_cache[word])
		call_deferred("_emit_result", tag, word, cached_ok, "已由外部字典確認。" if cached_ok else "外部字典未找到這個單字。")
		return
	if _tags_by_word.has(word):
		(_tags_by_word[word] as Array).append(tag)
		return
	_tags_by_word[word] = [tag]
	_queue.append(word)
	_start_pending_requests()


func has_result(word: String) -> bool:
	return _cache.has(word.strip_edges().to_upper())


func is_verified_valid(word: String) -> bool:
	return bool(_cache.get(word.strip_edges().to_upper(), false))


func get_cache() -> Dictionary:
	return _cache.duplicate()


func _start_pending_requests() -> void:
	while _active_requests.size() < MAX_CONCURRENT_REQUESTS and not _queue.is_empty():
		var word: String = _queue.pop_front()
		var request: HTTPRequest = HTTPRequest.new()
		request.timeout = REQUEST_TIMEOUT_SECONDS
		request.use_threads = true
		request.request_completed.connect(_on_request_completed.bind(request))
		add_child(request)
		_active_requests[request.get_instance_id()] = {"word": word, "provider": "datamuse"}
		var url: String = DATAMUSE_ROOT + word.to_lower().uri_encode() + "&md=d&max=100"
		var error: Error = request.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
		if error != OK:
			_start_fallback(request, word, "Datamuse API 無法連線。")


func _start_fallback(request: HTTPRequest, word: String, _reason: String = "") -> void:
	var request_id := request.get_instance_id()
	if not _active_requests.has(request_id):
		return
	var info: Dictionary = _active_requests[request_id]
	info["provider"] = "dictionaryapi"
	_active_requests[request_id] = info
	request.timeout = REQUEST_TIMEOUT_SECONDS
	var url: String = DICTIONARY_API_ROOT + word.to_lower().uri_encode()
	var error: Error = request.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)
	if error != OK:
		_finish_word(request, word, false, false, "外部字典暫時無法連線，未判定為有效。")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	var request_id := request.get_instance_id()
	if not _active_requests.has(request_id):
		return
	var info: Dictionary = _active_requests[request_id]
	var word := str(info.get("word", ""))
	var provider := str(info.get("provider", "datamuse"))
	if provider == "datamuse":
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and _datamuse_confirms(body, word):
			_finish_word(request, word, true, true, "已由 Datamuse 外部字典資料確認有效。")
			return
		_start_fallback(request, word, "Datamuse 未回傳可確認的精確字條目。")
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_word(request, word, false, false, "外部字典 API 暫時無法連線，未判定為有效。")
		return
	if response_code == 404:
		_finish_word(request, word, false, true, "外部字典未找到這個單字。")
		return
	if response_code != 200:
		_finish_word(request, word, false, false, "外部字典 API 回應錯誤，未判定為有效。")
		return
	var confirmed := _dictionaryapi_confirms(body, word)
	_finish_word(request, word, confirmed, true, "已由 Free Dictionary API 確認有效。" if confirmed else "外部字典回應沒有確認此單字。")


func _datamuse_confirms(body: PackedByteArray, word: String) -> bool:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Array:
		return false
	for entry_value: Variant in parsed:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var definitions: Variant = entry.get("defs", [])
		if str(entry.get("word", "")).strip_edges().to_upper() == word and definitions is Array and not definitions.is_empty():
			return true
	return false


func _dictionaryapi_confirms(body: PackedByteArray, word: String) -> bool:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Array:
		return false
	for entry_value: Variant in parsed:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var meanings: Variant = entry.get("meanings", [])
		if str(entry.get("word", "")).strip_edges().to_upper() == word and meanings is Array and not meanings.is_empty():
			return true
	return false


func _finish_word(request: HTTPRequest, word: String, is_valid: bool, definitive: bool, message: String) -> void:
	var request_id := request.get_instance_id()
	_active_requests.erase(request_id)
	if definitive:
		_cache[word] = is_valid
	var tags: Array = _tags_by_word.get(word, [])
	_tags_by_word.erase(word)
	request.queue_free()
	for tag_value: Variant in tags:
		_emit_result(str(tag_value), word, is_valid, message)
	_start_pending_requests()


func _emit_result(tag: String, word: String, is_valid: bool, message: String) -> void:
	validation_finished.emit(tag, word, is_valid, message)
