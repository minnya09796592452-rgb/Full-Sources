class_name CetoOceanRuntimeController
extends Node
## Runs CPU FFT updates on a worker thread and interpolates snapshots on the render thread.

const UnifiedCondition = preload("res://scripts/ceto_unified_spectrum_condition.gd")
const WaveSpectrumCPU = preload("res://scripts/ceto_wave_spectrum_cpu.gd")

@export_range(8, 512, 8) var fourier_size: int = 64
@export_range(0.0, 30.0, 0.1) var wind_speed: float = 8.0
@export_range(0.0, 360.0, 1.0) var wind_direction: float = 35.0
@export_range(0.5, 1.0, 0.01) var wave_age: float = 0.64
@export_range(0.0, 10.0, 0.1) var wave_speed: float = 1.0
@export_range(5.0, 60.0, 1.0) var fft_updates_per_second: float = 20.0
@export var ocean_mesh_path: NodePath = NodePath("../OceanSurface")
@export var grid_sizes: Vector4 = Vector4(1372.0, 392.0, 28.0, 4.0)
@export var sea_level: float = 0.0
@export var interpolate_between_fft_updates: bool = true

var _pipeline
var _material: ShaderMaterial
var _textures: Array[ImageTexture] = []
var _elapsed := 0.0
var _update_accumulator := 0.0
var _snapshot_age := 0.0
var _previous_grids: Array = []
var _current_grids: Array = []
var _fft_thread := Thread.new()
var _fft_thread_started := false
var _ready_for_render := false
var _has_snapshot := false
var _worker_updates := 0
var _last_worker_result := false


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
		_textures.append(texture)
		_material.set_shader_parameter("displacement_map_%d" % grid_index, texture)

	_material.set_shader_parameter("grid_size_0", grid_sizes.x)
	_material.set_shader_parameter("grid_size_1", grid_sizes.y)
	_material.set_shader_parameter("grid_size_2", grid_sizes.z)
	_material.set_shader_parameter("grid_size_3", grid_sizes.w)
	_material.set_shader_parameter("grid_choppyness", condition.choppyness)
	_material.set_shader_parameter("grid_scale", 0.5)
	_material.set_shader_parameter("sea_level", sea_level)
	_ready_for_render = true
	_start_fft_update()


func _process(delta: float) -> void:
	if not _ready_for_render:
		return
	_elapsed += delta
	_update_accumulator += delta
	_snapshot_age += delta

	_collect_completed_fft()
	if not _fft_thread_started and _update_accumulator >= 1.0 / maxf(fft_updates_per_second, 1.0):
		_update_accumulator = fmod(_update_accumulator, 1.0 / maxf(fft_updates_per_second, 1.0))
		_start_fft_update()

	if _has_snapshot:
		var alpha := 1.0
		if interpolate_between_fft_updates:
			alpha = clampf(_snapshot_age * fft_updates_per_second, 0.0, 1.0)
		_upload_interpolated_grids(alpha)


func _start_fft_update() -> void:
	if _fft_thread_started or _pipeline == null:
		return
	var ocean_time := _elapsed * wave_speed
	var error := _fft_thread.start(_run_fft_update.bind(ocean_time))
	if error != OK:
		push_error("CetoOceanRuntimeController: could not start FFT worker thread (error %d)." % error)
		return
	_fft_thread_started = true


func _run_fft_update(ocean_time: float) -> bool:
	return _pipeline.update(ocean_time)


func _collect_completed_fft() -> void:
	if not _fft_thread_started or _fft_thread.is_alive():
		return
	_last_worker_result = bool(_fft_thread.wait_to_finish())
	_fft_thread_started = false
	if not _last_worker_result:
		return
	var latest: Array = _pipeline.get_latest_write_displacements()
	if latest.size() != 4:
		push_error("CetoOceanRuntimeController: FFT worker returned an invalid grid count.")
		return
	var snapshot: Array = []
	for grid in latest:
		snapshot.append((grid as PackedFloat32Array).duplicate())
	if not _has_snapshot:
		_previous_grids = snapshot.duplicate(true)
		_current_grids = snapshot
		_has_snapshot = true
	else:
		_previous_grids = _current_grids
		_current_grids = snapshot
	_snapshot_age = 0.0
	_worker_updates += 1


func _upload_interpolated_grids(alpha: float) -> void:
	for grid_index in range(4):
		var previous: PackedFloat32Array = _previous_grids[grid_index]
		var current: PackedFloat32Array = _current_grids[grid_index]
		var expected := fourier_size * fourier_size * 3
		if previous.size() != expected or current.size() != expected:
			push_error("CetoOceanRuntimeController: grid %d has an invalid channel count." % grid_index)
			return
		var rgba := PackedFloat32Array()
		rgba.resize(fourier_size * fourier_size * 4)
		for texel in range(fourier_size * fourier_size):
			var src := texel * 3
			var dst := texel * 4
			rgba[dst] = lerpf(previous[src], current[src], alpha)
			rgba[dst + 1] = lerpf(previous[src + 1], current[src + 1], alpha)
			rgba[dst + 2] = lerpf(previous[src + 2], current[src + 2], alpha)
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


func get_worker_update_count() -> int:
	return _worker_updates


func _exit_tree() -> void:
	_ready_for_render = false
	if _fft_thread_started:
		_fft_thread.wait_to_finish()
		_fft_thread_started = false
	_textures.clear()
	_pipeline = null
