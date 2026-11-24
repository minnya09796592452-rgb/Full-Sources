class_name CetoUnifiedSpectrum
extends RefCounted
## Direct GDScript port of Ceto.UnifiedSpectrum (including constants and
## intermediate terms, rather than replacing it with a simplified spectrum).

const GRAVITY: float = 9.818286
const WAVE_CM: float = 0.23
const WAVE_KM: float = 370.0

var u10: float
var wave_age: float
var wind_dir: Vector2

var _pi_2: float
var _sqrt_10: float
var _g_sq_omega_u10: float
var _z_sq_u10_g: float
var _log_omega_6: float
var _sigma: float
var _sq_sigma_2: float
var _alpha_p: float
var _log_2_4: float
var _kp: float
var _cp: float
var _z0: float
var _u_star: float
var _gamma: float
var _half_alpha_p_cp: float
var _alpham: float
var _half_alpham_wave_cm: float
var _am: float


func _init(wind_speed: float, wind_dir_degrees: float, p_wave_age: float) -> void:
	u10 = wind_speed
	wave_age = p_wave_age
	var radians: float = wind_dir_degrees * PI / 180.0
	wind_dir = Vector2(cos(radians), sin(radians))

	_pi_2 = PI * 2.0
	_sqrt_10 = sqrt(10.0)
	_g_sq_omega_u10 = GRAVITY * _sqr(wave_age / u10)
	_z_sq_u10_g = 3.7e-5 * _sqr(u10) / 9.81
	_log_omega_6 = log(wave_age) * 6.0
	_sigma = 0.08 * (1.0 + 4.0 / pow(wave_age, 3.0))
	_sq_sigma_2 = _sqr(_sigma) * 2.0
	_alpha_p = 0.006 * sqrt(wave_age)
	_log_2_4 = log(2.0) / 4.0
	_kp = _g_sq_omega_u10
	_cp = _omega(_kp) / _kp
	_z0 = _z_sq_u10_g * pow(u10 / _cp, 0.9)
	_u_star = 0.41 * u10 / log(10.0 / _z0)
	_gamma = 1.7 if wave_age < 1.0 else 1.7 + _log_omega_6
	_half_alpha_p_cp = 0.5 * _alpha_p * _cp
	_alpham = 0.01 * (1.0 + log(_u_star / WAVE_CM) if _u_star < WAVE_CM else 1.0 + 3.0 * log(_u_star / WAVE_CM))
	_half_alpham_wave_cm = 0.5 * _alpham * WAVE_CM
	_am = 0.13 * _u_star / WAVE_CM


func _sqr(value: float) -> float:
	return value * value


func _omega(k: float) -> float:
	return sqrt(GRAVITY * k * (1.0 + _sqr(k / WAVE_KM)))


func spectrum(kx: float, ky: float) -> float:
	var rotated_x: float = kx * wind_dir.x - ky * wind_dir.y
	var rotated_y: float = kx * wind_dir.y + ky * wind_dir.x
	kx = rotated_x
	ky = rotated_y

	var wave_number: float = sqrt(kx * kx + ky * ky)
	var phase_speed: float = _omega(wave_number) / wave_number
	var peak_suppression: float = exp(-1.25 * _sqr(_kp / wave_number))
	var peak_shape: float = exp(-1.0 / _sq_sigma_2 * _sqr(sqrt(wave_number / _kp) - 1.0))
	var peak_enhancement: float = pow(_gamma, peak_shape)
	var long_wave_tail: float = peak_suppression * peak_enhancement * exp(-wave_age / _sqrt_10 * (sqrt(wave_number / _kp) - 1.0))
	var low_frequency_term: float = _half_alpha_p_cp / phase_speed * long_wave_tail
	var short_wave_damping: float = exp(-0.25 * _sqr(wave_number / WAVE_KM - 1.0))
	var high_frequency_term: float = _half_alpham_wave_cm / phase_speed * short_wave_damping * peak_suppression
	var directional_spread: float = tanh(_log_2_4 + 4.0 * pow(phase_speed / _cp, 2.5) + _am * pow(WAVE_CM / phase_speed, 2.5))
	var direction_angle: float = atan2(ky, kx)

	if kx < 0.0:
		return 0.0

	low_frequency_term *= 2.0
	high_frequency_term *= 2.0
	var forward_direction: float = sqrt(max(kx / wave_number, 0.0))
	return (low_frequency_term + high_frequency_term) * (1.0 + directional_spread * cos(2.0 * direction_angle)) / (_pi_2 * wave_number * wave_number * wave_number * wave_number) * forward_direction
