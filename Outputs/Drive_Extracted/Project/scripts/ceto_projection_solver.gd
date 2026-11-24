extends RefCounted
class_name CetoProjectionSolver
## Port of Ceto Projection3f / Projection3d.
## Matrices use row-major storage internally; calculations retain double GDScript floats.

const FRUSTUM_CORNERS := [
	Vector4(-1.0, -1.0, 1.0, 1.0), Vector4(1.0, -1.0, 1.0, 1.0),
	Vector4(1.0, 1.0, 1.0, 1.0), Vector4(-1.0, 1.0, 1.0, 1.0),
	Vector4(-1.0, -1.0, 0.0, 1.0), Vector4(1.0, -1.0, 0.0, 1.0),
	Vector4(1.0, 1.0, 0.0, 1.0), Vector4(-1.0, 1.0, 0.0, 1.0)
]
const FRUSTUM_EDGES := [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
	Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)
]
const QUAD := [
	Vector4(0.0, 0.0, 0.0, 1.0), Vector4(1.0, 0.0, 0.0, 1.0),
	Vector4(1.0, 1.0, 0.0, 1.0), Vector4(0.0, 1.0, 0.0, 1.0)
]

var is_flipped := false
var tight_fit := false
var disable_projection_flipping := true
var max_displacement := 0.0
var sea_level := 0.0
var last_projector_vp := Projection()
var last_interpolation := Projection()
var last_range_matrix := Projection()
var last_frustum_points: Array = []


func is_double() -> bool:
	return true


func _precision(value: float) -> float:
	if is_double():
		return value
	var packed := PackedFloat32Array()
	packed.append(value)
	return packed[0]


func update_projection(camera: Camera3D, level: float, displacement: float = 0.0) -> Dictionary:
	if camera == null:
		return {}
	sea_level = level
	max_displacement = maxf(displacement, 0.0)
	var projection := _projection_to_array(camera.get_camera_projection())
	var camera_view := _transform_to_array(camera.global_transform.affine_inverse())
	var camera_position := camera.global_position
	var direction := -camera.global_basis.z.normalized()
	var position: Array = [camera_position.x, camera_position.y, camera_position.z]
	var margin := (20.0 if tight_fit else 50.0) + max_displacement
	if disable_projection_flipping:
		position[1] = _precision(maxf(position[1], level))
		is_flipped = false
		position[1] = _precision(maxf(position[1], level + margin))
	elif position[1] < level:
		is_flipped = true
		position[1] = _precision(minf(position[1], level - margin))
	else:
		is_flipped = false
		position[1] = maxf(position[1], level + margin)

	var target: Array = [
		_precision(position[0] + direction.x * 50.0),
		level,
		_precision(position[2] + direction.z * 50.0)
	]
	var projector_view := _look_at_matrix(position, target, [0.0, 1.0, 0.0])
	var projector_vp := _multiply(projection, projector_view)
	var range_matrix := _create_range_matrix(projection, camera_view, projector_vp)
	var inverse_vp := _multiply(_inverse(projector_vp), range_matrix)
	var interpolation := _identity()
	for i in range(4):
		var projected := _h_project(inverse_vp, QUAD[i])
		for j in range(4):
			interpolation[i * 4 + j] = projected[j]
	var projector_result := _multiply(_inverse(range_matrix), projector_vp)

	last_projector_vp = _array_to_projection(projector_result)
	last_interpolation = _array_to_projection(interpolation)
	last_range_matrix = _array_to_projection(range_matrix)
	return {
		"projector_vp": last_projector_vp,
		"interpolation": last_interpolation,
		"range_matrix": last_range_matrix,
		"is_flipped": is_flipped,
		"frustum_points": last_frustum_points.duplicate()
	}


func _create_range_matrix(projection: Array, camera_view: Array, projector_vp: Array) -> Array:
	var range_matrix := _identity()
	var inverse_camera_vp := _inverse(_multiply(projection, camera_view))
	var corners: Array = []
	for clip_corner in FRUSTUM_CORNERS:
		var p := _mul_vector(inverse_camera_vp, [clip_corner.x, clip_corner.y, clip_corner.z, clip_corner.w])
		var divisor: float = p[3]
		if absf(divisor) < 0.0000001:
			divisor = 0.0000001 if divisor >= 0.0 else -0.0000001
		corners.append([
			_precision(p[0] / divisor),
			_precision(p[1] / divisor),
			_precision(p[2] / divisor)
		])
	last_frustum_points.clear()
	var extent := maxf(1.0, max_displacement)
	for corner in corners:
		if corner[1] <= sea_level + extent and corner[1] >= sea_level - extent:
			last_frustum_points.append(corner.duplicate())
	for edge in FRUSTUM_EDGES:
		var point = _segment_plane_intersection(corners[edge.x], corners[edge.y], sea_level + extent)
		if point != null:
			last_frustum_points.append(point)
		point = _segment_plane_intersection(corners[edge.x], corners[edge.y], sea_level - extent)
		if point != null:
			last_frustum_points.append(point)
	if last_frustum_points.is_empty():
		range_matrix[0] = 1.0
		range_matrix[3] = 0.0
		range_matrix[5] = 1.0
		range_matrix[7] = 0.0
		return range_matrix

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in last_frustum_points:
		var projected := _mul_vector(projector_vp, [point[0], sea_level, point[2], 1.0])
		if absf(projected[3]) < 0.0000001:
			continue
		var x := _precision(projected[0] / projected[3])
		var y := _precision(projected[1] / projected[3])
		min_x = minf(min_x, x)
		min_y = minf(min_y, y)
		max_x = maxf(max_x, x)
		max_y = maxf(max_y, y)
	if is_inf(min_x) or is_inf(min_y) or is_inf(max_x) or is_inf(max_y) or is_nan(min_x) or is_nan(min_y) or is_nan(max_x) or is_nan(max_y):
		return range_matrix
	range_matrix[0] = _precision(maxf(max_x - min_x, 0.000001))
	range_matrix[3] = min_x
	range_matrix[5] = _precision(maxf(max_y - min_y, 0.000001))
	range_matrix[7] = min_y
	return range_matrix

func _h_project(inverse_vp: Array, corner: Vector4) -> Array:
	var near_corner := _mul_vector(inverse_vp, [corner.x, corner.y, 1.0, corner.w])
	var far_corner := _mul_vector(inverse_vp, [corner.x, corner.y, 0.0, corner.w])
	var delta: Array = []
	for i in range(4):
		delta.append(_precision(far_corner[i] - near_corner[i]))
	var denominator := _precision(delta[1] - _precision(delta[3] * sea_level))
	if absf(denominator) < 0.0000001:
		denominator = 0.0000001 if denominator >= 0.0 else -0.0000001
	var t := _precision(_precision(near_corner[3] * sea_level - near_corner[1]) / denominator)
	var result: Array = []
	for i in range(4):
		result.append(_precision(near_corner[i] + _precision(delta[i] * t)))
	return result


func _segment_plane_intersection(a: Array, b: Array, plane_y: float):
	var dx := _precision(b[0] - a[0])
	var dy := _precision(b[1] - a[1])
	var dz := _precision(b[2] - a[2])
	if absf(dy) < 0.0000001:
		return null
	var t := _precision(_precision(plane_y - a[1]) / dy)
	if t > 0.0 and t <= 1.0:
		return [
			_precision(a[0] + _precision(dx * t)),
			_precision(a[1] + _precision(dy * t)),
			_precision(a[2] + _precision(dz * t))
		]
	return null


func _dot3(a: Array, b: Array) -> float:
	return _precision(_precision(a[0] * b[0]) + _precision(a[1] * b[1]) + _precision(a[2] * b[2]))


func _cross3(a: Array, b: Array) -> Array:
	return [
		_precision(_precision(a[1] * b[2]) - _precision(a[2] * b[1])),
		_precision(_precision(a[2] * b[0]) - _precision(a[0] * b[2])),
		_precision(_precision(a[0] * b[1]) - _precision(a[1] * b[0]))
	]


func _normalize3(value: Array) -> Array:
	var length := sqrt(_dot3(value, value))
	if length < 0.0000001:
		return [0.0, 0.0, 0.0]
	return [
		_precision(value[0] / length),
		_precision(value[1] / length),
		_precision(value[2] / length)
	]


func _look_at_matrix(position: Array, target: Array, up: Array) -> Array:
	var z_axis := _normalize3([
		_precision(position[0] - target[0]),
		_precision(position[1] - target[1]),
		_precision(position[2] - target[2])
	])
	var x_axis := _normalize3(_cross3(up, z_axis))
	var y_axis := _cross3(z_axis, x_axis)
	# Ceto's Unity view matrix negates the complete first row.
	return [
		-_precision(x_axis[0]), -_precision(x_axis[1]), -_precision(x_axis[2]), _dot3(x_axis, position),
		y_axis[0], y_axis[1], y_axis[2], -_dot3(y_axis, position),
		z_axis[0], z_axis[1], z_axis[2], -_dot3(z_axis, position),
		0.0, 0.0, 0.0, 1.0
	]


func _projection_to_array(p: Projection) -> Array:
	return [
		p.x.x, p.y.x, p.z.x, p.w.x,
		p.x.y, p.y.y, p.z.y, p.w.y,
		p.x.z, p.y.z, p.z.z, p.w.z,
		p.x.w, p.y.w, p.z.w, p.w.w
	]


func _transform_to_array(t: Transform3D) -> Array:
	var inv := t
	return [
		inv.basis.x.x, inv.basis.y.x, inv.basis.z.x, inv.origin.x,
		inv.basis.x.y, inv.basis.y.y, inv.basis.z.y, inv.origin.y,
		inv.basis.x.z, inv.basis.y.z, inv.basis.z.z, inv.origin.z,
		0.0, 0.0, 0.0, 1.0
	]


func _array_to_projection(m: Array) -> Projection:
	return Projection(
		Vector4(m[0], m[4], m[8], m[12]),
		Vector4(m[1], m[5], m[9], m[13]),
		Vector4(m[2], m[6], m[10], m[14]),
		Vector4(m[3], m[7], m[11], m[15])
	)


func _identity() -> Array:
	return [
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.0, 0.0, 0.0, 1.0
	]


func _multiply(a: Array, b: Array) -> Array:
	var result: Array = []
	result.resize(16)
	for row in range(4):
		for column in range(4):
			var value := 0.0
			for k in range(4):
				value = _precision(value + _precision(a[row * 4 + k] * b[k * 4 + column]))
			result[row * 4 + column] = value
	return result


func _mul_vector(m: Array, v: Array) -> Array:
	var result: Array = [0.0, 0.0, 0.0, 0.0]
	for row in range(4):
		for column in range(4):
			result[row] = _precision(result[row] + _precision(m[row * 4 + column] * v[column]))
	return result


func _inverse(source: Array) -> Array:
	var a: Array = []
	for row in range(4):
		var line: Array = []
		for column in range(4):
			line.append(source[row * 4 + column])
		for column in range(4):
			line.append(1.0 if row == column else 0.0)
		a.append(line)
	for column in range(4):
		var pivot := column
		for row in range(column + 1, 4):
			if absf(a[row][column]) > absf(a[pivot][column]):
				pivot = row
		if absf(a[pivot][column]) < 0.000000000001:
			return _identity()
		if pivot != column:
			var swap = a[column]
			a[column] = a[pivot]
			a[pivot] = swap
		var divisor: float = a[column][column]
		for j in range(8):
			a[column][j] = _precision(a[column][j] / divisor)
		for row in range(4):
			if row == column:
				continue
			var factor: float = a[row][column]
			for j in range(8):
				a[row][j] = _precision(a[row][j] - _precision(factor * a[column][j]))
	var result: Array = []
	result.resize(16)
	for row in range(4):
		for column in range(4):
			result[row * 4 + column] = a[row][column + 4]
	return result
