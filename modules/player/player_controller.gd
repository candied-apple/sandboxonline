extends CharacterBody3D

const SPEED = 5.0
const FLY_SPEED = 15.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

# Flight variables
var can_fly_ability: bool = false
var is_flying: bool = false
var last_jump_time: int = 0
const DOUBLE_JUMP_THRESHOLD_MS = 300

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D
# We assume a Label3D named "NameLabel" exists in the scene
@onready var name_label: Label3D = $NameLabel

var is_puppet: bool = false
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
const LERP_SPEED = 10.0 # Adjust for smoothness vs responsiveness

var _username: String = ""

func set_username(username: String) -> void:
	_username = username
	if name_label:
		name_label.text = username

func setup_puppet() -> void:
	is_puppet = true
	set_process_input(false)
	set_process_unhandled_input(false)
	# set_physics_process(false) # REMOVED: We need physics process for smoothing
	$Camera3D.current = false
	$CollisionShape3D.disabled = true
	target_position = position # Initialize to avoid jumping

func update_puppet_state(pos: Vector3, rot: Vector3) -> void:
	target_position = pos
	target_rotation = rot

func setup_local() -> void:
	is_puppet = false
	set_input_enabled(true)
	$Camera3D.current = true
	if name_label:
		name_label.visible = false

func set_input_enabled(enabled: bool) -> void:
	set_process_input(enabled)
	set_process_unhandled_input(enabled)
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if name_label:
		name_label.text = _username
	pass # Wait for setup_local() or setup_puppet()

func _input(event: InputEvent) -> void:
	if is_puppet: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_puppet:
		# Interpolate position and rotation
		position = position.lerp(target_position, delta * LERP_SPEED)
		rotation.x = lerp_angle(rotation.x, target_rotation.x, delta * LERP_SPEED)
		rotation.y = lerp_angle(rotation.y, target_rotation.y, delta * LERP_SPEED)
		rotation.z = lerp_angle(rotation.z, target_rotation.z, delta * LERP_SPEED)
		return

	# Handle Fly Toggle (Double Jump)
	if Input.is_action_just_pressed("jump"):
		var current_time = Time.get_ticks_msec()
		if can_fly_ability and (current_time - last_jump_time) < DOUBLE_JUMP_THRESHOLD_MS:
			is_flying = !is_flying
			if is_flying:
				velocity = Vector3.ZERO
		last_jump_time = current_time

	if is_flying:
		handle_fly_movement(delta)
	else:
		handle_ground_movement(delta)

func handle_fly_movement(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var vertical_dir = 0.0
	if Input.is_action_pressed("jump"):
		vertical_dir += 1.0
	if Input.is_key_pressed(KEY_SHIFT): # Hardcoded shift for now
		vertical_dir -= 1.0
		
	if direction:
		velocity.x = direction.x * FLY_SPEED
		velocity.z = direction.z * FLY_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, FLY_SPEED)
		velocity.z = move_toward(velocity.z, 0, FLY_SPEED)
		
	velocity.y = vertical_dir * FLY_SPEED
	move_and_slide()

func handle_ground_movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
