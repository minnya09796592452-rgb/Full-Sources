extends MeshInstance3D
## Screen-space ProjectedGrid with an overscan guard band.
## The extra NDC area keeps the viewport covered after horizontal choppy displacement.

@export_range(1, 16, 1) var resolution_step: int = 4
@export_range(16, 512, 8) var max_grid_width: int = 320
@export_range(16, 512, 8) var max_grid_height: int = 192
@export_range(0.0, 0.5, 0.01) var overscan_fraction: float = 0.18
@export var sea_level: float = 0.0
@export var max_horizon_dist: float = 2800.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = max_horizon_dist
	_rebuild_screen_grid()
	_update_projection_uniforms()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree():
		_rebuild_screen_grid()


func _process(_delta: float) -> void:
	var mat := get_active_material(0) as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("sea_level", sea_level)
	mat.set_shader_parameter("max_horizon_dist", max_horizon_dist)


func _build_grid_arrays(viewport_size: Vector2, step: int, overscan: float) -> Array:
	var width := clampi(ceili(viewport_size.x / float(step)) + 1, 2, max_grid_width)
	var height := clampi(ceili(viewport_size.y / float(step)) + 1, 2, max_grid_height)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(width * height)
	uvs.resize(width * height)

	var margin := maxf(overscan, 0.0)
	for y in range(height):
		for x in range(width):
			var u := float(x) / float(width - 1)
			var v := float(y) / float(height - 1)
			var ndc_x := lerpf(-1.0 - margin * 2.0, 1.0 + margin * 2.0, u)
			var ndc_y := lerpf(1.0 + margin * 2.0, -1.0 - margin * 2.0, v)
			var index := x + y * width
			vertices[index] = Vector3(ndc_x, ndc_y, 0.0)
			uvs[index] = Vector2(u, v)

	for y in range(height - 1):
		for x in range(width - 1):
			var a := x + y * width
			var b := a + width
			indices.append_array(PackedInt32Array([a, b, a + 1, b, b + 1, a + 1]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func _rebuild_screen_grid() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var arrays := _build_grid_arrays(viewport_size, resolution_step, overscan_fraction)
	var old_material := get_active_material(0)
	var screen_mesh := ArrayMesh.new()
	screen_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = screen_mesh
	if old_material != null:
		set_surface_override_material(0, old_material)


func _update_projection_uniforms() -> void:
	var mat := get_active_material(0) as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("sea_level", sea_level)
		mat.set_shader_parameter("max_horizon_dist", max_horizon_dist)
