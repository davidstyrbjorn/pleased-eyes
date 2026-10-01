package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

spawn_circle :: proc(world: ^World, position: rl.Vector2, grow := true, radius: f32 = -10) {
	entity := entity_create(world)
	component_storage_add(
		&world.growing_circles,
		entity,
		Growing_Circle{color = random_color(), grow = grow, radius = radius},
	)
	component_storage_add(&world.transforms, entity, Transform{position = position})
}

spawn_nav_cell :: proc(world: ^World, cell_position: Vector2i, walkable: bool) {
	entity := entity_create(world)
	game.nav_cells[cell_position] = entity
	component_storage_add(
		&world.transforms,
		entity,
		Transform {
			position = rl.Vector2{f32(cell_position.x), f32(cell_position.y)} * SIZE_CELL,
			size = rl.Vector2{1, 1} * SIZE_CELL,
		},
	)

	component_storage_add(
		&world.nav_cells,
		entity,
		NavCell {
			cell_position = cell_position,
			walkable = walkable,
			interpolated_flow_vector = 0,
			flow_vector = 0,
		},
	)
}

spawn_navigator :: proc(world: ^World, starting_cell_position: Vector2i) {
	entity := entity_create(world)
	t := component_storage_add(
		&world.transforms,
		entity,
		Transform{position = center_cell(starting_cell_position), size = 16},
	)
	component_storage_add(&world.navigators, entity, Navigator{target = nil})
}

spawn_line :: proc(world: ^World, a: rl.Vector2, b: rl.Vector2) {
	entity := entity_create(world)
	component_storage_add(
		&world.lines,
		entity,
		Line{color = random_color(), point_a = a, point_b = b},
	)
}

spawn_bullet :: proc(world: ^World, position: rl.Vector2, direction: rl.Vector2, speed: f32) {
	entity := entity_create(world)
	component_storage_add(
		&world.transforms,
		entity,
		Transform{position = position, size = rl.Vector2{20, 20}},
	)
	component_storage_add(&world.bullets, entity, Bullet{direction = direction, speed = speed})
	component_storage_add(&world.rectangles, entity, Rectangle{color = rl.RED})
}

random_enemy_behaviour :: proc() -> Enemy_Behaviour {
	num := rand.float32_range(0, 4)
	if num == 0 {
		return Enemy_Behaviour_Turret{}
	} else if num == 1 {
		return Enemy_Behaviour_Straight{}
	} else if num == 2 {
		return Enemy_Behaviour_Glitch{}
	} else if num == 3 {
		return Enemy_Behaviour_Zombie{}
	}

	return Enemy_Behaviour_Turret{}
}

spawn_enemy :: proc(world: ^World, position: rl.Vector2) {
	entity := entity_create(world)
	component_storage_add(
		&world.transforms,
		entity,
		Transform{position = position, size = rl.Vector2{40, 40}},
	)
	component_storage_add(&world.enemies, entity, Enemy{behaviour = random_enemy_behaviour()})
	component_storage_add(&world.rectangles, entity, Rectangle{color = rl.WHITE})
}
