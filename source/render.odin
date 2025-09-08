package game

import rl "vendor:raylib"

particle_size :: 3

render_scene :: proc(scene: Scene) {
	// defer rl.DrawFPS(i32(scene.size.x / 2), 0)

	for p in scene.particles {
		using p
		rl.DrawCircle(i32(pos.x), i32(pos.y), particle_size, scene.color_map[cluster])
	}
}

draw_ui :: proc(scene: ^Scene) {
	rl.GuiSlider(_layout(1), "", "speed", &scene.speed, 0, 2)
	rl.GuiSlider(_layout(2), "", "friction", &scene.params.friction, 0.01, 1)
	rl.GuiSlider(_layout(3), "", "force", &scene.params.force_mult, 0.01, 0.2)
	rl.GuiSlider(_layout(4), "", "equilibrium dist", &scene.params.eq_ratio, 0.001, 1)
	rl.GuiSlider(_layout(5), "", "max dist", &scene.params.dist_max, 1, 800)
	if rl.GuiButton(_layout(6), "Random weights") {
		fill_rand_weights(scene)
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		_scene.particles[0].pos = rl.GetMousePosition()
	}
}

_layout :: proc(i: i32) -> rl.Rectangle {
	return rl.Rectangle{0, _scene.size.y - f32(i) * 20, 200, 20}
}
