package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

/*
Constants
*/
MUSIC_BPM :: 80
SIZE_CELL :: 64
CELL_COUNT :: Vector2i{11, 11}

FONT_SIZE_TITLE :: 128
FONT_SIZE_BODY :: 48

GameState_Menu :: struct {}

GameState_Playing :: struct {}

GameState_Paused :: struct {}

GameState :: union {
	GameState_Menu,
	GameState_Playing,
	GameState_Paused,
}

Game :: struct {
	state:                 GameState,
	world:                 World,
	music:                 rl.Music,
	music_paused:          rl.Music,
	volume:                f32,
	font_title:            rl.Font,
	font_body:             rl.Font,
	shoot_origin:          rl.Vector2,
	navigator_spawn_timer: ElapsedTimer,
	nav_cells:             map[Vector2i]Entity_ID, // auxilary storage for easier access into navigation cells
	shader:                Shader,
}

game: Game
goal_position: Vector2i = 3

generate_flow_field :: proc(goal: Vector2i) {
	// max_distance_possible := lingalg.length(CELL_COUNT)

	// center_goal := goal + Vector2i{SIZE_CELL, SIZE_CELL} / 2
	center_goal := goal
	world := &game.world
	cells := [CELL_COUNT.x * CELL_COUNT.y]Entity_ID{}
	for entity, i in &world.nav_cells.entities {
		nav_cell := component_storage_get(&world.nav_cells, entity)
		cells[nav_cell.cell_position.x + nav_cell.cell_position.y * CELL_COUNT.x] = entity
	}

	for entity in cells {
		nav_cell := component_storage_get(&world.nav_cells, entity)
		if nav_cell.cell_position == goal {
			nav_cell.flow_vector = 0
			continue
		}
		towards_goal_float := [2]f32{0, 0}
		towards_goal_float.x = f32(center_goal.x) - f32(nav_cell.cell_position.x)
		towards_goal_float.y = f32(center_goal.y) - f32(nav_cell.cell_position.y)
		towards_goal_float = linalg.normalize(towards_goal_float)
		nav_cell.flow_vector.x = int(math.round(towards_goal_float.x))
		nav_cell.flow_vector.y = int(math.round(towards_goal_float.y))
	}
}

game_init :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})

	rl.InitWindow(
		i32(CELL_COUNT.x * SIZE_CELL),
		i32(CELL_COUNT.y * SIZE_CELL),
		"Tendrils of Time - Remake",
	)
	rl.InitAudioDevice()
	rl.SetExitKey(nil)

	game.volume = 0
	game.music = rl.LoadMusicStream("sound/song.wav")
	rl.PlayMusicStream(game.music)
	game.music_paused = rl.LoadMusicStream("sound/song_paused.wav")
	rl.PlayMusicStream(game.music_paused)
	rl.SetMasterVolume(0.4)

	game.font_title = rl.LoadFontEx("fonts/RubikScribble-Regular.ttf", FONT_SIZE_TITLE, nil, 0)
	game.font_body = rl.LoadFontEx("fonts/RubikScribble-Regular.ttf", FONT_SIZE_BODY, nil, 0)

	game.shader = load_shader(
		"obsidian.frag",
		{
			ShaderUniform{name = "uResolution", value = rl.Vector2{0, 0}},
			ShaderUniform{name = "uTime", value = 0.0},
		},
	)

	entity_world_init(&game.world)
	for x in 0 ..< CELL_COUNT.x {
		for y in 0 ..< CELL_COUNT.y {
			spawn_nav_cell(&game.world, Vector2i{x, y}, true)
		}
	}
	generate_flow_field(goal_position)

	game.state = GameState_Menu{}

	game.navigator_spawn_timer.interval_s = 1_000
	game.navigator_spawn_timer.playing = true
}

game_run :: proc() {
	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.UpdateMusicStream(game.music)
		rl.UpdateMusicStream(game.music_paused)
		rl.SetMusicVolume(game.music, game.volume)
		rl.SetMusicVolume(game.music_paused, 1 - game.volume)

		prev_goal_position := goal_position
		if rl.IsKeyPressed(.D) {
			goal_position.x += 1
		}
		if rl.IsKeyPressed(.A) {
			goal_position.x -= 1
		}
		if rl.IsKeyPressed(.S) {
			goal_position.y += 1
		}
		if rl.IsKeyPressed(.W) {
			goal_position.y -= 1
		}

		if prev_goal_position != goal_position {
			generate_flow_field(goal_position)
		}

		switch state in game.state {
		case GameState_Menu:
			game.volume = math.lerp(game.volume, 0.0, dt)
			update_menu(&game.world)
		case GameState_Playing:
			game.volume = math.lerp(game.volume, 1.0, dt)

			elapsed_timer_frame_tick(&game.navigator_spawn_timer, dt)

			update_nav_cells(&game.world, dt)
			update_growing_circles(&game.world, dt)
			update_shooting(&game.world, dt)
			update_paused(&game.world)
			update_bullets(&game.world, dt)
			update_navigators(&game.world, dt)
			update_pulsing_circles(&game.world, dt)

			if rl.IsKeyPressed(.ONE) {
				entities := make_dynamic_array([dynamic]Entity_ID, context.temp_allocator)
				// Turn all Growing_Circle components into Pulsing_Circle motherfuckers
				for entity in game.world.growing_circles.entities {
					growing_circle := component_storage_get(&game.world.growing_circles, entity)
					component_storage_add(
						&game.world.pulsing_circles,
						entity,
						Pulsing_Circle {
							from_radius = growing_circle.radius,
							to_radius = growing_circle.radius - 20,
							radius = growing_circle.radius,
							color = growing_circle.color,
						},
					)
					append(&entities, entity)
				}

				for entity in entities {
					component_storage_remove(&game.world.growing_circles, entity)
				}
			}

		case GameState_Paused:
			game.volume = math.lerp(game.volume, 0.0, dt)

			update_paused(&game.world)
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		switch state in game.state {
		case GameState_Menu:
			draw_menu(&game.world)
		case GameState_Playing:
			rl.BeginShaderMode(game.shader.rl_shader)

			window_width := rl.GetScreenWidth()
			window_height := rl.GetScreenHeight()
			update_uniform_value(
				&game.shader,
				"uResolution",
				rl.Vector2{f32(window_width), f32(window_height)},
			)
			update_uniform_value(&game.shader, "uTime", f32(rl.GetTime()))

			rl.DrawRectangle(0, 0, window_width, window_height, rl.WHITE)

			rl.EndShaderMode()

			debug_draw_nav_cells(&game.world)
			draw_circles(&game.world)
			draw_lines(&game.world)
			draw_shooting()
			draw_rectangles(&game.world)
			draw_navigators(&game.world)
		case GameState_Paused:
			draw_circles(&game.world)
			draw_lines(&game.world)
			draw_paused(&game.world)
		}

		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}

game_deinit :: proc() {
	entity_world_destroy(&game.world)

	rl.UnloadFont(game.font_body)
	rl.UnloadFont(game.font_title)
	rl.UnloadMusicStream(game.music)
	rl.UnloadMusicStream(game.music_paused)
}

random_color :: proc() -> rl.Color {
	r := u8(rand.int_range(100, 200))
	g := u8(rand.int_range(100, 200))
	b := u8(rand.int_range(100, 200))
	return rl.Color{r, g, b, 255}
}

center_cell :: proc(cell_position: Vector2i) -> rl.Vector2 {
	cell_position := linalg.array_cast(cell_position, f32)
	return (cell_position * SIZE_CELL) + {1, 1} * SIZE_CELL * 0.5
}
