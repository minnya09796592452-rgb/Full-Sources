class_name CetoPhillipsSpectrumCondition
extends "res://scripts/ceto_wave_spectrum_condition.gd"
## Direct port of Ceto.PhillipsSpectrumCondition grid presets.

const PhillipsSpectrum = preload("res://scripts/ceto_phillips_spectrum.gd")


func _init(size: int, wind_speed: float, wind_dir: float, _wave_age: float, num_grids: int) -> void:
	super(size, num_grids)
	if size <= 0 or num_grids < 1 or num_grids > 4:
		return

	match num_grids:
		1:
			grid_sizes = Vector4(217.0, 1.0, 1.0, 1.0)
			choppyness = Vector4(1.5, 1.0, 1.0, 1.0)
			wave_amps = Vector4(0.5, 1.0, 1.0, 1.0)
		2:
			grid_sizes = Vector4(217.0, 97.0, 1.0, 1.0)
			choppyness = Vector4(1.5, 1.2, 1.0, 1.0)
			wave_amps = Vector4(0.5, 1.0, 1.0, 1.0)
		3:
			grid_sizes = Vector4(217.0, 97.0, 31.0, 1.0)
			choppyness = Vector4(1.5, 1.2, 1.0, 1.0)
			wave_amps = Vector4(0.5, 1.0, 1.0, 1.0)
		4:
			grid_sizes = Vector4(1372.0, 217.0, 97.0, 31.0)
			choppyness = Vector4(1.5, 1.2, 1.0, 1.0)
			wave_amps = Vector4(0.25, 0.5, 1.0, 1.0)

	var spectrum = PhillipsSpectrum.new(wind_speed, wind_dir)
	spectrums = [spectrum, spectrum, spectrum, spectrum]
