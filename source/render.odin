package game

import rl "vendor:raylib"

particle_size :: 5

render_scene :: proc(scene: Scene) {
	defer rl.DrawFPS(0, 0)

	for p in scene.particles {
		using p
		rl.DrawCircle(i32(pos.x), i32(pos.y), particle_size, scene.color_map[cluster])
	}

	rl.GuiSlider(_layout(1), "", "speed", &_scene.speed, 0, 2)
	rl.GuiSlider(_layout(2), "", "friction", &_scene.params.friction, 0.01, 1)
	rl.GuiSlider(_layout(3), "", "force", &_scene.params.force_mult, 0.01, 0.2)
}

_layout :: proc(i: i32) -> rl.Rectangle {
	return rl.Rectangle {0, _scene.size.y - f32(i) * 20, 200, 20}
}
