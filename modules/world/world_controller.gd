extends Node3D

@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment

var current_time: float = 0.0 # 0.0 to 1.0
var target_time: float = 0.0
var time_lerp_speed: float = 2.0

func _ready() -> void:
	if world_env:
		world_env.environment = world_env.environment.duplicate()
	setup_sky()

func setup_sky() -> void:
	if not world_env or not world_env.environment:
		return
		
	var sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	
	world_env.environment.sky = sky
	world_env.environment.background_mode = Environment.BG_SKY

func _process(delta: float) -> void:
	# Smoothly interpolate time to avoid jumps
	if abs(current_time - target_time) > 0.5:
		# Handle wraparound
		if current_time < target_time:
			current_time += 1.0
		else:
			target_time += 1.0
			
	current_time = lerp(current_time, target_time, delta * time_lerp_speed)
	if current_time >= 1.0:
		current_time -= 1.0
		target_time -= 1.0

	update_sun_position()

func update_sun_position() -> void:
	# Time 0.0 is midnight, 0.5 is noon.
	# We want sun to be at top at 0.5.
	# Angle should be (time - 0.25) * 2 * PI
	var sun_angle = (current_time - 0.25) * 2.0 * PI
	
	# Rotate sun around X axis
	var rot = Vector3(sun_angle, deg_to_rad(-90), 0)
	sun.rotation = rot
	
	# Adjust sun energy based on height
	var sun_height = sin(sun_angle)
	sun.light_energy = clamp(sun_height * 2.0, 0.0, 1.0)
	
	# Optional: Set environment ambient light or other properties based on time
	if sun_height < -0.1:
		sun.visible = false
	else:
		sun.visible = true

func set_time(new_time: float) -> void:
	target_time = new_time
