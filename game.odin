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
CELL_COUNT :: Vector2i{19, 19}

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
	state:                           GameState,
	world:                           World,
	font_title:                      rl.Font,
	font_body:                       rl.Font,
	shoot_origin:                    rl.Vector2,
	navigator_spawn_timer:           ElapsedTimer,
	nav_cells:                       map[Vector2i]Entity_ID, // auxilary storage for easier access into navigation cells
	shader:                          Shader,
	flow_field:                      Flow_Field,
	player_turns:                    f32, // 1 turn = 2 PI
	defense_circle_radius:           f32,
	music_player:                    Music_Player,
	music_main_id, music_subdued_id: int,
	splash_image:                    rl.Texture,
	splash_timeline:                 Timelines,
	splash_a:                        f32,
	menu_a:                          f32,
}

// Store some auxiliary data about the flow field
Flow_Field :: struct {
	goal: Vector2i,
}

game: Game

get_player_position :: proc() -> rl.Vector2 {
	player_pos: rl.Vector2 = window_size() / 2.0
	theta := 2 * math.PI * game.player_turns
	player_pos.x += math.cos_f32(theta) * game.defense_circle_radius
	player_pos.y += math.sin_f32(theta) * game.defense_circle_radius
	return player_pos
}

generate_flow_field :: proc() {
	// max_distance_possible := lingalg.length(CELL_COUNT)

	// center_goal := goal + Vector2i{SIZE_CELL, SIZE_CELL} / 2
	goal := game.flow_field.goal
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
		towards_goal_float.x = f32(goal.x) - f32(nav_cell.cell_position.x)
		towards_goal_float.y = f32(goal.y) - f32(nav_cell.cell_position.y)
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
	rl.SetTargetFPS(144)

	game.font_title = rl.LoadFontEx("fonts/RubikScribble-Regular.ttf", FONT_SIZE_TITLE, nil, 0)
	game.font_body = rl.LoadFontEx("fonts/RubikScribble-Regular.ttf", FONT_SIZE_BODY, nil, 0)

	game.shader = load_shader(
		"shaders/toxic.frag",
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
	#assert(CELL_COUNT.x % 2 == 1 && CELL_COUNT.y % 2 == 1) // We want an uneven number of cells to have a true center cell
	game.flow_field.goal = {CELL_COUNT.x / 2, CELL_COUNT.y / 2}
	generate_flow_field()

	game.state = GameState_Menu{}

	game.navigator_spawn_timer.interval_s = 1
	game.navigator_spawn_timer.playing = true

	game.player_turns = 0
	game.defense_circle_radius = SIZE_CELL * 4

	game.music_main_id = music_player_add(&game.music_player, "sound/game.mp3")
	game.music_subdued_id = music_player_add(&game.music_player, "sound/game_subdued.mp3")
	music_player_init(&game.music_player, 0.0)
	music_player_set_current(&game.music_player, game.music_subdued_id)

	game.splash_image = rl.LoadTexture("images/danger.png")

	timelines_add(
		&game.splash_timeline,
		Timeline{duration = 2, from = 0.0, to = 255, v = &game.splash_a},
	)
	timelines_add(
		&game.splash_timeline,
		Timeline{duration = 2, from = 0.0, to = 0.6, v = &game.music_player.master_volume},
	)
	timelines_add(
		&game.splash_timeline,
		Timeline{duration = 2, from = 255, to = 255, v = &game.splash_a},
	)
	timelines_add(
		&game.splash_timeline,
		Timeline{duration = 2, from = 255, to = 0, v = &game.splash_a},
	)
	timelines_add(
		&game.splash_timeline,
		Timeline{duration = 2, from = 0, to = 255, v = &game.menu_a},
	)
}

dump_draw_instructions_all_circles_and_lines :: proc() {
	b := strings.builder_make()
	for entity in game.world.growing_circles.entities {
		transform := component_storage_get(&game.world.transforms, entity)
		circle := component_storage_get(&game.world.growing_circles, entity)
		strings.write_string(
			&b,
			fmt.tprintf(
				"rl.DrawCircleV({{%v, %v}}, %v, {{%v, %v, %v, %v}})\n",
				transform.position.x,
				transform.position.y,
				circle.radius,
				circle.color.r,
				circle.color.g,
				circle.color.b,
				circle.color.a,
			),
		)
	}

	for entity in game.world.lines.entities {
		line := component_storage_get(&game.world.lines, entity)
		strings.write_string(
			&b,
			fmt.tprintf(
				"rl.DrawLineDashed({{%v, %v}}, {{%v, %v}}, 2, 5, {{%v, %v, %v, %v}})\n",
				line.point_a.x,
				line.point_a.y,
				line.point_b.x,
				line.point_b.y,
				line.color.r,
				line.color.g,
				line.color.b,
				line.color.a,
			),
		)
	}

	str := strings.to_string(b)
	fmt.println(str)
}

game_should_run :: proc() -> bool {
	return !rl.WindowShouldClose()
}

game_run :: proc() {
	dt := rl.GetFrameTime()

	music_player_update(&game.music_player, dt)
	timelines_play(&game.splash_timeline, dt)
	fmt.printf("menu_a = %v\n", game.menu_a)

	switch state in game.state {
	case GameState_Menu:
		update_menu(&game.world)
	case GameState_Playing:
		elapsed_timer_frame_tick(&game.navigator_spawn_timer, dt)

		update_nav_cells(&game.world, dt)
		update_growing_circles(&game.world, dt)
		update_shooting(&game.world, dt)
		update_paused(&game.world)
		update_bullets(&game.world, dt)
		update_navigators(&game.world, dt)
		update_pulsing_circles(&game.world, dt)

		if rl.IsKeyDown(.D) {
			game.player_turns += 0.2 * dt
		} else if rl.IsKeyDown(.A) {
			game.player_turns -= 0.2 * dt
		}

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
		if rl.IsKeyPressed(.THREE) {
			dump_draw_instructions_all_circles_and_lines()
		}

	case GameState_Paused:
		update_paused(&game.world)
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	switch state in game.state {
	case GameState_Menu:
		draw_menu(&game.world, game.menu_a)
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
		// draw_circles(&game.world)
		// draw_lines(&game.world)
		draw_rectangles(&game.world)
		draw_navigators(&game.world)

		rl.DrawCircleLinesV(window_size() / 2.0, game.defense_circle_radius, rl.YELLOW)
		player_pos := get_player_position()
		rl.DrawCircleV(player_pos, 10, rl.YELLOW)

		rl.DrawCircleV({608, 608}, 32.385418, {113, 150, 106, 255})
		rl.DrawCircleV({608, 736}, 45.579853, {132, 131, 186, 255})
		rl.DrawCircleV({608, 544}, 32.108406, {128, 122, 194, 255})
		rl.DrawCircleV({480, 608}, 45.579853, {164, 165, 195, 255})
		rl.DrawCircleV({736, 608}, 45.579853, {180, 149, 112, 255})
		rl.DrawCircleV({544, 672}, 45.283447, {174, 103, 161, 255})
		rl.DrawCircleV({672, 672}, 45.283447, {161, 142, 156, 255})
		rl.DrawCircleV({544, 480}, 58.466766, {142, 196, 116, 255})
		rl.DrawCircleV({672, 480}, 58.466766, {182, 156, 177, 255})
		rl.DrawLineDashed({708, 576.1084}, {508, 576.1084}, 2, 5, {110, 195, 114, 255})
		rl.DrawLineDashed({508, 575.61456}, {708, 575.61456}, 2, 5, {143, 157, 143, 255})
		rl.DrawLineDashed(
			{646.73096, 633.3096},
			{505.30957, 774.73096},
			2,
			5,
			{103, 122, 109, 255},
		)
		rl.DrawLineDashed({441.2691, 710.6904}, {582.6904, 569.26904}, 2, 5, {144, 164, 104, 255})
		rl.DrawLineDashed({710.6904, 774.73096}, {569.26904, 633.3096}, 2, 5, {106, 100, 102, 255})
		rl.DrawLineDashed({633.3096, 569.26904}, {774.73096, 710.6904}, 2, 5, {172, 187, 174, 255})
		rl.DrawLineDashed({505.0595, 774.4809}, {646.4809, 633.0595}, 2, 5, {148, 177, 166, 255})
		rl.DrawLineDashed({569.5191, 633.0595}, {710.9405, 774.4809}, 2, 5, {171, 149, 118, 255})
		rl.DrawLineDashed({582.9405, 569.5191}, {441.5191, 710.9405}, 2, 5, {145, 137, 126, 255})
		rl.DrawLineDashed({774.4809, 710.9405}, {633.0595, 569.5191}, 2, 5, {178, 104, 149, 255})
		rl.DrawLineDashed({656.0529, 450.63153}, {514.63153, 592.0529}, 2, 5, {191, 189, 147, 255})
		rl.DrawLineDashed({701.36847, 592.0529}, {559.9471, 450.63153}, 2, 5, {118, 106, 171, 255})

	case GameState_Paused:
		draw_circles(&game.world)
		draw_lines(&game.world)
		draw_paused(&game.world)
	}

	rl.EndDrawing()

	free_all(context.temp_allocator)
}

game_deinit :: proc() {
	entity_world_destroy(&game.world)

	rl.UnloadFont(game.font_body)
	rl.UnloadFont(game.font_title)
	music_player_destroy(&game.music_player)
	timelines_destroy(&game.splash_timeline)
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
