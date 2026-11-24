class_name CetoPhillipsSpectrum
extends RefCounted
## Direct GDScript port of Ceto.PhillipsSpectrum.

const GRAVITY: float = 9.818286
const AMP: float = 0.02

var wind_speed: float
var wind_dir: Vector2
var length2: float
var damped_length2: float


func _init(p_wind_speed: float, p_wind_dir_degrees: float) -> void:
	wind_speed = p_wind_speed
	var radians: float = p_wind_dir_degrees * PI / 180.0
	wind_dir = Vector2(cos(radians), sin(radians))
	var deep_water_length: float = wind_speed * wind_speed / GRAVITY
	length2 = deep_water_length * deep_water_length
	var damping: float = 0.001
	damped_length2 = length2 * damping * damping


func spectrum(kx: float, kz: float) -> float:
	# Keep the same direction rotation and component order as the C# source.
	var rotated_x: float = kx * wind_dir.x - kz * wind_dir.y
	var rotated_z: float = kx * wind_dir.y + kz * wind_dir.x
	kx = rotated_x
	kz = rotated_z

	var wave_number: float = sqrt(kx * kx + kz * kz)
	if wave_number < 1.0e-6:
		return 0.0

	var k_squared: float = wave_number * wave_number
	var k_fourth: float = k_squared * k_squared
	kx /= wave_number
	kz /= wave_number

	var directional_dot: float = kx * 1.0 + kz * 0.0
	var directional_sixth: float = directional_dot * directional_dot * directional_dot * directional_dot * directional_dot * directional_dot
	return AMP * exp(-1.0 / (k_squared * length2)) / k_fourth * directional_sixth * exp(-k_squared * damped_length2)
