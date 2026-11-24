class_name CetoWaveSpectrumCondition
extends RefCounted
## Godot-side data container matching Ceto.WaveSpectrumCondition's spectrum
## arrays and per-grid parameters. Texture creation/upload is a render-stage job.

var size: int
var num_grids: int
var grid_sizes: Vector4 = Vector4.ONE
var choppyness: Vector4 = Vector4.ONE
var wave_amps: Vector4 = Vector4.ONE
var spectrums: Array = []

var done: bool = false
var last_updated: int = -1
var spectrum01: PackedColorArray = PackedColorArray()
var spectrum23: PackedColorArray = PackedColorArray()
var wtable: PackedColorArray = PackedColorArray()


func _init(p_size: int, p_num_grids: int) -> void:
	size = p_size
	num_grids = p_num_grids
	if size <= 0 or num_grids < 1 or num_grids > 4:
		push_error("CetoWaveSpectrumCondition: size must be positive and grids must be 1..4.")
		return
	spectrum01.resize(size * size)
	if num_grids > 2:
		spectrum23.resize(size * size)
	wtable.resize(size * size)


func inverse_grid_sizes() -> Vector4:
	var scale: float = TAU * float(size)
	return Vector4(scale / grid_sizes.x, scale / grid_sizes.y, scale / grid_sizes.z, scale / grid_sizes.w)


func apply_spectrum_data(data01: PackedColorArray, data23: PackedColorArray, data_wtable: PackedColorArray) -> void:
	if data01.size() == spectrum01.size():
		spectrum01 = data01
	if num_grids > 2 and data23.size() == spectrum23.size():
		spectrum23 = data23
	if data_wtable.size() == wtable.size():
		wtable = data_wtable
