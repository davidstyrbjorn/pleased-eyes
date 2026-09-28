package main

import rl "vendor:raylib"

// Components & util procedures strictly tied to components

Transform :: struct {
	position: rl.Vector2,
	size:     rl.Vector2,
}

Growing_Circle :: struct {
	radius: f32,
	color:  rl.Color,
	grow:   bool,
}

Line :: struct {
	point_a, point_b: rl.Vector2,
	color:            rl.Color,
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

Navigator :: struct {
	target: ^NavCell,
}

NavCell :: struct {
	walkable:                 bool,
	cell_position:            Vector2i,
	flow_vector:              Vector2i, // direction towards the goal
	interpolated_flow_vector: rl.Vector2,
	cost:                     int, // graph walk cost
}
