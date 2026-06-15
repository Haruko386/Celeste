class_name PlayerTech
extends RefCounted

const DASH_ATTACK_TIME := 0.30

static func is_horizontal_dash(direction: Vector2) -> bool:
	return abs(direction.x) > 0.85 and abs(direction.y) < 0.35

static func is_down_diagonal_dash(direction: Vector2) -> bool:
	return abs(direction.x) > 0.55 and direction.y > 0.55

static func is_upward_dash(direction: Vector2) -> bool:
	return direction.y < -0.55

static func is_pure_up_dash(direction: Vector2) -> bool:
	return abs(direction.x) < 0.35 and direction.y < -0.85

static func axis_sign(value: float, fallback: int) -> int:
	if abs(value) > 0.01:
		return int(sign(value))
	return fallback
