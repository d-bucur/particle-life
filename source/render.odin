package game

import rl "vendor:raylib"

particle_size :: 5
color_map := [?]rl.Color{rl.RED, rl.YELLOW, rl.GREEN}

render_scene :: proc(scene: Scene) {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	// try fade out effect
	rl.ClearBackground(rl.DARKGRAY)
	defer rl.DrawFPS(0, 0)

	for p in scene.particles {
		using p
		rl.DrawCircle(i32(pos.x), i32(pos.y), particle_size, color_map[cluster])
	}
}
