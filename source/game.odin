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
	init_scene_static(&_scene)
	init_scene_rand(&_scene)
	// init_scene_test(&_scene)
}

update :: proc() {
	if rl.IsWindowResized() do set_scene_size(rl.GetScreenWidth(), rl.GetScreenHeight())
	// log.info("log.info works!")
	// fmt.println("fmt.println too.")
	if rl.IsKeyPressed(.MINUS) do _scene.speed -= 0.2
	if rl.IsKeyPressed(.EQUAL) do _scene.speed += 0.2


	rl.BeginDrawing()
	defer rl.EndDrawing()
	// try fade out effect
	rl.ClearBackground(rl.ColorFromHSV(0, 0.1, 0.1))

	update_scene(&_scene, rl.GetFrameTime())
	render_scene(_scene)
	draw_ui(&_scene)

	// Anything allocated using temp allocator is invalid after this.
	free_all(context.temp_allocator)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h: i32) {
	rl.SetWindowSize(c.int(w), c.int(h))
	set_scene_size(w, h)
}

set_scene_size :: proc(w, h: i32) {
	_scene.size = {f32(w), f32(h)}
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
