extends SceneTree

const UnifiedCondition = preload("res://scripts/ceto_unified_spectrum_condition.gd")
const SpectrumTask = preload("res://scripts/ceto_spectrum_task.gd")
const DisplacementBuffer = preload("res://scripts/ceto_displacement_buffer_cpu.gd")
const WaveSpectrumCPU = preload("res://scripts/ceto_wave_spectrum_cpu.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_init_task_four_grid_packing()
	_test_three_double_packed_fft_buffers()
	_test_displacement_channel_layout()
	_test_ping_pong_swap()
	_test_wave_spectrum_coordinator()
	print("Ceto displacement tests: all checks passed.")
	quit(0)


func _make_condition(size: int = 8):
	var condition = UnifiedCondition.new(size, 8.0, 0.0, 0.64, 4)
	var task = SpectrumTask.new(condition)
	var result: Dictionary = task.run()
	assert(not result.cancelled)
	task.apply_to_condition(condition)
	assert(condition.done)
	return condition


func _test_init_task_four_grid_packing() -> void:
	var condition = _make_condition()
	var buffer = DisplacementBuffer.new(8)
	var task = preload("res://scripts/ceto_init_spectrum_displacements_task.gd").new(buffer, condition, 0.5)
	assert(task.run())
	var height_data: PackedVector4Array = task.get_data(0)
	var horizontal_01: PackedVector4Array = task.get_data(1)
	var horizontal_23: PackedVector4Array = task.get_data(2)
	assert(height_data.size() == 64)
	assert(horizontal_01.size() == 64)
	assert(horizontal_23.size() == 64)
	assert(height_data[0] == Vector4.ZERO)
	assert(horizontal_01[0] == Vector4.ZERO)
	assert(horizontal_23[0] == Vector4.ZERO)


func _test_three_double_packed_fft_buffers() -> void:
	var condition = _make_condition()
	var buffer = DisplacementBuffer.new(8)
	assert(buffer.run(condition, 0.75))
	assert(buffer.last_fft_indices == PackedInt32Array([1, 1, 1]))
	for buffer_index in range(3):
		assert(buffer.get_buffer_result(buffer_index).size() == 64)


func _test_displacement_channel_layout() -> void:
	var condition = _make_condition()
	var buffer = DisplacementBuffer.new(8)
	assert(buffer.run(condition, 0.75))
	var grids: Array = buffer.get_write_displacements()
	assert(grids.size() == 4)
	for grid in range(4):
		var channels: PackedFloat32Array = grids[grid]
		assert(channels.size() == 64 * 3)
		var has_height := false
		for index in range(64):
			if absf(channels[index * 3 + 1]) > 1.0e-8:
				has_height = true
				break
		assert(has_height, "Grid %d did not receive a height channel." % grid)


func _test_ping_pong_swap() -> void:
	var condition = _make_condition()
	var buffer = DisplacementBuffer.new(8)
	assert(buffer.run(condition, 0.25))
	var first_write: Array = buffer.copy_read_displacements()
	# Ceto swaps at the beginning of the next update, so the prior write
	# becomes the read set while the other set is reused for new output.
	assert(buffer.run(condition, 0.5))
	var second_read: Array = buffer.get_read_displacements()
	for grid in range(4):
		assert(second_read[grid] == first_write[grid])


func _test_wave_spectrum_coordinator() -> void:
	var condition = UnifiedCondition.new(8, 8.0, 0.0, 0.64, 4)
	var pipeline = WaveSpectrumCPU.new(condition)
	assert(pipeline.update(1.0))
	assert(pipeline.spectrum_ready)
	assert(pipeline.displacement_buffer.last_fft_indices == PackedInt32Array([1, 1, 1]))
