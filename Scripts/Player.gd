extends Node3D

@export var move_speed := 20.0
@export var rotation_speed := 1.5
@export var gravity := 20.0
@export var upward_acceleration := 50.0
@export var max_upward_speed := 15.0

@onready var camera = $Camera3D
@onready var drone = $drone

var vertical_velocity := 0.0
var yaw := 0.0
var pitch := 0.0
var pitch_limit := 0.6
var roll := 0.0
var roll_limit := 0.4
var roll_speed := 3.0

const drone_rot_offset := 90

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_mouse"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_input(delta)
		_update_camera()

func _handle_input(delta):
	# --- Handle Rotation ---
	if Input.is_action_pressed("move_left"):
		yaw += rotation_speed * delta
	if Input.is_action_pressed("move_right"):
		yaw -= rotation_speed * delta

	if Input.is_action_pressed("move_forward"):
		pitch = lerp(pitch, -pitch_limit, 2 * delta)
	elif Input.is_action_pressed("move_backward"):
		pitch = lerp(pitch, pitch_limit, 2 * delta)
	else:
		pitch = lerp(pitch, 0.0, delta)

	if Input.is_action_pressed("move_left"):
		roll = lerp(roll, -roll_limit, roll_speed * delta)
	elif Input.is_action_pressed("move_right"):
		roll = lerp(roll, roll_limit, roll_speed * delta)
	else:
		roll = lerp(roll, 0.0, roll_speed * delta)

	rotation.y = yaw
	drone.rotation = Vector3(roll, deg_to_rad(drone_rot_offset), pitch)

	# --- Movement ---
	var movement := Vector3.ZERO

	# Forward/backward only if pressing W/S
	var forward_dir = -transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	if Input.is_action_pressed("move_forward"):
		movement += forward_dir * move_speed
	elif Input.is_action_pressed("move_backward"):
		movement -= forward_dir * move_speed

	# Ascend (thrust up)
	if Input.is_action_pressed("move_up"):
		vertical_velocity += upward_acceleration * delta
	else:
		vertical_velocity -= gravity * delta

	vertical_velocity = clamp(vertical_velocity, -30.0, max_upward_speed)
	movement.y = vertical_velocity

	# Apply final movement
	global_translate(movement * delta)

func _update_camera() -> void:
	var back_offset := Vector3(0, 2.2, -3.2)
	camera.global_transform.origin = global_transform.origin - (transform.basis.z * back_offset.z) + (transform.basis.y * back_offset.y)
	camera.look_at(global_transform.origin + Vector3.UP * 1.7, Vector3.UP)
