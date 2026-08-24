package main

import "core:math/rand"
import rl "vendor:raylib"

spawn_circle :: proc(world: ^World, position: rl.Vector2) {
	entity := entity_create(world)
	component_storage_add(
		&world.growing_circles,
		entity,
		Growing_Circle {
			death_date = rand.float32_range(3.0, 5.0),
			time_alive = 0,
			color = random_color(),
			grow = true,
		},
	)
	component_storage_add(&world.transforms, entity, Transform{position = position})
}

spawn_nav_cell :: proc(world: ^World, cell_position: Vector2i) {
	entity := entity_create(world)
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
		NavCell{cell_position = cell_position, walkable = true},
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

spawn_enemy :: proc(world: ^World, position: rl.Vector2) {
	entity := entity_create(world)
	component_storage_add(
		&world.transforms,
		entity,
		Transform{position = position, size = rl.Vector2{40, 40}},
	)
	component_storage_add(&world.enemies, entity, Enemy{move_speed = rand.float32_range(30, 90)})
	component_storage_add(&world.rectangles, entity, Rectangle{color = rl.WHITE})
}
