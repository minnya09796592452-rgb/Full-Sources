extends SceneTree

const RuntimeController = preload("res://scripts/ceto_ocean_runtime_controller.gd")
const ProjectedGridScript = preload("res://scripts/ceto_projected_grid.gd")
const ProjectionSolver = preload("res://scripts/ceto_projection_solver.gd")
const Projection3f = preload("res://scripts/ceto_projection_3f.gd")
const Projection3d = preload("res://scripts/ceto_projection_3d.gd")


func _initialize() -> void:
	_test_rgba_float_upload_layout()
	_test_ceto_projected_grid_quads_and_border_uv()
	_test_projection_matrix_helpers()
	_test_projection_precision_adapters()
	print("Ceto ocean render-stage static checks passed.")
	quit(0)


func _test_rgba_float_upload_layout() -> void:
	var channels := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
	var rgba := PackedFloat32Array()
	rgba.resize(8)
	for texel in range(2):
		var src := texel * 3
		var dst := texel * 4
		rgba[dst] = channels[src]
		rgba[dst + 1] = channels[src + 1]
		rgba[dst + 2] = channels[src + 2]
		rgba[dst + 3] = 1.0
	assert(rgba == PackedFloat32Array([1.0, 2.0, 3.0, 1.0, 4.0, 5.0, 6.0, 1.0]))
	var image := Image.create_from_data(2, 1, false, Image.FORMAT_RGBAF, rgba.to_byte_array())
	assert(not image.is_empty())
	assert(image.get_format() == Image.FORMAT_RGBAF)
	assert(image.get_pixel(1, 0).is_equal_approx(Color(4.0, 5.0, 6.0, 1.0)))


func _test_ceto_projected_grid_quads_and_border_uv() -> void:
	var grid = ProjectedGridScript.new()
	grid.max_screen_width = 2048
	grid.max_screen_height = 2048
	assert(grid._resolution_to_number(1) == 1)
	assert(grid._resolution_to_number(2) == 2)
	assert(grid._resolution_to_number(4) == 4)
	assert(grid._resolution_to_number(8) == 8)
	assert(grid._resolution_to_number(16) == 16)
	assert(grid._choose_group_size(1, 128, 2048, 2048) == 128)
	var quads: Array = grid._create_screen_quads(Vector2(320.0, 180.0), 4, 0.1, 256)
	assert(quads.size() == 2)
	var first: Array = quads[0]
	var second: Array = quads[1]
	var first_vertices: PackedVector3Array = first[Mesh.ARRAY_VERTEX]
	var first_uvs: PackedVector2Array = first[Mesh.ARRAY_TEX_UV]
	var first_border: PackedVector2Array = first[Mesh.ARRAY_TEX_UV2]
	var second_border: PackedVector2Array = second[Mesh.ARRAY_TEX_UV2]
	assert(first_vertices.size() == 64 * 64)
	assert(first_uvs[0].is_equal_approx(Vector2.ZERO))
	assert(first_border[0].x > 0.0 and first_border[0].y > 0.0)
	assert(first_border[63].x == 0.0)
	assert(second_border[63].x > 0.0)
	assert(first[Mesh.ARRAY_INDEX].size() == (63 * 63 * 6))
	grid.free()


func _test_projection_matrix_helpers() -> void:
	var solver = ProjectionSolver.new()
	var identity: Array = solver._identity()
	assert(solver._multiply(identity, identity) == identity)
	assert(solver._inverse(identity) == identity)
	assert(solver._projection_to_array(solver._array_to_projection(identity)) == identity)
	var transform_matrix: Array = [2.0, 0.0, 0.0, 3.0, 0.0, 3.0, 0.0, 4.0, 0.0, 0.0, 4.0, 5.0, 0.0, 0.0, 0.0, 1.0]
	var inverse_product: Array = solver._multiply(transform_matrix, solver._inverse(transform_matrix))
	for index in range(16):
		assert(is_equal_approx(inverse_product[index], identity[index]))
	var hit = solver._segment_plane_intersection([0.0, 2.0, 0.0], [0.0, -2.0, 0.0], 0.0)
	assert(hit != null)
	assert(is_equal_approx(hit[0], 0.0) and is_equal_approx(hit[1], 0.0) and is_equal_approx(hit[2], 0.0))
	assert(ProjectionSolver.FRUSTUM_CORNERS.size() == 8)
	assert(ProjectionSolver.FRUSTUM_EDGES.size() == 12)
	solver.free()


func _test_projection_precision_adapters() -> void:
	var single = Projection3f.new()
	var double = Projection3d.new()
	assert(not single.is_double())
	assert(double.is_double())
	assert(single._precision(1.00000006) != 1.00000006)
	assert(double._precision(1.00000006) == 1.00000006)
	single.free()
	double.free()
