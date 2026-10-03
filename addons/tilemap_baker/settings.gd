@tool
extends RefCounted

const SETTING_PATH := "sides_tiles/physics_layers"
const NAME_KEY := "name"
const COLOR_KEY := "color"
const SHAPE_ALPHA := 0.42

static func register() -> void:
	if not ProjectSettings.has_setting(SETTING_PATH):
		ProjectSettings.set_setting(SETTING_PATH, {})
	
	ProjectSettings.set_initial_value(SETTING_PATH, {})
	ProjectSettings.add_property_info({
		"name": SETTING_PATH,
		"type": TYPE_DICTIONARY,
	})
	

static func save() -> void:
	ProjectSettings.save()

static func get_layer_name(physics_layer: int) -> String:
	var entry := _get_entry(physics_layer)
	var value: Variant = entry.get(NAME_KEY, "")
	
	if value is String:
		return value.strip_edges()
	
	return ""

static func get_display_name(physics_layer: int) -> String:
	var layer_name := get_layer_name(physics_layer)
	
	if layer_name.is_empty():
		return "Physics Layer %d" % physics_layer
		
	return layer_name

static func get_layer_color(physics_layer: int) -> Color:
	var entry := _get_entry(physics_layer)
	var value: Variant = entry.get(COLOR_KEY, null)
	
	if value is Color:
		return value
	
	return get_default_color(physics_layer)

static func get_shape_color(physics_layer: int) -> Color:
	var color := get_layer_color(physics_layer)
	color.a = SHAPE_ALPHA
	return color

static func get_default_color(physics_layer: int) -> Color:
	var hue := fposmod(float(physics_layer) * 0.618034, 1.0)
	return Color.from_hsv(hue, 0.65, 0.95)

static func set_layer_name(physics_layer: int, layer_name: String) -> void:
	_set_value(physics_layer, NAME_KEY, layer_name)

static func set_layer_color(physics_layer: int, color: Color) -> void:
	_set_value(physics_layer, COLOR_KEY, color)

static func _get_data() -> Dictionary:
	var value: Variant = ProjectSettings.get_setting(SETTING_PATH, {})
	
	if value is Dictionary:
		return value
	
	return {}

static func _get_entry(physics_layer: int) -> Dictionary:
	var entry: Variant = _get_data().get(str(physics_layer), {})
	
	if entry is Dictionary:
		return entry
	return {}

static func _set_value(
	physics_layer: int,
	key: String,
	value: Variant
) -> void:
	var data := _get_data().duplicate(true)
	var entry := _get_entry(physics_layer).duplicate(true)
	
	entry[key] = value
	data[str(physics_layer)] = entry
	
	ProjectSettings.set_setting(SETTING_PATH, data)
