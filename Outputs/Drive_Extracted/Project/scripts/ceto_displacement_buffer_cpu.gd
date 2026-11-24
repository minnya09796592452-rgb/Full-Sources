class_name CetoDisplacementBufferCPU
extends RefCounted
## CPU equivalent of Ceto.DisplacementBufferCPU + WaveSpectrumBufferCPU.
## Three double-packed FFT buffers produce four grids of (horizontal, height,
## horizontal) displacement channels. The write/read swap matches Ceto's
## one-update-latency buffer contract.

const FourierCPU = preload("res://scripts/ceto_fourier_cpu.gd")
const InitTask = preload("res://scripts/ceto_init_spectrum_displacements_task.gd")

const NUM_BUFFERS := 3
const NUM_GRIDS := 4
const CHANNELS := 3

var size: int
var _fourier
var _buffers: Array = []
var _displacements: Array = [[], []]
var _write_index := 0
var _read_index := 1
var last_fft_indices := PackedInt32Array()


func _init(grid_size: int) -> void:
	size = grid_size
	_fourier = FourierCPU.new(size)
	if not _fourier.is_valid:
		return
	var count := size * size
	for _buffer_index in range(NUM_BUFFERS):
		var first := PackedVector4Array()
		var second := PackedVector4Array()
		first.resize(count)
		second.resize(count)
		var result := PackedColorArray()
		result.resize(count)
		_buffers.append({
			"data": [first, second],
			"results": result,
			"double_packed": true,
			"disabled": false
		})
	for ping_pong in range(2):
		var grids: Array = []
		for _grid in range(NUM_GRIDS):
			var channels := PackedFloat32Array()
			channels.resize(count * CHANNELS)
			grids.append(channels)
		_displacements[ping_pong] = grids


func get_write_displacements() -> Array:
	return _displacements[_write_index]


func get_read_displacements() -> Array:
	return _displacements[_read_index]


func get_write_buffer(buffer_index: int) -> PackedVector4Array:
	if not _valid_buffer_index(buffer_index):
		return PackedVector4Array()
	return _buffers[buffer_index].data[0]


func get_read_buffer(buffer_index: int) -> PackedVector4Array:
	if not _valid_buffer_index(buffer_index):
		return PackedVector4Array()
	return _buffers[buffer_index].data[1]


func get_buffer_result(buffer_index: int) -> PackedColorArray:
	if not _valid_buffer_index(buffer_index):
		return PackedColorArray()
	return _buffers[buffer_index].results


func set_read_buffer(buffer_index: int, values: PackedVector4Array) -> void:
	if not _valid_buffer_index(buffer_index) or values.size() != size * size:
		return
	_buffers[buffer_index].data[1] = values


func run(condition: Variant, time_value: float) -> bool:
	if not _fourier.is_valid or condition == null or int(condition.num_grids) != NUM_GRIDS or int(condition.size) != size:
		push_error("CetoDisplacementBufferCPU: expected a matching four-grid spectrum condition.")
		return false

	# Ceto.DisplacementBufferCPU.Run swaps first, then clears the new write set.
	_swap_displacements()
	_clear_write_displacements()

	var init_task = InitTask.new(self, condition, time_value)
	if not init_task.run():
		return false

	last_fft_indices.resize(NUM_BUFFERS)
	for buffer_index in range(NUM_BUFFERS):
		var data: Array = _buffers[buffer_index].data
		var final_index: int = _fourier.perform_fft_double_packed(0, data)
		if final_index != 1:
			push_error("CetoDisplacementBufferCPU: FFT did not finish in read buffer index 1.")
			return false
		_buffers[buffer_index].data = data
		last_fft_indices[buffer_index] = final_index
		_process_fourier_data(buffer_index, data[final_index])

	return true


func _process_fourier_data(buffer_index: int, data: PackedVector4Array) -> void:
	var result: PackedColorArray = _buffers[buffer_index].results
	var grids: Array = _displacements[_write_index]
	var grid0: PackedFloat32Array = grids[0]
	var grid1: PackedFloat32Array = grids[1]
	var grid2: PackedFloat32Array = grids[2]
	var grid3: PackedFloat32Array = grids[3]
	var count := size * size

	for index in range(count):
		var value := data[index]
		result[index] = Color(value.x, value.y, value.z, value.w)
		var channel_offset := index * CHANNELS

		match buffer_index:
			0:
				# FourierTask.ProcessData: height goes into channel 1.
				grid0[channel_offset + 1] = value.x
				grid1[channel_offset + 1] = value.y
				grid2[channel_offset + 1] = value.z
				grid3[channel_offset + 1] = value.w
			1:
				# FFT buffer 1 carries horizontal displacement for grids 0 and 1.
				grid0[channel_offset] += value.x
				grid0[channel_offset + 2] += value.y
				grid1[channel_offset] += value.z
				grid1[channel_offset + 2] += value.w
			2:
				# FFT buffer 2 carries horizontal displacement for grids 2 and 3.
				grid2[channel_offset] += value.x
				grid2[channel_offset + 2] += value.y
				grid3[channel_offset] += value.z
				grid3[channel_offset + 2] += value.w

	grids[0] = grid0
	grids[1] = grid1
	grids[2] = grid2
	grids[3] = grid3
	_displacements[_write_index] = grids
	_buffers[buffer_index].results = result


func _clear_write_displacements() -> void:
	for grid_index in range(NUM_GRIDS):
		var channels: PackedFloat32Array = _displacements[_write_index][grid_index]
		channels.fill(0.0)
		_displacements[_write_index][grid_index] = channels


func _swap_displacements() -> void:
	var previous_write := _write_index
	_write_index = _read_index
	_read_index = previous_write


func _valid_buffer_index(index: int) -> bool:
	return index >= 0 and index < NUM_BUFFERS


func copy_read_displacements() -> Array:
	var copied: Array = []
	for grid in _displacements[_read_index]:
		copied.append(grid.duplicate())
	return copied
