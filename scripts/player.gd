extends CharacterBody2D

const Tech = preload("res://scripts/player_tech.gd")

@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -430.0
@export var gravity: float = 1200.0
@export var fall_gravity_multiplier: float = 1.35
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12

@export var max_dashes: int = 1
@export var dash_speed: float = 620.0
@export var dash_time: float = 0.15

@export var wall_slide_speed: float = 80.0
@export var wall_grab_fall_speed: float = 0.0
@export var wall_climb_speed: float = 95.0
@export var wall_climb_boost_speed: float = 620.0
@export var wall_climb_boost_time: float = 0.075
@export var wall_jump_horizontal_speed: float = 330.0
@export var wall_jump_vertical_speed: float = -430.0
@export var wall_stick_speed: float = 30.0

@export var wavedash_speed: float = 560.0
@export var wavedash_jump_velocity: float = -320.0
@export var superdash_speed: float = 540.0
@export var superdash_jump_velocity: float = -340.0
@export var wall_bounce_horizontal_speed: float = 440.0
@export var wall_bounce_vertical_speed: float = -660.0
@export var wall_bounce_check_distance: float = 12.0
@export var tech_momentum_time: float = 0.18

var spawn_position: Vector2
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_attack_timer: float = 0.0
var tech_momentum_timer: float = 0.0
var wall_climb_boost_timer: float = 0.0
var dashes: int = 1
var is_dashing: bool = false
var is_wall_grabbing: bool = false
var dash_started_on_floor: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var facing: int = 1

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	spawn_position = global_position
	refill_dash()

func _physics_process(delta: float) -> void:
	if global_position.y > 900.0:
		respawn()

	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_up", "move_down")
	if input_x != 0.0:
		facing = int(sign(input_x))

	var wall_dir := get_wall_dir()
	var touching_wall := wall_dir != 0 and not is_on_floor()
	var holding_grab := Input.is_action_pressed("grab")
	is_wall_grabbing = holding_grab and touching_wall

	update_timers(delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if try_consume_jump_tech(touching_wall, wall_dir):
		move_and_slide()
		update_visual()
		return

	if wall_climb_boost_timer > 0.0:
		update_wall_climb_boost(input_x, delta)
		move_and_slide()
		update_visual()
		return

	if is_dashing:
		update_dash(delta)
		move_and_slide()
		update_visual()
		return

	if Input.is_action_just_pressed("dash") and dashes > 0:
		start_dash()
		move_and_slide()
		update_visual()
		return

	if try_consume_standard_jump(touching_wall, wall_dir):
		move_and_slide()
		update_visual()
		return

	apply_horizontal_movement(input_x, delta)
	apply_vertical_movement(input_y, touching_wall, holding_grab, delta)

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	move_and_slide()
	update_visual()

func update_timers(delta: float) -> void:
	if is_on_floor() and not is_dashing:
		coyote_timer = coyote_time
		refill_dash()
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	dash_attack_timer = max(dash_attack_timer - delta, 0.0)
	tech_momentum_timer = max(tech_momentum_timer - delta, 0.0)
	wall_climb_boost_timer = max(wall_climb_boost_timer - delta, 0.0)

func update_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	if dash_timer <= 0.0:
		is_dashing = false
		velocity *= 0.72

func update_wall_climb_boost(input_x: float, delta: float) -> void:
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.y = -wall_climb_boost_speed

func try_consume_jump_tech(touching_wall: bool, wall_dir: int) -> bool:
	if jump_buffer_timer <= 0.0:
		return false

	if is_wall_grabbing and touching_wall:
		perform_wall_climb_jump()
		return true

	if dash_attack_timer <= 0.0:
		return false

	if Tech.is_down_diagonal_dash(dash_direction) and is_on_floor():
		perform_wavedash()
		return true

	if Tech.is_horizontal_dash(dash_direction) and dash_started_on_floor and is_on_floor():
		perform_superdash()
		return true

	if Tech.is_pure_up_dash(dash_direction):
		var near_wall_dir := get_near_wall_dir()
		if near_wall_dir != 0:
			perform_wall_bounce(near_wall_dir)
			return true

	return false

func try_consume_standard_jump(touching_wall: bool, wall_dir: int) -> bool:
	if jump_buffer_timer <= 0.0:
		return false

	if coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return true

	if touching_wall:
		velocity.x = -wall_dir * wall_jump_horizontal_speed
		velocity.y = wall_jump_vertical_speed
		facing = -wall_dir
		jump_buffer_timer = 0.0
		is_wall_grabbing = false
		return true

	return false

func perform_wall_climb_jump() -> void:
	velocity.x = 0.0
	velocity.y = -wall_climb_boost_speed
	wall_climb_boost_timer = wall_climb_boost_time
	jump_buffer_timer = 0.0
	is_wall_grabbing = false

func perform_wavedash() -> void:
	var dir: int = Tech.axis_sign(dash_direction.x, facing)
	velocity.x = dir * wavedash_speed
	velocity.y = wavedash_jump_velocity
	facing = dir
	refill_dash()
	is_dashing = false
	dash_attack_timer = 0.0
	tech_momentum_timer = tech_momentum_time
	jump_buffer_timer = 0.0

func perform_superdash() -> void:
	var dir: int = Tech.axis_sign(dash_direction.x, facing)
	velocity.x = dir * superdash_speed
	velocity.y = superdash_jump_velocity
	facing = dir
	refill_dash()
	is_dashing = false
	dash_attack_timer = 0.0
	tech_momentum_timer = tech_momentum_time
	jump_buffer_timer = 0.0

func perform_wall_bounce(near_wall_dir: int) -> void:
	var dir := -near_wall_dir
	velocity.x = dir * wall_bounce_horizontal_speed
	velocity.y = wall_bounce_vertical_speed
	facing = dir
	is_dashing = false
	dash_attack_timer = 0.0
	tech_momentum_timer = tech_momentum_time
	jump_buffer_timer = 0.0

func apply_horizontal_movement(input_x: float, delta: float) -> void:
	if is_wall_grabbing:
		velocity.x = wall_stick_speed * get_wall_dir()
		return

	if tech_momentum_timer > 0.0 and sign(velocity.x) != 0.0:
		if input_x == 0.0 or sign(input_x) == sign(velocity.x):
			return

	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

func apply_vertical_movement(
	input_y: float,
	touching_wall: bool,
	holding_grab: bool,
	delta: float
) -> void:
	if is_wall_grabbing:
		if input_y < 0.0:
			velocity.y = -wall_climb_speed
		elif input_y > 0.0:
			velocity.y = wall_climb_speed
		else:
			velocity.y = wall_grab_fall_speed
		return

	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_multiplier
	velocity.y += g * delta

	if touching_wall and velocity.y > wall_slide_speed and not holding_grab:
		velocity.y = wall_slide_speed

func start_dash() -> void:
	dashes = max(dashes - 1, 0)
	is_dashing = true
	is_wall_grabbing = false
	dash_started_on_floor = is_on_floor()
	dash_timer = dash_time
	dash_attack_timer = Tech.DASH_ATTACK_TIME

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)

	dash_direction = dir.normalized()
	if dash_direction.x != 0.0:
		facing = int(sign(dash_direction.x))
	velocity = dash_direction * dash_speed

func refill_dash() -> bool:
	if dashes < max_dashes:
		dashes = max_dashes
		return true
	return false

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_dashing = false
	is_wall_grabbing = false
	dash_attack_timer = 0.0
	tech_momentum_timer = 0.0
	wall_climb_boost_timer = 0.0
	refill_dash()

func update_visual() -> void:
	sprite.flip_h = facing < 0
	if is_wall_grabbing:
		sprite.modulate = Color(0.98, 0.55, 0.35, 1)
	elif dashes == 0:
		sprite.modulate = Color(0.266, 0.718, 1.0, 1)
	elif tech_momentum_timer > 0.0 or wall_climb_boost_timer > 0.0:
		sprite.modulate = Color(1.0, 0.85, 0.35, 1)
	else:
		sprite.modulate = Color(0.95, 0.25, 0.35, 1)

func get_wall_dir() -> int:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if abs(normal.x) > 0.7:
			return int(-sign(normal.x))
	return 0

func get_near_wall_dir() -> int:
	if test_move(global_transform, Vector2(wall_bounce_check_distance, 0.0)):
		return 1
	if test_move(global_transform, Vector2(-wall_bounce_check_distance, 0.0)):
		return -1
	return 0
