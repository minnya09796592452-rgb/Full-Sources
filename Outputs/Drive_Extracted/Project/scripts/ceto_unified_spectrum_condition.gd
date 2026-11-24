class_name CetoUnifiedSpectrumCondition
extends "res://scripts/ceto_wave_spectrum_condition.gd"
## Direct port of Ceto.UnifiedSpectrumCondition grid presets.

const UnifiedSpectrum = preload("res://scripts/ceto_unified_spectrum.gd")


func _init(size: int, wind_speed: float, wind_dir: float, wave_age: float, num_grids: int) -> void:
	super(size, num_grids)
	if size <= 0 or num_grids < 1 or num_grids > 4:
		return

	match num_grids:
		1:
			grid_sizes = Vector4(772.0, 1.0, 1.0, 1.0)
			choppyness = Vector4(2.3, 1.0, 1.0, 1.0)
			wave_amps = Vector4.ONE
		2:
			grid_sizes = Vector4(772.0, 57.0, 1.0, 1.0)
			choppyness = Vector4(2.3, 2.1, 1.0, 1.0)
			wave_amps = Vector4.ONE
		3:
			grid_sizes = Vector4(1372.0, 392.0, 28.0, 1.0)
			choppyness = Vector4(2.3, 2.1, 1.6, 1.0)
			wave_amps = Vector4.ONE
		4:
			grid_sizes = Vector4(1372.0, 392.0, 28.0, 4.0)
			choppyness = Vector4(2.3, 2.1, 1.6, 0.9)
			wave_amps = Vector4.ONE

	var spectrum = UnifiedSpectrum.new(wind_speed, wind_dir, wave_age)
	spectrums = [spectrum, spectrum, spectrum, spectrum]
