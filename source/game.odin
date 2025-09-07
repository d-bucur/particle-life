package game

import "core:c"
import "core:fmt"
import "core:log"
import rl "vendor:raylib"

run: bool
scene: Scene

init :: proc() {
	run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	scene = Scene {
		size = {1024, 600},
	}
	rl.InitWindow(i32(scene.size.x), i32(scene.size.y), "Particle life")
	init_scene_rand(&scene)
}

update :: proc() {
	update_scene(&scene)
	// log.info("log.info works!")
	// fmt.println("fmt.println too.")
	render_scene(scene)

	// Anything allocated using temp allocator is invalid after this.
	free_all(context.temp_allocator)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
}

shutdown :: proc() {
	rl.CloseWindow()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			run = false
		}
	}

	return run
}
