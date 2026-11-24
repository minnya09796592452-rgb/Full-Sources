class_name CetoDotNetRandom
extends RefCounted
## .NET Framework-compatible seeded System.Random implementation.
## System.Random(seed) uses this subtractive generator for explicit seeds,
## including current .NET compatibility mode. This preserves seed-0 NextDouble.

const MBIG: int = 2147483647
const MSEED: int = 161803398

var _seed_array := PackedInt32Array()
var _inext: int = 0
var _inextp: int = 21


func _init(seed: int = 0) -> void:
	_seed_array.resize(56)
	var subtraction: int = MBIG if seed == -2147483648 else absi(seed)
	var mj: int = MSEED - subtraction
	_seed_array[55] = mj
	var mk: int = 1

	for i in range(1, 55):
		var ii: int = (21 * i) % 55
		_seed_array[ii] = mk
		mk = mj - mk
		if mk < 0:
			mk += MBIG
		mj = _seed_array[ii]

	for _pass in range(4):
		for i in range(1, 56):
			_seed_array[i] -= _seed_array[1 + (i + 30) % 55]
			if _seed_array[i] < 0:
				_seed_array[i] += MBIG

	_inext = 0
	_inextp = 21


func _internal_sample() -> int:
	_inext += 1
	if _inext >= 56:
		_inext = 1
	_inextp += 1
	if _inextp >= 56:
		_inextp = 1

	var result: int = _seed_array[_inext] - _seed_array[_inextp]
	if result == MBIG:
		result -= 1
	if result < 0:
		result += MBIG
	_seed_array[_inext] = result
	return result


func next_double() -> float:
	return float(_internal_sample()) * (1.0 / float(MBIG))
