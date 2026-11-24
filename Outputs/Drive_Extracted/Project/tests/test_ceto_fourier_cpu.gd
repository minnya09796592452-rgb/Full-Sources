extends SceneTree

const FourierCPU = preload("res://scripts/ceto_fourier_cpu.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_double_packed_matches_direct_2d_inverse_dft(2)
	_test_double_packed_matches_direct_2d_inverse_dft(4)
	_test_double_packed_matches_direct_2d_inverse_dft(8)
	_test_single_packed_matches_direct_2d_inverse_dft()
	_test_start_index_zero_ping_pong()
	_test_size_one_returns_ceto_destination()
	_test_cancellation_returns_minus_one()
	print("CetoFourierCPU tests: all checks passed.")
	quit(0)


func _test_double_packed_matches_direct_2d_inverse_dft(grid_size: int) -> void:
	var fft = FourierCPU.new(grid_size)
	var source := PackedVector4Array()
	var scratch := PackedVector4Array()
	source.resize(grid_size * grid_size)
	scratch.resize(grid_size * grid_size)

	for y in range(grid_size):
		for x in range(grid_size):
			var index := x + y * grid_size
			source[index] = Vector4(
				float((x * 3 + y * 2) % 7) * 0.17,
				float((x + y * 4) % 5) * -0.23,
				float((x * 2 + y) % 6) * 0.11,
				float((x * 5 + y * 3) % 8) * 0.07
			)

	var buffers: Array = [source, scratch]
	var output_index: int = fft.perform_fft_double_packed(1, buffers)
	assert(output_index >= 0, "Double-packed FFT must return a valid buffer.")
	var actual: PackedVector4Array = buffers[output_index]

	for ky in range(grid_size):
		for kx in range(grid_size):
			var expected := Vector4.ZERO
			for y in range(grid_size):
				for x in range(grid_size):
					var input_value: Vector4 = source[x + y * grid_size]
					var angle := TAU * float(kx * x + ky * y) / float(grid_size)
					var wr := cos(angle)
					var wi := sin(angle)
					expected.x += wr * input_value.x - wi * input_value.y
					expected.y += wi * input_value.x + wr * input_value.y
					expected.z += wr * input_value.z - wi * input_value.w
					expected.w += wi * input_value.z + wr * input_value.w

			var actual_value: Vector4 = actual[kx + ky * grid_size]
			assert(actual_value.distance_to(expected) < 0.0005,
				"Double-packed FFT differs from direct DFT at (%d,%d), N=%d: got %s expected %s"
				% [kx, ky, grid_size, actual_value, expected])


func _test_single_packed_matches_direct_2d_inverse_dft() -> void:
	var grid_size := 4
	var fft = FourierCPU.new(grid_size)
	var source := PackedVector4Array()
	var scratch := PackedVector4Array()
	source.resize(grid_size * grid_size)
	scratch.resize(grid_size * grid_size)

	for index in range(source.size()):
		source[index] = Vector4(float(index) * 0.13, float(index % 3) * -0.21, 17.0, -9.0)

	var buffers: Array = [source, scratch]
	var output_index: int = fft.perform_fft_single_packed(1, buffers)
	assert(output_index >= 0, "Single-packed FFT must return a valid buffer.")
	var actual: PackedVector4Array = buffers[output_index]

	for ky in range(grid_size):
		for kx in range(grid_size):
			var expected := Vector2.ZERO
			for y in range(grid_size):
				for x in range(grid_size):
					var input_value: Vector4 = source[x + y * grid_size]
					var angle := TAU * float(kx * x + ky * y) / float(grid_size)
					var wr := cos(angle)
					var wi := sin(angle)
					expected.x += wr * input_value.x - wi * input_value.y
					expected.y += wi * input_value.x + wr * input_value.y

			var actual_value: Vector4 = actual[kx + ky * grid_size]
			assert(Vector2(actual_value.x, actual_value.y).distance_to(expected) < 0.0005,
				"Single-packed FFT differs from direct DFT at (%d,%d)." % [kx, ky])


func _test_cancellation_returns_minus_one() -> void:
	var fft = FourierCPU.new(4)
	var source := PackedVector4Array()
	var scratch := PackedVector4Array()
	source.resize(16)
	scratch.resize(16)
	var buffers: Array = [source, scratch]
	var always_cancel := func() -> bool: return true
	assert(fft.perform_fft_double_packed(1, buffers, always_cancel) == -1,
		"Cancelled FFT must return -1.")


func _test_start_index_zero_ping_pong() -> void:
	var grid_size := 4
	var fft = FourierCPU.new(grid_size)
	var input_buffer := PackedVector4Array()
	var output_buffer := PackedVector4Array()
	input_buffer.resize(grid_size * grid_size)
	output_buffer.resize(grid_size * grid_size)

	for index in range(input_buffer.size()):
		input_buffer[index] = Vector4(float(index) * 0.09, float(index % 4) * 0.12, 0.0, 0.0)

	# start_idx=0 means the original input is in buffer 1.
	var buffers: Array = [output_buffer, input_buffer]
	var output_index: int = fft.perform_fft_single_packed(0, buffers)
	assert(output_index == 1, "Ceto ping-pong parity must return buffer 1 for N=4, start_idx=0.")


func _test_size_one_returns_ceto_destination() -> void:
	var fft = FourierCPU.new(1)
	var buffers: Array = [PackedVector4Array([Vector4.ZERO]), PackedVector4Array([Vector4.ONE])]
	assert(fft.perform_fft_double_packed(0, buffers) == 0,
		"Ceto returns destination index 0 when the transform has zero passes.")
