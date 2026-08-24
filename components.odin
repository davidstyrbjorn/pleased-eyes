package main

import rl "vendor:raylib"

// Components & util procedures strictly tied to components

Transform :: struct {
	position: rl.Vector2,
	size:     rl.Vector2,
}

Growing_Circle :: struct {
	time_alive: f32,
	death_date: f32,
	color:      rl.Color,
	grow:       bool,
}

circle_get_t :: proc(circle: Growing_Circle) -> f32 {
	return min(1.0, circle.time_alive / circle.death_date)
}

Rectangle :: struct {
	color: rl.Color,
}

Bullet :: struct {
	direction: rl.Vector2,
	speed:     f32,
}

Sprite :: struct {
	name:        string,
	before_draw: proc(world: ^World, entity: Entity_ID),
	after_draw:  proc(world: ^World, entity: Entity_ID),
}

Enemy :: struct {
	move_speed: f32,
}

// Flow_Direction: Vector2i : enum {
// 	NORTH = Vector2i{0, -1},
// 	WEST = Vector2i{-1, 0},
// 	EAST = Vector2i{0, -1},
// 	SOUTH = Vector2i{1, 0},
// 	NORTH_WEST = V,
// 	NORTH_EAST,
// 	SOUTH_WEST,
// 	SOUTH_EAST,
// }

NavCell :: struct {
	walkable:      bool,
	cell_position: Vector2i,
	flow_vector:   Vector2i, // direction towards the goal
	cost:          int, // graph walk cost
}
