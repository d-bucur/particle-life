package game

import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import rl "vendor:raylib"

import "base:runtime"
import "core:sync"
import "trace"

_run: bool
_scene: Scene
_camera_offset: Vec2 // fake camera offset that wraps around, actual Raylib camera is fixed

// performance timings
_update_time: f64
_render_time: f64
_historic_fact :: 0.1 // used to calculate FPS

init :: proc() {
	_run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	_scene = Scene {
		size = {1024, 600},
	}
	rl.InitWindow(i32(_scene.size.x), i32(_scene.size.y), "Particle life")
	when trace.IS_TRACING {
		trace.spall_context_create()
		trace.buffer_create()
	}
	
	init_scene_static(&_scene)
	init_scene_rand(&_scene)
	// init_scene_test(&_scene, 2)
	init_render()
	init_solvers()
}

update :: proc() {
	if rl.IsWindowResized() do set_scene_size(rl.GetScreenWidth(), rl.GetScreenHeight())
	rebuild_cache(&_scene)

	handle_input()

	// Update and redraw particles in the scene
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(_background_color)

	rl.BeginMode2D(_camera)
	cleanup_particles(&_scene, f32(rl.GetTime()))
	start := time.tick_now()
	update_scene(&_scene, rl.GetFrameTime())
	duration := time.duration_microseconds(time.tick_since(start))
	_update_time = (1 - _historic_fact) * _update_time + _historic_fact * duration

	start = time.tick_now()
	render_scene(_scene)
	duration = time.duration_microseconds(time.tick_since(start))
	_render_time = (1 - _historic_fact) * _render_time + _historic_fact * duration
	rl.EndMode2D()

	finish_render()

	// Anything allocated using temp allocator is invalid after this.
	free_all(context.temp_allocator)
}

handle_input :: proc() {
	speed :: 10
	if rl.IsKeyDown(.W) do _camera_offset += {0, speed}
	if rl.IsKeyDown(.S) do _camera_offset += {0, -speed}
	if rl.IsKeyDown(.A) do _camera_offset += {speed, 0}
	if rl.IsKeyDown(.D) do _camera_offset += {-speed, 0}
	wrap_position(&_camera_offset, _scene.size)

	zoom_speed :: 0.01
	if rl.IsKeyDown(.Q) do _camera.zoom = math.max(_camera.zoom - zoom_speed, 1)
	if rl.IsKeyDown(.E) do _camera.zoom = math.min(_camera.zoom + zoom_speed, 2)
	// IMPROV should change offset to zoom around center

	if rl.IsKeyPressed(.R) do fill_rand_weights(&_scene)
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
	_scene.spatial = create_spatial(_scene.size, _scene.params.dist_max)
}

shutdown :: proc() {
	rl.CloseWindow()
	when trace.IS_TRACING {
		trace.buffer_destroy()
		trace.spall_context_destroy()
	}
	destroy_solvers()
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
