class_name CetoUnifiedPhillipsSpectrumCondition
extends "res://scripts/ceto_wave_spectrum_condition.gd"
## Direct port of Ceto.UnifiedPhillipsSpectrumCondition grid presets and
## per-grid spectrum selection (including the original four-grid assignment).

const UnifiedSpectrum = preload("res://scripts/ceto_unified_spectrum.gd")
const PhillipsSpectrum = preload("res://scripts/ceto_phillips_spectrum.gd")


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
			grid_sizes = Vector4(772.0, 97.0, 1.0, 1.0)
			choppyness = Vector4(2.3, 1.2, 1.0, 1.0)
			wave_amps = Vector4.ONE
		3:
			grid_sizes = Vector4(1372.0, 392.0, 31.0, 1.0)
			choppyness = Vector4(2.3, 2.1, 1.0, 1.0)
			wave_amps = Vector4.ONE
		4:
			grid_sizes = Vector4(1372.0, 392.0, 31.0, 4.0)
			choppyness = Vector4(2.3, 2.1, 1.0, 0.9)
			wave_amps = Vector4.ONE

	var unified = UnifiedSpectrum.new(wind_speed, wind_dir, wave_age)
	var phillips = PhillipsSpectrum.new(wind_speed, wind_dir)
	match num_grids:
		1:
			spectrums = [unified, null, null, null]
		2:
			spectrums = [unified, phillips, null, null]
		3:
			spectrums = [unified, unified, phillips, null]
		4:
			spectrums = [unified, unified, phillips, unified]
