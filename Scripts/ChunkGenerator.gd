extends Node3D

# --- Settings and Variables ---
@export var size := 3
@export var spacing := 80
@export var player : Node3D
@export var max_chunks_per_frame := 1

@onready var root := get_tree().root
@onready var chunk_preload := preload("res://Scenes/Chunk.tscn")

var upper_bound := size / 2 + 2
var lower_bound := - upper_bound - 1
var interval := range(lower_bound, upper_bound)

var unload_dist := (size - 1) * spacing
var render_dist := (size - 1.5) * spacing
var render_squared := render_dist * render_dist

var spawn_queue: Array[Vector3i] = []

func _ready() -> void:
	# Ensure grid size is only odd (add 1 to even numbers)
	size += (size + 1) % 2

func _process(_delta: float) -> void:
	# Add chunks to spawn queue
	if spawn_queue.is_empty():
		var player_pos = player.global_position
		var player_grid := Vector3i(player_pos / spacing)

		# Iterate grid around the player
		for x in interval:
			for y in interval:
				for z in interval:
					var offset := Vector3i(x, y, z)
					var grid_pos = (player_grid + offset) * spacing
					if not spawn_queue.has(grid_pos) and \
						player_pos.distance_squared_to(grid_pos) <= render_squared:
						spawn_queue.append(grid_pos)

		# Sort chunks by distance
		spawn_queue.sort_custom(Callable(self, "_sort_by_player_distance"))

	# Spawn up to N chunks per frame
	var chunks_spawned := 0
	while not spawn_queue.is_empty() and chunks_spawned < max_chunks_per_frame:
		var grid_pos : Vector3i = spawn_queue.pop_front()
		if Global.spawned_positions.get(grid_pos, false):
			continue

		var chunk := chunk_preload.instantiate()
		chunk.pos3i = grid_pos
		chunk.player = player
		chunk.unload_dist = unload_dist
		chunk.chunk_scale = spacing
		root.add_child(chunk)
		Global.spawned_positions[grid_pos] = true
		chunks_spawned += 1

func _sort_by_player_distance(a, b):
	return a.distance_squared_to(player.global_position) < b.distance_squared_to(player.global_position)
