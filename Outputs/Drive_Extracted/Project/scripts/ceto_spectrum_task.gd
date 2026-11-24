class_name CetoSpectrumTask
extends RefCounted
## Direct GDScript port of Ceto.SpectrumTask's WTable and initial h0 spectrum
## generation. Uses the legacy seeded .NET System.Random sequence (seed=0).

const DotNetRandom = preload("res://scripts/ceto_dotnet_random.gd")

const GRAVITY: float = 9.818286
const WAVE_CM: float = 0.23
const WAVE_KM: float = 370.0
const DISTRIBUTION_LINEAR: String = "LINEAR"
const DISTRIBUTION_GAUSSIAN: String = "GAUSSIAN"

var size: int
var num_grids: int
var grid_sizes: Vector4
var inverse_grid_sizes: Vector4
var wave_amps: Vector4
var spectrums: Array
var distribution: String = DISTRIBUTION_LINEAR

var spectrum01: PackedColorArray = PackedColorArray()
var spectrum23: PackedColorArray = PackedColorArray()
var wtable: PackedColorArray = PackedColorArray()

var _random
var _cancel_check: Callable = Callable()
var cancelled: bool = false


func _init(condition: Variant) -> void:
	if condition == null:
		push_error("CetoSpectrumTask: condition is required.")
		return
	size = int(condition.size)
	num_grids = int(condition.num_grids)
	grid_sizes = condition.grid_sizes
	wave_amps = condition.wave_amps
	spectrums = condition.spectrums.duplicate()
	inverse_grid_sizes = condition.inverse_grid_sizes()
	if size <= 0 or num_grids < 1 or num_grids > 4 or spectrums.size() != 4:
		push_error("CetoSpectrumTask: invalid condition.")
		return

	spectrum01.resize(size * size)
	if num_grids > 2:
		spectrum23.resize(size * size)
	wtable.resize(size * size)
	_random = DotNetRandom.new(0)


func run(cancel_check: Callable = Callable()) -> Dictionary:
	_cancel_check = cancel_check
	cancelled = false
	_create_w_table()
	if cancelled:
		return _result()
	_generate_waves_spectrum()
	return _result()


func _result() -> Dictionary:
	return {
		"cancelled": cancelled,
		"spectrum01": spectrum01,
		"spectrum23": spectrum23,
		"wtable": wtable
	}


func _is_cancelled() -> bool:
	if _cancel_check.is_valid() and bool(_cancel_check.call()):
		cancelled = true
	return cancelled


func _random_number() -> float:
	if distribution == DISTRIBUTION_GAUSSIAN:
		return _gaussian_random_number()
	return _random.next_double()


func _gaussian_random_number() -> float:
	var x: float
	var radius_squared: float
	while true:
		x = 2.0 * _random.next_double() - 1.0
		var y: float = 2.0 * _random.next_double() - 1.0
		radius_squared = x * x + y * y
		if radius_squared < 1.0:
			break
	var scale: float = sqrt(-2.0 * log(radius_squared) / radius_squared)
	return x * scale


func _get_spectrum_sample(i: float, j: float, dk: float, k_min: float, amp: float, spectrum: Variant) -> float:
	if spectrum == null:
		return 0.0
	var kx: float = i * dk
	var ky: float = j * dk
	var sample: float = 0.0
	if absf(kx) >= k_min or absf(ky) >= k_min:
		sample = sqrt(spectrum.spectrum(kx, ky) * amp * 0.5) * dk
		if is_nan(sample) or is_inf(sample):
			sample = 0.0
	return sample


func _generate_waves_spectrum() -> void:
	var half_size: int = size / 2
	var size_float: float = float(size)
	var tau: float = TAU
	var k_min: float = PI / grid_sizes.x
	var k_min2: float = PI * size_float / grid_sizes.x
	var k_min3: float = PI * size_float / grid_sizes.y
	var k_min4: float = PI * size_float / grid_sizes.z
	var dk: float = tau / grid_sizes.x
	var dk2: float = tau / grid_sizes.y
	var dk3: float = tau / grid_sizes.z
	var dk4: float = tau / grid_sizes.w
	var amps := [wave_amps.x, wave_amps.y, wave_amps.z, wave_amps.w]
	var dks := [dk, dk2, dk3, dk4]
	var k_mins := [k_min, k_min2, k_min3, k_min4]

	for row in range(size):
		for column in range(size):
			if _is_cancelled():
				return
			var index: int = column + row * size
			var wave_i: float = float(column - size if column >= half_size else column)
			var wave_j: float = float(row - size if row >= half_size else row)
			var channels := [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]

			for grid in range(num_grids):
				# C# consumes one random value before each grid's spectrum sample.
				var phase: float = _random_number() * tau
				var amplitude: float = _get_spectrum_sample(
					wave_i, wave_j, dks[grid], k_mins[grid], amps[grid], spectrums[grid]
				)
				var real_part: float = amplitude * cos(phase) * 1.4142135
				var imaginary_part: float = amplitude * sin(phase) * 1.4142135
				var color_index: int = 0 if grid < 2 else 1
				var color: Color = channels[color_index]
				match grid % 2:
					0:
						color.r = real_part
						color.g = imaginary_part
					1:
						color.b = real_part
						color.a = imaginary_part
				channels[color_index] = color

			spectrum01[index] = channels[0]
			if num_grids > 2:
				spectrum23[index] = channels[1]


func _create_w_table() -> void:
	var size_float: float = float(size)
	var inverse_size: float = 1.0 / size_float
	var inv_sq := [
		inverse_grid_sizes.x * inverse_grid_sizes.x,
		inverse_grid_sizes.y * inverse_grid_sizes.y,
		inverse_grid_sizes.z * inverse_grid_sizes.z,
		inverse_grid_sizes.w * inverse_grid_sizes.w
	]
	var gravity_km_squared: float = 136900.0

	for row in range(size):
		for column in range(size):
			if _is_cancelled():
				return
			var index: int = column + row * size
			var uv := Vector2(float(column) * inverse_size, float(row) * inverse_size)
			var centered := Vector2(
				uv.x - 1.0 if uv.x > 0.5 else uv.x,
				uv.y - 1.0 if uv.y > 0.5 else uv.y
			)
			var squared := Vector2(centered.x * centered.x, centered.y * centered.y)
			var color := Color(0, 0, 0, 0)

			for grid in range(num_grids):
				var wave_number: float = sqrt(squared.x * inv_sq[grid] + squared.y * inv_sq[grid])
				var omega: float = sqrt(GRAVITY * wave_number * (1.0 + wave_number * wave_number / gravity_km_squared))
				match grid:
					0: color.r = omega
					1: color.g = omega
					2: color.b = omega
					3: color.a = omega

			wtable[index] = color


func apply_to_condition(condition: Variant) -> void:
	if condition == null or cancelled:
		return
	condition.apply_spectrum_data(spectrum01, spectrum23, wtable)
	condition.done = true
