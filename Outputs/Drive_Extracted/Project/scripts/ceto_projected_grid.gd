extends MeshInstance3D

@export var border_length: float = 200.0
@export var max_horizon_dist: float = 2800.0

func _ready() -> void:
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    extra_cull_margin = border_length

func _process(_delta: float) -> void:
    var cam := get_viewport().get_camera_3d()
    if cam:
        # Ceto ProjectedGrid keeps high-density mesh centered around camera XZ in world space
        global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z)
