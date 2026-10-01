package main

main :: proc() {
	game_init()
	defer game_deinit()

	for game_should_run() {
		game_run()
	}
}
