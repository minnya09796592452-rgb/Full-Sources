class_name CetoWaveSpectrumCPU
extends RefCounted
## Small Godot-side CPU pipeline coordinator.
## Spectrum generation is performed once per condition; each update then
## initializes time-dependent frequency data and runs the three FFT buffers.

const SpectrumTask = preload("res://scripts/ceto_spectrum_task.gd")
const DisplacementBuffer = preload("res://scripts/ceto_displacement_buffer_cpu.gd")

# Ceto.WaveSpectrum defaults retained as reference configuration values.
const DEFAULT_FOURIER_SIZE := 64
const DEFAULT_NUM_GRIDS := 4
const DEFAULT_WIND_SPEED := 8.0
const DEFAULT_WAVE_AGE := 0.64
const DEFAULT_WAVE_SPEED := 1.0
const DEFAULT_GRID_SCALE := 0.5
const DEFAULT_CHOPPYNESS := 0.8

var condition
var displacement_buffer
var spectrum_task
var spectrum_ready := false
var last_time := 0.0


func _init(p_condition: Variant) -> void:
	if p_condition == null:
		push_error("CetoWaveSpectrumCPU: a prepared spectrum condition is required.")
		return
	if int(p_condition.num_grids) != DEFAULT_NUM_GRIDS:
		push_error("CetoWaveSpectrumCPU: this stage currently supports four grids only.")
		return
	condition = p_condition
	displacement_buffer = DisplacementBuffer.new(int(condition.size))
	spectrum_task = SpectrumTask.new(condition)


func initialize_spectrum() -> bool:
	if condition == null or spectrum_task == null:
		return false
	var generated: Dictionary = spectrum_task.run()
	if generated.cancelled:
		return false
	spectrum_task.apply_to_condition(condition)
	spectrum_ready = bool(condition.done)
	return spectrum_ready


func update(ocean_time: float) -> bool:
	if not spectrum_ready and not initialize_spectrum():
		return false
	last_time = ocean_time
	return displacement_buffer.run(condition, ocean_time)


func get_read_displacements() -> Array:
	if displacement_buffer == null:
		return []
	return displacement_buffer.get_read_displacements()


func get_latest_write_displacements() -> Array:
	if displacement_buffer == null:
		return []
	return displacement_buffer.get_write_displacements()
