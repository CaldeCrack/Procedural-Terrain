extends Node3D

@export var move_speed := 20.0
@export var mouse_sensitivity := 0.002

@onready var camera = $Camera3D

var velocity := Vector3.ZERO
var input_direction := Vector3.ZERO
var rotation_y := 0.0  # Yaw
var rotation_x := 0.0  # Pitch

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Rotate player horizontally
		rotation_y -= event.relative.x * mouse_sensitivity

		# Rotate camera vertically
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))
		rotation.y = rotation_y
		camera.rotation.x = rotation_x

func _process(delta):
	_handle_input()
	_move(delta)

func _handle_input():
	input_direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_direction += Vector3.FORWARD
	if Input.is_action_pressed("move_backward"):
		input_direction -= Vector3.FORWARD
	if Input.is_action_pressed("move_left"):
		input_direction -= Vector3.RIGHT
	if Input.is_action_pressed("move_right"):
		input_direction += Vector3.RIGHT
	if Input.is_action_pressed("move_up"):
		input_direction += Vector3.UP
	if Input.is_action_pressed("move_down"):
		input_direction -= Vector3.UP
	if Input.is_action_just_pressed("accelerate"):
		move_speed *= 3
	elif Input.is_action_just_released("accelerate"):
		move_speed /= 3

	input_direction = input_direction.normalized()

func _move(delta):
	if input_direction == Vector3.ZERO:
		return

	# Transform input_direction relative to the camera
	var direction = global_transform.basis * input_direction
	global_translate(direction * move_speed * delta)
