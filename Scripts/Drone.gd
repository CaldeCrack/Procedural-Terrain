extends Node3D

@export var base_spin_speed := 30.0
@export var active_spin_speed := 60.0
@export var acceleration := 10.0

@export var base_pitch := 0.8
@export var max_pitch := 1.4

@onready var propeller_1: MeshInstance3D = $Propeller1
@onready var propeller_2: MeshInstance3D = $Propeller2
@onready var propeller_3: MeshInstance3D = $Propeller3
@onready var propeller_4: MeshInstance3D = $Propeller4
@onready var drone_sound := $Noise

var current_spin_speed := 0.0

func _ready():
	drone_sound.play()
	current_spin_speed = base_spin_speed

func _process(delta):
	# Check if forward/backward is being pressed
	var target_speed = base_spin_speed
	if Input.is_action_pressed("move_up"):
		target_speed = active_spin_speed

	# Smoothly interpolate current speed toward target
	current_spin_speed = lerp(current_spin_speed, target_speed, acceleration * delta)

	# Rotate propellers
	var rotation_amount = current_spin_speed * delta
	propeller_1.rotate_y(rotation_amount)   # CCW
	propeller_2.rotate_y(-rotation_amount)  # CW
	propeller_3.rotate_y(-rotation_amount)  # CW
	propeller_4.rotate_y(rotation_amount)   # CCW

	var t := inverse_lerp(base_spin_speed, active_spin_speed, current_spin_speed)
	drone_sound.pitch_scale = lerp(base_pitch, max_pitch, t)
