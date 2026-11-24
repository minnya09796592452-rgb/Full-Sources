class_name CetoOceanRuntimeController
extends Node
## Bridges the four CPU displacement grids to RGBAF textures consumed by the ocean shader.

const UnifiedCondition = preload("res://scripts/ceto_unified_spectrum_condition.gd")
const WaveSpectrumCPU = preload("res://scripts/ceto_wave_spectrum_cpu.gd")

@export_range(8, 512, 8) var fourier_size: int = 64
@export_range(0.0, 30.0, 0.1) var wind_speed: float = 8.0
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 35.0
@export_range(0.5, 1.0, 0.01) var wave_age: float = 0.64
@export_range(0.0, 10.0, 0.1) var wave_speed: float = 1.0
@export var ocean_mesh_path: NodePath = NodePath("../OceanSurface")
@export var grid_sizes: Vector4 = Vector4(1372.0, 392.0, 28.0, 4.0)
@export var sea_level: float = 0.0
@export var upload_every_frame: bool = true

var _pipeline
var _material: ShaderMaterial
var _textures: Array[ImageTexture] = []
var _elapsed := 0.0
var _frame_count := 0
var _ready_for_render := false


func _ready() -> void:
	var ocean_mesh := get_node_or_null(ocean_mesh_path) as MeshInstance3D
	if ocean_mesh == null:
		push_error("CetoOceanRuntimeController: Ocean MeshInstance3D was not found.")
		set_process(false)
		return
	_material = ocean_mesh.get_active_material(0) as ShaderMaterial
	if _material == null:
		push_error("CetoOceanRuntimeController: ocean surface needs a ShaderMaterial.")
		set_process(false)
		return

	var condition = UnifiedCondition.new(fourier_size, wind_speed, wind_direction, wave_age, 4)
	condition.grid_sizes = grid_sizes
	_pipeline = WaveSpectrumCPU.new(condition)
	for grid_index in range(4):
		var image := Image.create(fourier_size, fourier_size, false, Image.FORMAT_RGBAF)
		image.fill(Color(0.0, 0.0, 0.0, 1.0))
		var texture := ImageTexture.create_from_image(image)
		texture.resource_name = "Ceto Displacement Grid %d RGBAF" % grid_index
		texture.set_meta("ceto_grid_index", grid_index)
		_textures.append(texture)
		_material.set_shader_parameter("displacement_map_%d" % grid_index, texture)
	_material.set_shader_parameter("grid_size_0", grid_sizes.x)
	_material.set_shader_parameter("grid_size_1", grid_sizes.y)
	_material.set_shader_parameter("grid_size_2", grid_sizes.z)
	_material.set_shader_parameter("grid_size_3", grid_sizes.w)
	_material.set_shader_parameter("sea_level", sea_level)
	_ready_for_render = true


func _process(delta: float) -> void:
	if not _ready_for_render:
		return
	_elapsed += delta
	if not _pipeline.update(_elapsed * wave_speed):
		return
	_frame_count += 1
	# The source Ceto buffer swaps before each run; its readable set is the
	# previous completed update, so the first frame intentionally remains clear.
	if _frame_count < 2 or upload_every_frame:
		_upload_read_grids()


func _upload_read_grids() -> void:
	var grids: Array = _pipeline.get_read_displacements()
	if grids.size() != 4:
		push_error("CetoOceanRuntimeController: expected exactly four displacement grids.")
		return
	for grid_index in range(4):
		var channels: PackedFloat32Array = grids[grid_index]
		var expected := fourier_size * fourier_size * 3
		if channels.size() != expected:
			push_error("CetoOceanRuntimeController: grid %d has an invalid channel count." % grid_index)
			return
		var rgba := PackedFloat32Array()
		rgba.resize(fourier_size * fourier_size * 4)
		for texel in range(fourier_size * fourier_size):
			var src := texel * 3
			var dst := texel * 4
			rgba[dst] = channels[src]
			rgba[dst + 1] = channels[src + 1]
			rgba[dst + 2] = channels[src + 2]
			rgba[dst + 3] = 1.0
		var image := Image.create_from_data(
			fourier_size, fourier_size, false, Image.FORMAT_RGBAF, rgba.to_byte_array()
		)
		if image == null or image.is_empty():
			push_error("CetoOceanRuntimeController: failed to create RGBAF image for grid %d." % grid_index)
			return
		_textures[grid_index].update(image)


func get_displacement_texture(grid_index: int) -> Texture2D:
	if grid_index < 0 or grid_index >= _textures.size():
		return null
	return _textures[grid_index]


func _exit_tree() -> void:
	_ready_for_render = false
	_textures.clear()
	_pipeline = null
