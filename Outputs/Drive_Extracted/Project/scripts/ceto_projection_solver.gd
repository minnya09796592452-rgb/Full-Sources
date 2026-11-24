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
var last_frustum_points: Array[Vector3] = []


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
	var position := camera.global_position
	var direction := -camera.global_basis.z.normalized()
	var margin := (20.0 if tight_fit else 50.0) + max_displacement
	if disable_projection_flipping:
		position.y = maxf(position.y, level)
		is_flipped = false
		position.y = maxf(position.y, level + margin)
	elif position.y < level:
		is_flipped = true
		position.y = minf(position.y, level - margin)
	else:
		is_flipped = false
		position.y = maxf(position.y, level + margin)

	var target := Vector3(position.x + direction.x * 50.0, level, position.z + direction.z * 50.0)
	var projector_view := _look_at_matrix(position, target, Vector3.UP)
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
	var corners: Array[Vector3] = []
	for clip_corner in FRUSTUM_CORNERS:
		var p := _mul_vector(inverse_camera_vp, [clip_corner.x, clip_corner.y, clip_corner.z, clip_corner.w])
		var divisor := p[3]
		if absf(divisor) < 0.0000001:
			divisor = 0.0000001 if divisor >= 0.0 else -0.0000001
		corners.append(Vector3(p[0] / divisor, p[1] / divisor, p[2] / divisor))
	last_frustum_points.clear()
	var extent := maxf(1.0, max_displacement)
	for corner in corners:
		if corner.y <= sea_level + extent and corner.y >= sea_level - extent:
			last_frustum_points.append(corner)
	for edge in FRUSTUM_EDGES:
		var a: Vector3 = corners[edge.x]
		var b: Vector3 = corners[edge.y]
		var point := _segment_plane_intersection(a, b, sea_level + extent)
		if point != null:
			last_frustum_points.append(point)
		point = _segment_plane_intersection(a, b, sea_level - extent)
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
		var projected := _mul_vector(projector_vp, [point.x, sea_level, point.z, 1.0])
		if absf(projected[3]) < 0.0000001:
			continue
		var x := projected[0] / projected[3]
		var y := projected[1] / projected[3]
		min_x = minf(min_x, x)
		min_y = minf(min_y, y)
		max_x = maxf(max_x, x)
		max_y = maxf(max_y, y)
	if not is_finite(min_x) or not is_finite(min_y) or not is_finite(max_x) or not is_finite(max_y):
		return range_matrix
	range_matrix[0] = maxf(max_x - min_x, 0.000001)
	range_matrix[3] = min_x
	range_matrix[5] = maxf(max_y - min_y, 0.000001)
	range_matrix[7] = min_y
	return range_matrix


func _h_project(inverse_vp: Array, corner: Vector4) -> Array:
	var near_corner := _mul_vector(inverse_vp, [corner.x, corner.y, 1.0, corner.w])
	var far_corner := _mul_vector(inverse_vp, [corner.x, corner.y, 0.0, corner.w])
	var delta: Array = []
	for i in range(4):
		delta.append(far_corner[i] - near_corner[i])
	var denominator := delta[1] - delta[3] * sea_level
	if absf(denominator) < 0.0000001:
		denominator = 0.0000001 if denominator >= 0.0 else -0.0000001
	var t := (near_corner[3] * sea_level - near_corner[1]) / denominator
	var result: Array = []
	for i in range(4):
		result.append(near_corner[i] + delta[i] * t)
	return result


func _segment_plane_intersection(a: Vector3, b: Vector3, plane_y: float):
	var delta := b - a
	if absf(delta.y) < 0.0000001:
		return null
	var t := (plane_y - a.y) / delta.y
	if t > 0.0 and t <= 1.0:
		return a + delta * t
	return null


func _look_at_matrix(position: Vector3, target: Vector3, up: Vector3) -> Array:
	var z_axis := (position - target).normalized()
	var x_axis := up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis)
	# Ceto's Unity view matrix negates the complete first row.
	return [
		-x_axis.x, -x_axis.y, -x_axis.z, x_axis.dot(position),
		y_axis.x, y_axis.y, y_axis.z, -y_axis.dot(position),
		z_axis.x, z_axis.y, z_axis.z, -z_axis.dot(position),
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
