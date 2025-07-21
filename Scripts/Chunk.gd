extends MeshInstance3D

# --- Settings and Variables ---
@export var noise_scale : float = 2.1
@export var iso_level : float = 1.0

var player : Node3D
var unload_dist : int
var chunk_scale : int
var pos3i : Vector3i

const resolution : int = 6
const work_group_size : int = 8
const num_voxels_per_axis : int = work_group_size * resolution
const buffer_set_index : int = 0
const triangle_bind_index : int = 0
const params_bind_index : int = 1
const counter_bind_index : int = 2
const lut_bind_index : int = 3

# Compute stuff
var rd : RenderingDevice
var shader : RID
var pipeline : RID

var buffer_set : RID
var triangle_buffer : RID
var params_buffer : RID
var counter_buffer : RID
var lut_buffer : RID

# Data received from compute shader
var triangle_data_bytes : PackedByteArray
var counter_data_bytes : PackedByteArray
var num_triangles : int

var array_mesh : ArrayMesh
var verts = PackedVector3Array()
var normals = PackedVector3Array()

# Paralelization
var thread : Thread
signal mesh_ready

func _ready() -> void:
	mesh_ready.connect(create_mesh)
	global_position = Vector3(0, 0, 0)
	array_mesh = ArrayMesh.new()
	mesh = array_mesh

	init_compute()
	run_compute()
	fetch_and_process_compute_data()

func _process(_delta : float) -> void:
	if pos3i.distance_to(player.global_position) > unload_dist:
		Global.spawned_positions[pos3i] = false
		queue_free()

func init_compute() -> void:
	# Load global rd and compute shader
	rd = Global.rd
	shader = Global.shader

	# Create triangles buffer
	const max_tris_per_voxel : int = 5
	const max_triangles : int = max_tris_per_voxel * int(pow(num_voxels_per_axis, 3))
	const bytes_per_float : int = 4
	const floats_per_triangle : int = 4 * 3
	const bytes_per_triangle : int = floats_per_triangle * bytes_per_float
	const max_bytes : int = bytes_per_triangle * max_triangles

	triangle_buffer = rd.storage_buffer_create(max_bytes)
	var triangle_uniform := RDUniform.new()
	triangle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	triangle_uniform.binding = triangle_bind_index
	triangle_uniform.add_id(triangle_buffer)

	# Create params buffer
	var params_bytes := PackedFloat32Array(get_params_array()).to_byte_array()
	params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = params_bind_index
	params_uniform.add_id(params_buffer)

	# Create counter buffer
	var counter := [0]
	var counter_bytes := PackedFloat32Array(counter).to_byte_array()
	counter_buffer = rd.storage_buffer_create(counter_bytes.size(), counter_bytes)
	var counter_uniform := RDUniform.new()
	counter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	counter_uniform.binding = counter_bind_index
	counter_uniform.add_id(counter_buffer)

	# Create lookup table (lut) buffer
	lut_buffer = Global.lut_buffer
	var lut_uniform := RDUniform.new()
	lut_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	lut_uniform.binding = lut_bind_index
	lut_uniform.add_id(lut_buffer)

	# Create buffer setter and pipeline
	var buffers := [triangle_uniform, params_uniform, counter_uniform, lut_uniform]
	buffer_set = rd.uniform_set_create(buffers, shader, buffer_set_index)
	pipeline = Global.pipeline

func run_compute() -> void:
	# Update params buffer
	var params_bytes := PackedFloat32Array(get_params_array()).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)

	# Reset counter
	var counter := [0]
	var counter_bytes := PackedFloat32Array(counter).to_byte_array()
	rd.buffer_update(counter_buffer,0,counter_bytes.size(), counter_bytes)

	# Prepare compute list
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, buffer_set, buffer_set_index)
	rd.compute_list_dispatch(compute_list, resolution, resolution, resolution)
	rd.compute_list_end()

	# Run
	rd.submit()

func fetch_and_process_compute_data() -> void:
	rd.sync()

	# Get output
	triangle_data_bytes = rd.buffer_get_data(triangle_buffer)
	counter_data_bytes =  rd.buffer_get_data(counter_buffer)
	thread = Thread.new()
	thread.start(process_mesh_data)

func process_mesh_data() -> void:
	var triangle_data := triangle_data_bytes.to_float32_array()
	num_triangles = counter_data_bytes.to_int32_array()[0]
	var num_verts : int = num_triangles * 3
	verts.resize(num_verts)
	normals.resize(num_verts)

	for tri_index in range(num_triangles):
		var i := tri_index * 16
		var posA := Vector3(triangle_data[i + 0], triangle_data[i + 1], triangle_data[i + 2])
		var posB := Vector3(triangle_data[i + 4], triangle_data[i + 5], triangle_data[i + 6])
		var posC := Vector3(triangle_data[i + 8], triangle_data[i + 9], triangle_data[i + 10])
		var norm := Vector3(triangle_data[i + 12], triangle_data[i + 13], triangle_data[i + 14])
		verts[tri_index * 3 + 0] = posA
		verts[tri_index * 3 + 1] = posB
		verts[tri_index * 3 + 2] = posC
		normals[tri_index * 3 + 0] = norm
		normals[tri_index * 3 + 1] = norm
		normals[tri_index * 3 + 2] = norm

	mesh_ready.emit.call_deferred()

func create_mesh() -> void:
	thread.wait_to_finish()
	print("Num tris: ", num_triangles, " FPS: ", Engine.get_frames_per_second())

	if verts.is_empty():
		return

	var mesh_data : Array = []
	mesh_data.resize(Mesh.ARRAY_MAX)
	mesh_data[Mesh.ARRAY_VERTEX] = verts
	mesh_data[Mesh.ARRAY_NORMAL] = normals
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)

func get_params_array() -> Array:
	var params := [
		noise_scale,
		iso_level,
		float(num_voxels_per_axis),
		chunk_scale,
		float(pos3i.x),
		float(pos3i.y),
		float(pos3i.z)
	]
	return params

func load_lut(file_path : String) -> Array[int]:
	var file := FileAccess.open(file_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var index_strings := text.split(',')
	var indices : Array[int] = []
	for s in index_strings:
		indices.append(int(s))

	return indices

func _notification(type: int) -> void:
	if type == NOTIFICATION_PREDELETE:
		release()

func release() -> void:
	rd.free_rid(triangle_buffer)
	rd.free_rid(params_buffer)
	rd.free_rid(counter_buffer);

	pipeline = RID()
	triangle_buffer = RID()
	params_buffer = RID()
	counter_buffer = RID()
	lut_buffer = RID()
	shader = RID()

	rd = null
