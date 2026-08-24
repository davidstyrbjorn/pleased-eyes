package main

main :: proc() {
	game_init()
	defer game_deinit()
	game_run()
}
