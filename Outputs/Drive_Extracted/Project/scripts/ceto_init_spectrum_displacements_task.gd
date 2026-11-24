class_name CetoInitSpectrumDisplacementsTask
extends RefCounted
## Four-grid port of Ceto.InitSpectrumDisplacementsTask.
## Builds height-frequency data (buffer 0) and horizontal displacement
## frequency data (buffers 1 and 2) before the three CPU FFT passes.

var size: int
var num_grids: int
var time_value: float
var _spectrum01: PackedColorArray
var _spectrum23: PackedColorArray
var _wtable: PackedColorArray
var _inverse_grid_sizes: Vector4
var _data: Array = []
var _buffer


func _init(buffer: Variant, condition: Variant, time: float) -> void:
	if buffer == null or condition == null:
		push_error("CetoInitSpectrumDisplacementsTask: buffer and condition are required.")
		return
	size = int(condition.size)
	num_grids = int(condition.num_grids)
	time_value = time
	if size <= 0 or num_grids != 4:
		push_error("CetoInitSpectrumDisplacementsTask: this port currently requires exactly four grids.")
		return
	if condition.spectrum01.size() != size * size or condition.spectrum23.size() != size * size or condition.wtable.size() != size * size:
		push_error("CetoInitSpectrumDisplacementsTask: spectrum condition arrays are incomplete.")
		return

	_buffer = buffer
	_spectrum01 = condition.spectrum01
	_spectrum23 = condition.spectrum23
	_wtable = condition.wtable
	_inverse_grid_sizes = condition.inverse_grid_sizes()
	for buffer_index in range(3):
		_data.append(buffer.get_read_buffer(buffer_index))


func run() -> bool:
	if _data.size() != 3:
		return false
	var height_data: PackedVector4Array = _data[0]
	var displacement_01: PackedVector4Array = _data[1]
	var displacement_23: PackedVector4Array = _data[2]
	var count := size * size
	var inverse_size := 1.0 / float(size)

	for row in range(size):
		for column in range(size):
			var index := column + row * size
			var mirror_index := ((size - column) % size) + ((size - row) % size) * size
			var uv := Vector2(float(column) * inverse_size, float(row) * inverse_size)
			var centered := Vector2(
				uv.x - 1.0 if uv.x > 0.5 else uv.x,
				uv.y - 1.0 if uv.y > 0.5 else uv.y
			)

			var c0 := _spectrum01[index]
			var c1 := _spectrum01[mirror_index]
			var c2 := _spectrum23[index]
			var c3 := _spectrum23[mirror_index]
			var omega := _wtable[index]
			var h0 := _rotate_pair(c0.r, c0.g, c1.r, c1.g, omega.r * time_value)
			var h1 := _rotate_pair(c0.b, c0.a, c1.b, c1.a, omega.g * time_value)
			var h2 := _rotate_pair(c2.r, c2.g, c3.r, c3.g, omega.b * time_value)
			var h3 := _rotate_pair(c2.b, c2.a, c3.b, c3.a, omega.a * time_value)

			# C# InitilizeGrids4 packs h0 + i*h1 and h2 + i*h3.
			height_data[index] = Vector4(
				h0.x - h1.y,
				h0.y + h1.x,
				h2.x - h3.y,
				h2.y + h3.x
			)

			var k0 := _k_vector(centered, _inverse_grid_sizes.x)
			var k1 := _k_vector(centered, _inverse_grid_sizes.y)
			var k2 := _k_vector(centered, _inverse_grid_sizes.z)
			var k3 := _k_vector(centered, _inverse_grid_sizes.w)
			var d0 := _horizontal_displacement(h0, k0)
			var d1 := _horizontal_displacement(h1, k1)
			var d2 := _horizontal_displacement(h2, k2)
			var d3 := _horizontal_displacement(h3, k3)
			displacement_01[index] = Vector4(d0.x, d0.y, d1.x, d1.y)
			displacement_23[index] = Vector4(d2.x, d2.y, d3.x, d3.y)

	height_data.resize(count)
	displacement_01.resize(count)
	displacement_23.resize(count)
	_data[0] = height_data
	_data[1] = displacement_01
	_data[2] = displacement_23
	for buffer_index in range(3):
		_buffer.set_read_buffer(buffer_index, _data[buffer_index])
	return true


## Exact C# pair rotation used by InitilizeGrids4.
func _rotate_pair(real_k: float, imag_k: float, real_mirror: float, imag_mirror: float, angle: float) -> Vector2:
	var cosine := cos(angle)
	var sine := sin(angle)
	return Vector2(
		(real_k + real_mirror) * cosine - (imag_k + imag_mirror) * sine,
		(real_k - real_mirror) * sine + (imag_k - imag_mirror) * cosine
	)


func _k_vector(centered: Vector2, inverse_grid_size: float) -> Vector3:
	var k := centered * inverse_grid_size
	var magnitude := k.length()
	return Vector3(k.x, k.y, 0.0 if is_zero_approx(magnitude) else 1.0 / magnitude)


## Ceto's -i * k_hat * h transform, returning its real/imaginary pair.
func _horizontal_displacement(height: Vector2, k: Vector3) -> Vector2:
	return Vector2(
		(-k.x * height.y - k.y * height.x) * k.z,
		(k.x * height.x - k.y * height.y) * k.z
	)


func get_data(buffer_index: int) -> PackedVector4Array:
	if buffer_index < 0 or buffer_index >= _data.size():
		return PackedVector4Array()
	return _data[buffer_index]
