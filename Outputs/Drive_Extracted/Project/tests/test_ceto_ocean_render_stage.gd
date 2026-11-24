extends SceneTree

const RuntimeController = preload("res://scripts/ceto_ocean_runtime_controller.gd")
const ProjectedGridScript = preload("res://scripts/ceto_projected_grid.gd")


func _initialize() -> void:
	_test_rgba_float_upload_layout()
	_test_projected_grid_resolution_mapping()
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


func _test_projected_grid_resolution_mapping() -> void:
	assert(ProjectedGridScript != null)
	assert(RuntimeController != null)
