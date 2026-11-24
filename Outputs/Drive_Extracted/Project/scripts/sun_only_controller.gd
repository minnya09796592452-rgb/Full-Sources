extends Node3D

@export_range(0.0, 24.0, 0.05) var time_of_day: float = 10.0
@export var auto_cycle: bool = false
@export var cycle_speed: float = 0.45
@export var azimuth_deg: float = 0.0

const ORIG_SUN_COLOR := Color(1.0, 0.99222, 0.98529, 1.0)
const WARM_HORIZON_COLOR := Color(1.0, 0.58, 0.30, 1.0)
const MOON_LIGHT_COLOR := Color(0.55, 0.68, 0.95, 1.0)

@onready var sun_light: DirectionalLight3D = $SunDirectionalLight
@onready var world_env: WorldEnvironment = $WorldEnvironment

func _ready() -> void:
    _update_celestial()

func _process(delta: float) -> void:
    if auto_cycle:
        time_of_day = fmod(time_of_day + delta * cycle_speed, 24.0)
    _update_celestial()

func _update_celestial() -> void:
    var elev_deg: float = ((time_of_day - 6.0) / 12.0) * 180.0
    var elev_rad: float = deg_to_rad(elev_deg)
    var azim_rad: float = deg_to_rad(azimuth_deg)
    var sun_dir := Vector3(cos(elev_rad) * sin(azim_rad), sin(elev_rad), cos(elev_rad) * cos(azim_rad)).normalized()
    var moon_dir := -sun_dir

    var is_day: bool = sun_dir.y > -0.05
    var active_dir: Vector3 = sun_dir if is_day else moon_dir
    sun_light.look_at_from_position(active_dir * 60.0, Vector3.ZERO, Vector3.UP)

    if is_day:
        var h: float = clamp(sun_dir.y, 0.0, 1.0)
        sun_light.light_color = WARM_HORIZON_COLOR.lerp(ORIG_SUN_COLOR, pow(h, 0.42))
        sun_light.light_energy = lerp(0.15, 1.75, pow(h, 0.55))
    else:
        var mh: float = clamp(moon_dir.y, 0.0, 1.0)
        sun_light.light_color = MOON_LIGHT_COLOR
        sun_light.light_energy = lerp(0.05, 0.38, pow(mh, 0.6))

    if world_env and world_env.environment and world_env.environment.sky:
        var mat := world_env.environment.sky.sky_material as ShaderMaterial
        if mat:
            mat.set_shader_parameter("moon_dir", moon_dir)
