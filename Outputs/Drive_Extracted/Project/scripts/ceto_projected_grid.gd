extends MeshInstance3D
## Ceto ProjectedGrid port: resolution LOD, screen quad groups, border UV falloff,
## camera-dependent projector matrices, and original top/under cull-face values.

@export_enum("EXTREME:1", "ULTRA:2", "HIGH:4", "MEDIUM:8", "LOW:16") var mesh_resolution: int = 4
@export_enum("SINGLE:-1", "EXTREME:128", "HIGH:196", "MEDIUM:256", "LOW:512") var grid_group_size: int = 256
@export var receive_shadows := false
@export var sea_level := 0.0
@export_range(0.0, 1000.0, 1.0) var max_displacement := 0.0
@export_range(0.0, 1.0, 0.01) var border_uv_fraction := 0.1
@export_range(1, 2048, 1) var max_screen_width := 2048
@export_range(1, 2048, 1) var max_screen_height := 2048
@export var tight_fit := false
@export var disable_projection_flipping := true
@export var use_double_precision := true

var _projection_solver: CetoProjectionSolver
var _last_viewport_size := Vector2i.ZERO
var _last_camera_id := 0
var _last_camera_transform := Transform3D.IDENTITY
var _last_projection := Projection()


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_projection_solver = CetoProjection3d.new() if use_double_precision else CetoProjection3f.new()
	_projection_solver.tight_fit = tight_fit
	_projection_solver.disable_projection_flipping = disable_projection_flipping
	_rebuild_screen_grid()
	_update_projection()


func _process(_delta: float) -> void:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	if viewport_size != _last_viewport_size:
		_rebuild_screen_grid()
	_update_projection()


func _build_grid_arrays(viewport_size: Vector2, step: int, overscan: float = 0.1,
		group_size: int = 256) -> Array:
	var width := mini(max_screen_width, maxi(2, int(ceil(viewport_size.x))))
	var height := mini(max_screen_height, maxi(2, int(ceil(viewport_size.y))))
	var resolution := maxi(step, 1)
	var selected_group := group_size
	if selected_group != -1:
		selected_group = maxi(selected_group, resolution * 2)
		width = ceili(float(width) / selected_group) * selected_group
		height = ceili(float(height) / selected_group) * selected_group
	var quad_width := width if selected_group == -1 else selected_group
	var quad_height := height if selected_group == -1 else selected_group
	var verts_x := maxi(2, int(quad_width / resolution))
	var verts_y := maxi(2, int(quad_height / resolution))
	var quads_x := 1 if selected_group == -1 else int(width / selected_group)
	var quads_y := 1 if selected_group == -1 else int(height / selected_group)
	var arrays_list: Array = []
	for gy in range(quads_y):
		for gx in range(quads_x):
			var ux := float(gx * quad_width) / float(width)
			var uy := float(gy * quad_height) / float(height)
			var w := float(quad_width) / float(width)
			var h := float(quad_height) / float(height)
			arrays_list.append(_create_quad_arrays(verts_x, verts_y, ux, uy, w, h, overscan))
	return arrays_list


func _create_quad_arrays(verts_x: int, verts_y: int, ux: float, uy: float,
		w: float, h: float, border: float) -> Array:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var border_uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(verts_x * verts_y)
	uvs.resize(verts_x * verts_y)
	border_uvs.resize(verts_x * verts_y)
	var margin := maxf(border, 0.0)
	for y in range(verts_y):
		for x in range(verts_x):
			var screen_uv := Vector2(float(x) / float(verts_x - 1), float(y) / float(verts_y - 1))
			screen_uv = Vector2(screen_uv.x * w + ux, screen_uv.y * h + uy)
			var expanded := screen_uv * (1.0 + margin * 2.0) - Vector2.ONE * margin
			var clamped := expanded.clamp(Vector2.ZERO, Vector2.ONE)
			var outside := Vector2.ZERO
			if expanded.x < 0.0:
				outside.x = absf(expanded.x) / maxf(margin, 0.000001)
			elif expanded.x > 1.0:
				outside.x = (expanded.x - 1.0) / maxf(margin, 0.000001)
			if expanded.y < 0.0:
				outside.y = absf(expanded.y) / maxf(margin, 0.000001)
			elif expanded.y > 1.0:
				outside.y = (expanded.y - 1.0) / maxf(margin, 0.000001)
			var index := x + y * verts_x
			vertices[index] = Vector3(clamped.x, clamped.y, 0.0)
			uvs[index] = clamped
			border_uvs[index] = outside * outside
	for y in range(verts_y - 1):
		for x in range(verts_x - 1):
			var a := x + y * verts_x
			var b := a + verts_x
			indices.append_array(PackedInt32Array([a, b, a + 1, b, b + 1, a + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = border_uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func _rebuild_screen_grid() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_last_viewport_size = Vector2i(viewport_size)
	var arrays_list := _build_grid_arrays(viewport_size, mesh_resolution, border_uv_fraction, grid_group_size)
	var old_material := get_active_material(0)
	var screen_mesh := ArrayMesh.new()
	for arrays in arrays_list:
		screen_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = screen_mesh
	if old_material != null:
		for surface_index in range(screen_mesh.get_surface_count()):
			set_surface_override_material(surface_index, old_material)
	_update_projection()


func _update_projection() -> void:
	if _projection_solver == null or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_projection_solver.tight_fit = tight_fit
	_projection_solver.disable_projection_flipping = disable_projection_flipping
	var result := _projection_solver.update_projection(camera, sea_level, max_displacement)
	if result.is_empty():
		return
	var mat := get_active_material(0) as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("Ceto_Interpolation", result.interpolation)
	mat.set_shader_parameter("Ceto_ProjectorVP", result.projector_vp)
	mat.set_shader_parameter("Ceto_GridEdgeBorder", 200.0)
	mat.set_shader_parameter("Ceto_ScreenGridSize", Vector2(
		float(mesh_resolution) / maxf(float(_last_viewport_size.x), 1.0),
		float(mesh_resolution) / maxf(float(_last_viewport_size.y), 1.0)
	))
	# Unity Ceto values: 2 = back-face culling (top), 1 = front-face culling (under).
	var cull_face := 1 if camera.global_position.y < sea_level else 2
	mat.set_shader_parameter("_CullFace", cull_face)
	mat.set_shader_parameter("sea_level", sea_level)
	mat.set_shader_parameter("max_horizon_dist", 2800.0)
