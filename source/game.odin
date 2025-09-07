package game

import "core:c"
import "core:fmt"
import "core:log"
import rl "vendor:raylib"

_run: bool
_scene: Scene

init :: proc() {
	_run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	_scene = Scene {
		size = {1024, 600},
	}
	rl.InitWindow(i32(_scene.size.x), i32(_scene.size.y), "Particle life")
	init_scene_rand(&_scene)
}

update :: proc() {
	// log.info("log.info works!")
	// fmt.println("fmt.println too.")

	rl.BeginDrawing()
	defer rl.EndDrawing()
	// try fade out effect
	rl.ClearBackground(rl.DARKGRAY)

	update_scene(&_scene, rl.GetFrameTime())
	render_scene(_scene)

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
			_run = false
		}
	}

	return _run
}
