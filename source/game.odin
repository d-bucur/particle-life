package game

import "core:c"
import "core:fmt"
import "core:time"
import rl "vendor:raylib"

_run: bool
_scene: Scene
_target_particle_count: f32 // has to be float to work with raygui
_target_tile_ratio: f32 = 0.3 // tiles in spatial grid try to be this ratio of the dist_max
_update_time: f64
_render_time: f64
_historic_fact :: 0.1

init :: proc() {
	_run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	_scene = Scene {
		size = {1024, 600},
	}
	rl.InitWindow(i32(_scene.size.x), i32(_scene.size.y), "Particle life")
	_target_particle_count = 300
	init_scene_static(&_scene)
	init_scene_rand(&_scene)
	init_render()
	// init_scene_test(&_scene)
}

update :: proc() {
	if rl.IsWindowResized() do set_scene_size(rl.GetScreenWidth(), rl.GetScreenHeight())
	rebuild_cache(&_scene)
	// log.info("log.info works!")
	// fmt.println("fmt.println too.")

	rl.BeginDrawing()
	defer rl.EndDrawing()
	// try fade out effect
	rl.ClearBackground(rl.ColorFromHSV(0, 0.1, 0.1))

	cleanup_particles(&_scene, f32(rl.GetTime()))
	start := time.tick_now()
	update_scene(&_scene, rl.GetFrameTime())
	duration := time.duration_microseconds(time.tick_since(start))
	_update_time = (1 - _historic_fact) * _update_time + _historic_fact * duration

	start = time.tick_now()
	render_scene(_scene)
	duration = time.duration_microseconds(time.tick_since(start))
	_render_time = (1 - _historic_fact) * _render_time + _historic_fact * duration
	draw_ui(&_scene)

	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		rl.DrawFPS(i32(_scene.size.x / 2), 0)
	} else {
		rl.DrawText(fmt.ctprintf("%6.f", _update_time), i32(_scene.size.x / 2), 0, 20, rl.GREEN)
		rl.DrawText(fmt.ctprintf("%6.f", _render_time), i32(_scene.size.x / 2), 20, 20, rl.YELLOW)
		rl.DrawText(
			fmt.ctprintf("%i", _useless_comparisons),
			i32(_scene.size.x / 2),
			40,
			20,
			rl.PURPLE,
		)
	}

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
	rebuild_cache(&_scene)
	_scene.spatial = create_spatial(_scene.size, _scene.params.dist_max, _target_tile_ratio)
}

shutdown :: proc() {
	rl.CloseWindow()
	delete(_scene.particles)
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
