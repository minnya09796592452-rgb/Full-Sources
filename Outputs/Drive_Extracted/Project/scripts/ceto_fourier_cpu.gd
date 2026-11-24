class_name CetoFourierCPU
extends RefCounted
## CPU radix-2 2D FFT ported from Ceto.FourierCPU.
##
## The transform uses Ceto's positive-angle twiddles (an unnormalised inverse
## DFT), row-major Vector4 buffers, bit-reversed input on stage zero, and
## horizontal passes followed by vertical passes. No normalisation is applied.

var size: int = 0
var passes: int = 0
var is_valid: bool = false

var _lookup_j1 := PackedInt32Array()
var _lookup_j2 := PackedInt32Array()
var _lookup_wr := PackedFloat32Array()
var _lookup_wi := PackedFloat32Array()


func _init(grid_size: int) -> void:
	if not _is_power_of_two(grid_size):
		push_error("CetoFourierCPU: grid size must be a positive power of two.")
		return

	size = grid_size
	passes = int(round(log(float(size)) / log(2.0)))
	_compute_butterfly_lookup_table()
	is_valid = true


func _is_power_of_two(value: int) -> bool:
	return value > 0 and (value & (value - 1)) == 0


## Ceto.FourierCPU.BitReverse, preserving its bit traversal order.
func _bit_reverse(value: int) -> int:
	var reversed_value := 0
	var output_bit := 1
	var input_bit: int = size >> 1

	while input_bit != 0:
		var bit_value := 1 if (value & input_bit) > input_bit - 1 else 0
		reversed_value += bit_value * output_bit
		output_bit *= 2
		input_bit = input_bit >> 1

	return reversed_value


## Builds the same flattened [stage * size + butterfly_index] table as Ceto.
func _compute_butterfly_lookup_table() -> void:
	var table_length := size * passes
	_lookup_j1.resize(table_length)
	_lookup_j2.resize(table_length)
	_lookup_wr.resize(table_length)
	_lookup_wi.resize(table_length)

	for stage in range(passes):
		var group_count := 1 << (passes - 1 - stage)
		var group_width := 1 << stage

		for group in range(group_count):
			for lane in range(group_width):
				var index_a := group * group_width * 2 + lane
				var index_b := group * group_width * 2 + group_width + lane
				var source_a: int
				var source_b: int

				if stage == 0:
					source_a = _bit_reverse(index_a)
					source_b = _bit_reverse(index_b)
				else:
					source_a = index_a
					source_b = index_b

				var angle := TAU * float(lane * group_count) / float(size)
				var wr := cos(angle)
				var wi := sin(angle)

				var table_a := index_a + stage * size
				_lookup_j1[table_a] = source_a
				_lookup_j2[table_a] = source_b
				_lookup_wr[table_a] = wr
				_lookup_wi[table_a] = wi

				var table_b := index_b + stage * size
				_lookup_j1[table_b] = source_a
				_lookup_j2[table_b] = source_b
				_lookup_wr[table_b] = -wr
				_lookup_wi[table_b] = -wi


## Equivalent to Ceto.FourierCPU.PeformFFT_SinglePacked.
##
## data0 must contain two PackedVector4Array buffers, each with size*size
## elements. start_idx is the initial ping-pong destination (0 or 1).
## The optional cancellation Callable must take no arguments and return bool.
## Returns the final destination buffer index, or -1 if cancelled/invalid.
func perform_fft_single_packed(
		start_idx: int,
		data0: Array,
		cancel_check: Callable = Callable()
) -> int:
	return _perform_fft(start_idx, data0, false, cancel_check)


## Equivalent to Ceto.FourierCPU.PeformFFT_DoublePacked.
## Processes both complex pairs: Vector4.xy and Vector4.zw.
func perform_fft_double_packed(
		start_idx: int,
		data0: Array,
		cancel_check: Callable = Callable()
) -> int:
	return _perform_fft(start_idx, data0, true, cancel_check)


func _perform_fft(
		start_idx: int,
		data0: Array,
		double_packed: bool,
		cancel_check: Callable
) -> int:
	if not is_valid or start_idx < 0 or start_idx > 1:
		push_error("CetoFourierCPU: invalid instance or start buffer index.")
		return -1

	if data0.size() < 2:
		push_error("CetoFourierCPU: two ping-pong buffers are required.")
		return -1

	var required_length := size * size
	for buffer_index in range(2):
		if not data0[buffer_index] is PackedVector4Array:
			push_error("CetoFourierCPU: buffers must be PackedVector4Array.")
			return -1
		var buffer: PackedVector4Array = data0[buffer_index]
		if buffer.size() != required_length:
			push_error("CetoFourierCPU: buffer length must equal size * size.")
			return -1

	var pass_number := start_idx
	var final_destination_index := 0

	# Ceto runs all horizontal passes first.
	for stage in range(passes):
		var destination_index := pass_number % 2
		var source_index := (pass_number + 1) % 2
		if not _execute_pass(
				data0, stage, false, destination_index, source_index,
				double_packed, cancel_check
		):
			return -1
		final_destination_index = destination_index
		pass_number += 1

	# Then it runs all vertical passes, continuing the same ping-pong parity.
	for stage in range(passes):
		var destination_index := pass_number % 2
		var source_index := (pass_number + 1) % 2
		if not _execute_pass(
				data0, stage, true, destination_index, source_index,
				double_packed, cancel_check
		):
			return -1
		final_destination_index = destination_index
		pass_number += 1

	return final_destination_index


func _execute_pass(
		data0: Array,
		stage: int,
		vertical: bool,
		destination_index: int,
		source_index: int,
		double_packed: bool,
		cancel_check: Callable
) -> bool:
	var source: PackedVector4Array = data0[source_index]
	var destination: PackedVector4Array = data0[destination_index]
	var table_offset := stage * size

	if not vertical:
		# Match C# loop order: butterfly column i, then row k.
		for i in range(size):
			var table_index := i + table_offset
			var j1 := _lookup_j1[table_index]
			var j2 := _lookup_j2[table_index]
			var wr := _lookup_wr[table_index]
			var wi := _lookup_wi[table_index]

			for k in range(size):
				if _is_cancelled(cancel_check):
					return false

				var row_offset := k * size
				var output_index := i + row_offset
				var input_a := j1 + row_offset
				var input_b := j2 + row_offset

				var value := destination[output_index]
				var a := source[input_a]
				var b := source[input_b]
				value.x = a.x + wr * b.x - wi * b.y
				value.y = a.y + wi * b.x + wr * b.y

				if double_packed:
					value.z = a.z + wr * b.z - wi * b.w
					value.w = a.w + wi * b.z + wr * b.w

				destination[output_index] = value
	else:
		# Match C# loop order: butterfly row k, then column i.
		for k in range(size):
			var table_index := k + table_offset
			var j1 := _lookup_j1[table_index] * size
			var j2 := _lookup_j2[table_index] * size
			var wr := _lookup_wr[table_index]
			var wi := _lookup_wi[table_index]

			for i in range(size):
				if _is_cancelled(cancel_check):
					return false

				var output_index := i + k * size
				var input_a := i + j1
				var input_b := i + j2

				var value := destination[output_index]
				var a := source[input_a]
				var b := source[input_b]
				value.x = a.x + wr * b.x - wi * b.y
				value.y = a.y + wi * b.x + wr * b.y

				if double_packed:
					value.z = a.z + wr * b.z - wi * b.w
					value.w = a.w + wi * b.z + wr * b.w

				destination[output_index] = value

	data0[destination_index] = destination
	return true


func _is_cancelled(cancel_check: Callable) -> bool:
	return cancel_check.is_valid() and bool(cancel_check.call())
