# This script is based on the default CharacterBody2D template. Not much interesting happening here.
extends CharacterBody2D

const SPEED_MIN = 275.0
const SPEED_MAX = 700.0
const ACCEL = 300.0
const DECEL = 2000.0
##const DECEL_AIR = 100.0
const DECEL_TURN = 25.0
const JUMP_VELOCITY = -450.0
const MAX_FALL_SPEED = 900.0
const COYOTE_TIME: float = .1
const SHORT_HOP: float = .5
const WALLJUMP_SPEED = 400.0
const WALLJUMP_LENIENCY: float = .15

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var animation: String

var reset_position: Vector2
# Indicates that the player has an event happening and can't be controlled.
var event: bool

var abilities: Array[StringName]
var double_jump: bool
var prev_on_floor: bool
var airtime: float = 0
var speed: float = SPEED_MIN
var off_wall_time: float = 0 #airtime but for walls

func _ready() -> void:
	on_enter()

func _physics_process(delta: float) -> void:
	if event:
		return
	
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, MAX_FALL_SPEED)
		airtime += delta
	elif not prev_on_floor and &"double_jump" in abilities:
		# Some simple double jump implementation.
		double_jump = true
		airtime = 0
	
	if is_on_wall():
		speed = max(SPEED_MIN, speed - DECEL * delta)
		off_wall_time = 0
	else:
		off_wall_time += delta
	
	var on_floor_ct: bool = is_on_floor() or airtime < COYOTE_TIME
	if off_wall_time < WALLJUMP_LENIENCY:
		##on_floor_ct = true
		if velocity.x != 0 and velocity.x / abs(velocity.x) == get_wall_normal()[0]:
			on_floor_ct = true
	if Input.is_action_just_pressed("ui_accept") and (on_floor_ct or double_jump):
		if off_wall_time < WALLJUMP_LENIENCY and not is_on_floor():
			speed = max(speed, WALLJUMP_SPEED)
		if not on_floor_ct:
			double_jump = false
		
		if Input.is_action_pressed("ui_down"):
			position.y += 8
		else:
			velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_released("ui_accept"):
		if not is_on_floor() and velocity.y < 0:
			velocity.y = min(0, velocity.y - JUMP_VELOCITY * SHORT_HOP)
			
	if Input.is_action_just_released("ui_left") or Input.is_action_just_released("ui_right"):
		speed = max(SPEED_MIN, speed - DECEL_TURN)
		
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_action_pressed("ui_left") and Input.is_action_pressed("ui_right"):
		if velocity.x == 0:
			direction = 0
		else:
			if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
				direction = -1 * velocity.x / abs(velocity.x)
			else:
				direction = velocity.x / abs(velocity.x)
			speed = max(SPEED_MIN, speed - DECEL * delta)
			##if is_on_floor():
			##	speed = max(SPEED_MIN, speed - DECEL * delta)
			##else:
			##	speed = max(SPEED_MIN, speed - DECEL_AIR * delta)
	if direction:
		speed = min(SPEED_MAX, speed + ACCEL * delta)
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED_MIN)
		speed = max(SPEED_MIN, speed - DECEL * delta)

	prev_on_floor = is_on_floor()
	move_and_slide()
	
	var new_animation = &"Idle"
	if velocity.y < 0:
		new_animation = &"Jump"
	elif velocity.y >= 0 and not is_on_floor():
		new_animation = &"Fall"
	elif absf(velocity.x) > 1:
		new_animation = &"Run"
	
	if new_animation != animation:
		animation = new_animation
		$AnimationPlayer.play(new_animation)
	
	if velocity.x > 1:
		$Sprite2D.flip_h = false
	elif velocity.x < -1:
		$Sprite2D.flip_h = true
		

func kill():
	# Player dies, reset the position to the entrance.
	position = reset_position
	Game.get_singleton().load_room(MetSys.get_current_room_name())

func on_enter():
	# Position for kill system. Assigned when entering new room (see Game.gd).
	reset_position = position
