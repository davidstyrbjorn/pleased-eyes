package main

import "core:c"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

RADIUS :: 100
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

	if rl.IsMouseButtonPressed(.RIGHT) {
		// shoot in 4 directions X shaped
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

update_enemies :: proc(world: ^World, dt: f32) {
	to_destroy: [dynamic]Entity_ID

	for entity in world.enemies.entities {
		transform := component_storage_get(&world.transforms, entity)
		enemy := component_storage_get(&world.enemies, entity)
		transform.position.x += enemy.move_speed * dt

		for entity2 in world.bullets.entities {
			transform2 := component_storage_get(&world.transforms, entity2)
			if check_rect_collision(transform, transform2) {
				append(&to_destroy, entity)
				append(&to_destroy, entity2)
				break
			}
		}
	}

	for entity in to_destroy {
		entity_destroy(world, entity)
	}

	if elapsed_timer_triggered(&game.enemy_spawn_timer) {
		offset := rand.float32_range(-100, 100)
		spawn_enemy(world, {20, WINDOW_HEIGHT / 2.0 + offset})
	}
}


update_growing_circles :: proc(world: ^World, dt: f32) {
	for entity in world.growing_circles.entities {
		circle := component_storage_get(&world.growing_circles, entity)
		if circle.grow {
			circle.time_alive += dt
		}

		for entity2 in world.growing_circles.entities {
			if entity == entity2 {
				continue
			}
			circle2 := component_storage_get(&world.growing_circles, entity2)
			transform := component_storage_get(&world.transforms, entity)
			transform2 := component_storage_get(&world.transforms, entity2)

			r := RADIUS * circle_get_t(circle^)
			r2 := RADIUS * circle_get_t(circle2^)
			delta := transform2.position - transform.position
			delta_squared := math.pow(delta.x, 2) + math.pow(delta.y, 2)
			radii_sum := r + r2
			if delta_squared <= math.pow(radii_sum, 2) {
				circle.grow = false
			}
		}
	}

	// if rl.IsMouseButtonPressed(.LEFT) {
	// 	mouse_pos := rl.GetMousePosition()
	// 	spawn_circle(&game.world, mouse_pos)
	// }
}

update_bullets :: proc(world: ^World, dt: f32) {
	for entity in world.bullets.entities {
		bullet := component_storage_get(&world.bullets, entity)
		transform := component_storage_get(&world.transforms, entity)
		transform.position += rl.Vector2Normalize(bullet.direction) * dt * bullet.speed
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

debug_draw_nav_cells :: proc(world: ^World) {
	for entity in world.nav_cells.entities {
		transform := component_storage_get(&world.transforms, entity)
		rl.DrawRectangleLines(
			c.int(transform.position.x),
			c.int(transform.position.y),
			c.int(transform.size.x),
			c.int(transform.size.y),
			rl.Color{50, 50, 200, 100},
		)
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

draw_circles :: proc(world: ^World) {
	for entity in world.growing_circles.entities {
		transform := component_storage_get(&world.transforms, entity)
		circle := component_storage_get(&world.growing_circles, entity)
		when ODIN_DEBUG {
			assert(transform != nil && circle != nil)
		}

		r := RADIUS * circle_get_t(circle^)
		rl.DrawCircleLinesV(transform.position, r, circle.color)
	}
}
