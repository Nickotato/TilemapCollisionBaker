@tool
extends RefCounted

const SettingsScript := preload("uid://c5i7h2p7ixlc4")

const BAKED_META_KEY := "_sides_tiles_generated"
const PHYSICS_LAYER_META_KEY := "_sides_tiles_physics_layer"

static func bake(tile_map: TileMapLayer) -> Dictionary:
	var result := {
		"success": false,
		"physics_layers": 0,
		"layers": [],
	}

	if tile_map == null:
		push_error("Tilemap Baker: TileMapLayer is null.")
		return result
	
	var tile_set := tile_map.tile_set

	if tile_set == null:
		push_error("Tilemap Baker: No TileSet is assigned to '%s'." % tile_map.name)
		return result

	var physics_layer_count := tile_set.get_physics_layers_count()

	if physics_layer_count <= 0:
		push_error("Tilemap Baker: The TileSet of '%s' has no physics layers." % tile_map.name)
		return result

	clear(tile_map)

	result["physics_layers"] = physics_layer_count

	var layer_cells: Array[Dictionary] = []

	for physics_layer in range(physics_layer_count):
		layer_cells.append({})

	for cell: Vector2i in tile_map.get_used_cells():
		var tile_data := tile_map.get_cell_tile_data(cell)

		if tile_data == null:
			continue

		for physics_layer in range(physics_layer_count):
			if tile_data.get_collision_polygons_count(physics_layer) > 0:
				layer_cells[physics_layer][cell] = true

	for physics_layer in range(physics_layer_count):
		var cells := layer_cells[physics_layer]

		var layer_result := {
			"layer": physics_layer,
			"name": SettingsScript.get_display_name(physics_layer),
			"color": SettingsScript.get_layer_color(physics_layer),
			"cells": cells.size(),
			"rectangles": 0,
		}

		if not cells.is_empty():
			var rectangles := _merge_cells_into_rectangles(cells)

			layer_result["rectangles"] = rectangles.size()

			_create_baked_body(tile_map, physics_layer, rectangles)

		result["layers"].append(layer_result)

	result["success"] = true

	print(
		"Tilemap Baker: Baked %d physics layer(s) for '%s'."
		% [physics_layer_count, tile_map.name]
	)

	return result


static func clear(tile_map: TileMapLayer) -> void:
	if tile_map == null:
		return
	
	var nodes_to_remove: Array[Node] = []
	
	for child in tile_map.get_children():
		if child.get_meta(BAKED_META_KEY, false):
			nodes_to_remove.append(child)
		
	for node in nodes_to_remove:
		tile_map.remove_child(node)
		node.free()
		

static func _create_baked_body(
	tile_map: TileMapLayer,
	physics_layer: int,
	rectangles: Array[Rect2i]
) -> void:
	var body := _create_physics_body()
	var tile_set := tile_map.tile_set
	var scene_root := _get_scene_root(tile_map)
	var shape_color := SettingsScript.get_shape_color(physics_layer)
	
	body.name = _make_unique_body_name(
		tile_map,
		SettingsScript.get_display_name(physics_layer)
	)
	
	body.collision_layer = tile_set.get_physics_layer_collision_layer(physics_layer)
	body.collision_mask = tile_set.get_physics_layer_collision_mask(physics_layer)
	body.set_meta(BAKED_META_KEY, true)
	body.set_meta(PHYSICS_LAYER_META_KEY, physics_layer)
	
	tile_map.add_child(body)
	body.owner = scene_root
	
	for rect in rectangles:
		_create_rectangle_collision(tile_map, body, rect, shape_color, scene_root)

static func _create_physics_body() -> StaticBody2D:
	# Finding Rapier does not work, I've tried everything, fix later.
	#var class_list := ProjectSettings.get_global_class_list()
	#var script_exists := false
	#
	#for c in class_list:
		#if c["class"] == "RapierStaticBody2D":
			#script_exists = true
			#break
	#
	#if script_exists:
		#var instance = RapierStaticBody2D.new() #this gives an error if rapier plugin isn't installed obviously.
		#if instance is StaticBody2D:
			#return instance
		#else:
			#instance.free()
	
	return StaticBody2D.new()


static func _create_rectangle_collision(
	tile_map: TileMapLayer,
	body: StaticBody2D,
	rect: Rect2i,
	color: Color,
	scene_root: Node
) -> void:
	var tile_size := Vector2(tile_map.tile_set.tile_size)
	var shape := RectangleShape2D.new()
	var collision := CollisionShape2D.new()
	
	shape.size = Vector2(rect.size) * tile_size
	
	collision.shape = shape
	collision.debug_color = color
	collision.position = (
		tile_map.map_to_local(rect.position)
		+ Vector2(rect.size - Vector2i.ONE) * tile_size * 0.5
	)
	
	body.add_child(collision)
	collision.owner = scene_root

static func _get_scene_root(tile_map: TileMapLayer) -> Node:
	if tile_map.owner != null:
		return tile_map.owner
	
	return tile_map

static func _make_unique_body_name(
	tile_map: TileMapLayer,
	desired_name: String
) -> String:
	var base_name := desired_name.validate_node_name().strip_edges()
	
	if base_name.is_empty():
		base_name = "Physics Layer"
		
	var candidate := base_name
	var index := 2
	
	while tile_map.has_node(NodePath(candidate)):
		candidate = "%s %d" % [base_name, index]
		index += 1
	
	return candidate


static func _merge_cells_into_rectangles(cells: Dictionary) -> Array[Rect2i]:
	var ordered: Array[Vector2i] = []
	
	for cell: Vector2i in cells.keys():
		ordered.append(cell)
	
	ordered.sort_custom(_compare_cells)
	
	var remaining := cells.duplicate()
	var rectangles: Array[Rect2i] = []
	
	for start in ordered:
		if not remaining.has(start):
			continue
			
		var width := 1
	
		while remaining.has(start + Vector2i(width, 0)):
			width += 1
		
		var height := 1
	
		while _row_exists(remaining, start + Vector2i(0, height), width):
			height += 1
		
		rectangles.append(Rect2i(start, Vector2i(width, height)))
		
		for y in range(height):
			for x in range(width):
				remaining.erase(start + Vector2i(x, y))
	
	return rectangles

static func _compare_cells(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	
	return a.x < b.x

static func _row_exists(
	cells: Dictionary,
	start: Vector2i,
	width: int
) -> bool:
	for x in range(width):
		if not cells.has(start + Vector2i(x, 0)):
			return false
	
	return true
