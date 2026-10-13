extends Button

var tile_id := -1
var hand_owner_id := 0
var main_controller: Node


func _get_drag_data(_at_position: Vector2) -> Variant:
	if tile_id < 0 or not is_instance_valid(main_controller):
		return null
	var preview := Button.new()
	preview.text = text
	preview.custom_minimum_size = custom_minimum_size
	preview.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	preview.add_theme_color_override("font_color", get_theme_color("font_color"))
	set_drag_preview(preview)
	return {"source_tile_id": tile_id, "hand_owner_id": hand_owner_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not is_instance_valid(main_controller):
		return false
	return int(data.get("hand_owner_id", -1)) == main_controller.get_instance_id() and int(data.get("source_tile_id", -1)) != tile_id


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var insert_after := at_position.x >= size.x * 0.5
	main_controller.call_deferred("_reorder_hand_tile", int(data.get("source_tile_id", -1)), tile_id, insert_after)
