package main

import "core:math"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

/*
Constants
*/
WINDOW_WIDTH :: 1024
WINDOW_HEIGHT :: 512
MUSIC_BPM :: 80
SIZE_CELL :: 64
CELL_COUNT :: Vector2i{16, 8}

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
	state:             GameState,
	world:             World,
	music:             rl.Music,
	music_paused:      rl.Music,
	volume:            f32,
	font_title:        rl.Font,
	font_body:         rl.Font,
	shoot_origin:      rl.Vector2,
	enemy_spawn_timer: ElapsedTimer,
}

game: Game

game_init :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tendrils of Time - Remake")
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

	entity_world_init(&game.world)
	for x in 0 ..< CELL_COUNT.x {
		for y in 0 ..< CELL_COUNT.y {
			spawn_nav_cell(&game.world, Vector2i{x, y})
		}
	}

	game.state = GameState_Menu{}

	game.enemy_spawn_timer.interval_s = 1.0
	game.enemy_spawn_timer.playing = true
}

game_run :: proc() {
	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.UpdateMusicStream(game.music)
		rl.UpdateMusicStream(game.music_paused)
		rl.SetMusicVolume(game.music, game.volume)
		rl.SetMusicVolume(game.music_paused, 1 - game.volume)

		switch state in game.state {
		case GameState_Menu:
			game.volume = math.lerp(game.volume, 0.0, dt)
			update_menu(&game.world)
		case GameState_Playing:
			game.volume = math.lerp(game.volume, 1.0, dt)

			elapsed_timer_frame_tick(&game.enemy_spawn_timer, dt)

			update_growing_circles(&game.world, dt)
			update_shooting(&game.world, dt)
			update_paused(&game.world)
			update_bullets(&game.world, dt)
			update_enemies(&game.world, dt)

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
			debug_draw_nav_cells(&game.world)
			draw_circles(&game.world)
			draw_shooting()
			draw_rectangles(&game.world)
		case GameState_Paused:
			draw_circles(&game.world)
			draw_paused(&game.world)
		}

		rl.EndDrawing()
	}
}

game_deinit :: proc() {
	entity_world_destroy(&game.world)

	rl.UnloadFont(game.font_body)
	rl.UnloadFont(game.font_title)
	rl.UnloadMusicStream(game.music)
	rl.UnloadMusicStream(game.music_paused)
}

rlxy :: proc(x: f32, y: f32) -> rl.Vector2 {
	return rl.Vector2{x, y}
}

random_color :: proc() -> rl.Color {
	r := u8(rand.int_range(100, 200))
	g := u8(rand.int_range(100, 200))
	b := u8(rand.int_range(100, 200))
	return rl.Color{r, g, b, 255}
}
