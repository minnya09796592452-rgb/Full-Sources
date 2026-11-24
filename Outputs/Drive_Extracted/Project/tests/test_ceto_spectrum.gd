extends SceneTree

const DotNetRandom = preload("res://scripts/ceto_dotnet_random.gd")
const PhillipsCondition = preload("res://scripts/ceto_phillips_spectrum_condition.gd")
const UnifiedCondition = preload("res://scripts/ceto_unified_spectrum_condition.gd")
const MixedCondition = preload("res://scripts/ceto_unified_phillips_spectrum_condition.gd")
const SpectrumTask = preload("res://scripts/ceto_spectrum_task.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_dotnet_random_seed_zero_sequence()
	_test_grid_presets()
	_test_mixed_grid_spectrum_selection()
	_test_spectrum_task_is_deterministic()
	_test_spectrum_and_wtable_shapes()
	_test_cancellation()
	print("Ceto spectrum tests: all checks passed.")
	quit(0)


func _test_dotnet_random_seed_zero_sequence() -> void:
	var rng = DotNetRandom.new(0)
	var expected := [
		0.7262432699679598,
		0.8173253595909687,
		0.7680226893946634,
		0.5581611914365372,
		0.2060331540210327
	]
	for value in expected:
		assert(absf(rng.next_double() - value) < 1.0e-15,
			"Seed-0 .NET System.Random sequence mismatch.")


func _test_grid_presets() -> void:
	var unified = UnifiedCondition.new(64, 8.0, 0.0, 0.64, 4)
	assert(unified.grid_sizes == Vector4(1372.0, 392.0, 28.0, 4.0))
	assert(unified.choppyness == Vector4(2.3, 2.1, 1.6, 0.9))
	assert(unified.wave_amps == Vector4.ONE)

	var phillips = PhillipsCondition.new(64, 8.0, 0.0, 0.64, 4)
	assert(phillips.grid_sizes == Vector4(1372.0, 217.0, 97.0, 31.0))
	assert(phillips.choppyness == Vector4(1.5, 1.2, 1.0, 1.0))
	assert(phillips.wave_amps == Vector4(0.25, 0.5, 1.0, 1.0))


func _test_mixed_grid_spectrum_selection() -> void:
	var mixed = MixedCondition.new(64, 8.0, 0.0, 0.64, 4)
	assert(mixed.spectrums.size() == 4)
	assert(mixed.spectrums[0] is preload("res://scripts/ceto_unified_spectrum.gd"))
	assert(mixed.spectrums[1] is preload("res://scripts/ceto_unified_spectrum.gd"))
	assert(mixed.spectrums[2] is preload("res://scripts/ceto_phillips_spectrum.gd"))
	assert(mixed.spectrums[3] is preload("res://scripts/ceto_unified_spectrum.gd"))


func _test_spectrum_task_is_deterministic() -> void:
	var condition_a = UnifiedCondition.new(8, 8.0, 0.0, 0.64, 4)
	var condition_b = UnifiedCondition.new(8, 8.0, 0.0, 0.64, 4)
	var task_a = SpectrumTask.new(condition_a)
	var task_b = SpectrumTask.new(condition_b)
	var result_a: Dictionary = task_a.run()
	var result_b: Dictionary = task_b.run()
	assert(result_a.spectrum01 == result_b.spectrum01)
	assert(result_a.spectrum23 == result_b.spectrum23)
	assert(result_a.wtable == result_b.wtable)


func _test_spectrum_and_wtable_shapes() -> void:
	var condition = UnifiedCondition.new(8, 8.0, 0.0, 0.64, 4)
	var task = SpectrumTask.new(condition)
	var result: Dictionary = task.run()
	assert(not result.cancelled)
	assert(result.spectrum01.size() == 64)
	assert(result.spectrum23.size() == 64)
	assert(result.wtable.size() == 64)
	assert(result.wtable[0].r == 0.0)
	assert(result.wtable[0].g == 0.0)
	assert(result.wtable[0].b == 0.0)
	assert(result.wtable[0].a == 0.0)


func _test_cancellation() -> void:
	var condition = UnifiedCondition.new(16, 8.0, 0.0, 0.64, 4)
	var task = SpectrumTask.new(condition)
	var cancel_now := func() -> bool: return true
	var result: Dictionary = task.run(cancel_now)
	assert(result.cancelled)
