extends Node

var spawned_positions : Dictionary[Vector3i, bool]

var rd : RenderingDevice
var shader : RID
var lut_buffer : RID
var pipeline : RID

func _ready() -> void:
	rd = RenderingServer.create_local_rendering_device()

	var shader_file : RDShaderFile = load("res://Compute/MarchingCubes.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

	var lut := load_lut("res://Compute/LUT.txt")
	var lut_bytes := PackedInt32Array(lut).to_byte_array()
	lut_buffer = rd.storage_buffer_create(lut_bytes.size(), lut_bytes)

	pipeline = rd.compute_pipeline_create(shader)

func load_lut(file_path : String) -> Array[int]:
	var file := FileAccess.open(file_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var index_strings := text.split(',')
	var indices : Array[int] = []
	for s in index_strings:
		indices.append(int(s))

	return indices
