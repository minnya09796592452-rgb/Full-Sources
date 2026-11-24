extends SceneTree

const RuntimeController = preload("res://scripts/ceto_ocean_runtime_controller.gd")
const ProjectedGridScript = preload("res://scripts/ceto_projected_grid.gd")


func _initialize() -> void:
	_test_rgba_float_upload_layout()
	_test_projected_grid_overscan()
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


func _test_projected_grid_overscan() -> void:
	assert(ProjectedGridScript != null)
	assert(RuntimeController != null)
	var grid = ProjectedGridScript.new()
	grid.max_grid_width = 320
	grid.max_grid_height = 192
	var arrays: Array = grid._build_grid_arrays(Vector2(320.0, 180.0), 4, 0.18)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert(vertices.size() > 0)
	assert(vertices[0].x < -1.0)
	assert(vertices[0].y > 1.0)
	var last: Vector3 = vertices[vertices.size() - 1]
	assert(last.x > 1.0)
	assert(last.y < -1.0)
	grid.free()
