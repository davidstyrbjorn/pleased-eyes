package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

MAX_MOVE_SPEED :: 90

update_shooting :: proc(world: ^World, dt: f32) {
	if rl.IsMouseButtonPressed(.LEFT) {
		// mark 'start'
		game.shoot_origin = rl.GetMousePosition()
	}

	if rl.IsMouseButtonReleased(.LEFT) {
		// shoot bitch
		dir := rl.GetMousePosition() - game.shoot_origin
		speed := min(MAX_MOVE_SPEED, rl.Vector2Length(dir))
		spawn_bullet(
			world,
			game.shoot_origin - 10,
			rl.GetMousePosition() - game.shoot_origin,
			speed,
		)
	}
}

update_navigators :: proc(world: ^World, dt: f32) {
	if elapsed_timer_triggered(&game.navigator_spawn_timer) {
		// Pick a random border cell
		num := rand.int_range(0, 4)
		spawn_position: Vector2i = 0
		if num == 0 {
			spawn_position.x = 0
			spawn_position.y = rand.int_range(0, CELL_COUNT.y)
		}
		if num == 1 {
			spawn_position.x = CELL_COUNT.x - 1
			spawn_position.y = rand.int_range(0, CELL_COUNT.y)
		}
		if num == 2 {
			spawn_position.x = rand.int_range(0, CELL_COUNT.x)
			spawn_position.y = 0
		}
		if num == 3 {
			spawn_position.x = rand.int_range(0, CELL_COUNT.x)
			spawn_position.y = CELL_COUNT.y - 1
		}
		spawn_navigator(world, spawn_position)
	}

	move_speed :: 100
	entities_to_remove := make([dynamic]Entity_ID, context.temp_allocator)
	for entity in world.navigators.entities {
		navigator := component_storage_get(&world.navigators, entity)
		transform := component_storage_get(&world.transforms, entity)
		if navigator.target == nil {
			// Find target
			// Convert out world position to a cell_position
			cell_position: Vector2i = {
				int(transform.position.x / SIZE_CELL),
				int(transform.position.y / SIZE_CELL),
			}

			nav_cell_entity := game.nav_cells[cell_position]
			nav_cell := component_storage_get(&world.nav_cells, nav_cell_entity)
			navigator.target = nav_cell
		} else {
			if rl.Vector2Distance(
				   transform.position,
				   center_cell(navigator.target.cell_position),
			   ) <
			   0.1 {
				// Did we reach our target and is it equal to the goal position
				if navigator.target.cell_position == goal_position {
					append(&entities_to_remove, entity)
				} else {
					// Time to pick a new thing to move towards
					new_cell := navigator.target.cell_position + navigator.target.flow_vector
					new_target := game.nav_cells[new_cell]
					if component_storage_has(&world.nav_cells, new_target) {
						navigator.target = component_storage_get(&world.nav_cells, new_target)
					}
				}
			} else {
				dir := linalg.normalize(
					center_cell(navigator.target.cell_position) - transform.position,
				)
				transform.position += dir * move_speed * dt
			}
		}
	}

	for entity in entities_to_remove {
		entity_destroy(world, entity)
	}

}

draw_shooting :: proc() {
	if rl.IsMouseButtonDown(.LEFT) {
		// if mouse is down, draw line from 'start' to mouse position (limited length)
		dir := rl.GetMousePosition() - game.shoot_origin
		line := rl.Vector2Normalize(dir) * min(MAX_MOVE_SPEED, rl.Vector2Length(dir))
		rl.DrawLineV(game.shoot_origin, game.shoot_origin + line, rl.RED)
	}
}

draw_navigators :: proc(world: ^World) {
	for entity in world.navigators.entities {
		transform := component_storage_get(&world.transforms, entity)
		rl.DrawCircleV(transform.position, transform.size.x, rl.PURPLE)
	}
}

Circle_Grow_System :: struct {
	grow: bool,
}

circle_grow: Circle_Grow_System = {
	grow = false,
}

update_growing_circles :: proc(world: ^World, dt: f32) {
	if rl.IsMouseButtonPressed(.RIGHT) {
		mouse_pos := rl.GetMousePosition()
		// Snap to the center of a cell
		cell_position: Vector2i = {int(mouse_pos.x / SIZE_CELL), int(mouse_pos.y / SIZE_CELL)}
		spawn_position := center_cell(cell_position)
		spawn_circle(world, spawn_position)
	}

	if rl.IsKeyPressed(.SPACE) {
		circle_grow.grow = !circle_grow.grow
	}

	if !circle_grow.grow {
		return
	}

	grow_speed :: 50

	for entity in world.growing_circles.entities {
		circle := component_storage_get(&world.growing_circles, entity)
		if circle.grow {
			circle.radius += dt * grow_speed
		}

		collided_with := make([dynamic]Entity_ID, context.temp_allocator)

		for entity2 in world.growing_circles.entities {
			if entity == entity2 {
				continue
			}
			circle2 := component_storage_get(&world.growing_circles, entity2)
			transform := component_storage_get(&world.transforms, entity)
			transform2 := component_storage_get(&world.transforms, entity2)

			delta := transform2.position - transform.position
			delta_squared := math.pow(delta.x, 2) + math.pow(delta.y, 2)
			radii_sum := circle.radius + circle2.radius
			if delta_squared <= math.pow(radii_sum, 2) && circle.grow {
				append(&collided_with, entity2)
			}
		}

		for entity2 in collided_with {
			transform := component_storage_get(&world.transforms, entity)
			transform2 := component_storage_get(&world.transforms, entity2)

			circle.grow = false

			// Collision point is what?
			collision_point :=
				transform.position +
				rl.Vector2Normalize(transform2.position - transform.position) * circle.radius

			// we want to grab the tangent of this point on the circle
			a := transform.position
			b := transform2.position
			a_to_b := a - b
			c: rl.Vector2
			c.x = -a_to_b.y
			c.y = a_to_b.x
			c = rl.Vector2Normalize(c)
			spawn_line(world, collision_point + c * 100, collision_point - c * 100)
		}
	}
}

update_bullets :: proc(world: ^World, dt: f32) {
	for entity in world.bullets.entities {
		bullet := component_storage_get(&world.bullets, entity)
		transform := component_storage_get(&world.transforms, entity)
		rect := component_storage_get(&world.rectangles, entity)
		transform.position += rl.Vector2Normalize(bullet.direction) * dt * bullet.speed

		// if transform.position.x < 0 || transform.position.x + transform.size.x > WINDOW_WIDTH {
		// 	bullet.direction.x *= -1
		// }
		// if transform.position.y < 0 || transform.position.y + transform.size.y > WINDOW_HEIGHT {
		// 	bullet.direction.y *= -1
		// }
	}
}

update_menu :: proc(world: ^World) {
	if rl.IsKeyPressed(.SPACE) {
		game.state = GameState_Playing{}
	}
}

update_paused :: proc(world: ^World) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.P) {
		switch state in game.state {
		case GameState_Menu:
			assert(false)
		case GameState_Playing:
			game.state = GameState_Paused{}
		case GameState_Paused:
			game.state = GameState_Playing{}
		}
	}
}

draw_rectangles :: proc(world: ^World) {
	for entity in world.rectangles.entities {
		transform := component_storage_get(&world.transforms, entity)
		rectangle := component_storage_get(&world.rectangles, entity)
		rl.DrawRectangleV(transform.position, transform.size, rectangle.color)
	}
}

update_nav_cells :: proc(world: ^World, dt: f32) {
	for entity in world.nav_cells.entities {
		nav_cell := component_storage_get(&world.nav_cells, entity)
		goal := [2]f32{f32(nav_cell.flow_vector.x), f32(nav_cell.flow_vector.y)}

		nav_cell.interpolated_flow_vector = linalg.lerp(
			nav_cell.interpolated_flow_vector,
			goal,
			dt * 5,
		)
	}
}

pulsing_t: f32 = 0
update_pulsing_circles :: proc(world: ^World, dt: f32) {
	if len(world.pulsing_circles.entities) == 0 {
		return
	}

	pulsing_t += dt

	for entity in world.pulsing_circles.entities {
		pulsing_circle := component_storage_get(&world.pulsing_circles, entity)
		diff := pulsing_circle.to_radius - pulsing_circle.from_radius
		h := (math.sin_f32(pulsing_t - math.PI / 2.0) + 1) / 2.0
		pulsing_circle.radius = pulsing_circle.from_radius + diff * h
	}
}

debug_draw_nav_cells :: proc(world: ^World) {
	for entity in world.nav_cells.entities {
		transform := component_storage_get(&world.transforms, entity)
		nav_cell := component_storage_get(&world.nav_cells, entity)
		// rl.DrawRectangleLines(
		// 	c.int(transform.position.x),
		// 	c.int(transform.position.y),
		// 	c.int(transform.size.x),
		// 	c.int(transform.size.y),
		// 	rl.Color{50, 50, 200, 100},
		// )

		center_cell := transform.position + transform.size / 2.0
		// rl.DrawCircleV(center_cell, 5, rl.PURPLE)

		cell_center := transform.position + transform.size / 2.0
		cell_corner :=
			cell_center +
			((cast([2]f32)nav_cell.interpolated_flow_vector * transform.size * 0.5) / 1.0)
		rl.DrawLineV(cell_center, cell_corner, rl.RED)

	}
}

draw_menu :: proc(world: ^World) {
	do_text_center("Tender", 100, FONT_SIZE_TITLE, rl.WHITE, game.font_title)
	do_text_center("Press [SPACE] to begin", 250, FONT_SIZE_BODY, rl.WHITE, game.font_body)
}

draw_paused :: proc(world: ^World) {
	do_text_center("Paused", 100, FONT_SIZE_TITLE, rl.WHITE, game.font_title)
	do_text_center("Press [ESCAPE] to return", 250, FONT_SIZE_BODY, rl.WHITE, game.font_body)
}

draw_lines :: proc(world: ^World) {
	for entity in world.lines.entities {
		line := component_storage_get(&world.lines, entity)
		when ODIN_DEBUG {
			assert(line != nil)
		}

		rl.DrawLineDashed(line.point_a, line.point_b, 2, 5, rl.SKYBLUE)
	}
}

draw_circles :: proc(world: ^World) {
	for entity in world.growing_circles.entities {
		transform := component_storage_get(&world.transforms, entity)
		circle := component_storage_get(&world.growing_circles, entity)
		when ODIN_DEBUG {
			assert(transform != nil && circle != nil)
		}

		r := abs(circle.radius)
		rl.DrawCircleLinesV(transform.position, r, circle.color)
	}

	for entity in world.pulsing_circles.entities {
		transform := component_storage_get(&world.transforms, entity)
		circle := component_storage_get(&world.pulsing_circles, entity)
		when ODIN_DEBUG {
			assert(transform != nil && circle != nil)
		}

		rl.DrawCircleLinesV(transform.position, circle.radius, circle.color)
	}
}
