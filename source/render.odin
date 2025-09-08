package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

particle_size :: 3

render_scene :: proc(scene: Scene) {
	defer rl.DrawFPS(i32(scene.size.x / 2), 0)

	for p in scene.particles {
		using p
		rl.DrawCircle(i32(pos.x), i32(pos.y), particle_size, scene.color_map[cluster])
	}
}

_ui_width :: 200
draw_ui :: proc(scene: ^Scene) {
	rl.GuiSliderBar(_layout(1), "", "speed", &scene.speed, 0, 2)
	rl.GuiSlider(_layout(2), "", "friction", &scene.params.friction, 0.01, 1)
	rl.GuiSlider(_layout(3), "", "force", &scene.params.force_mult, 0.01, 0.2)
	rl.GuiSlider(_layout(4), "", "equilibrium dist", &scene.params.eq_ratio, 0.001, 1)
	rl.GuiSlider(_layout(5), "", "max dist", &scene.params.dist_max, 1, 800)
	if rl.GuiButton(_layout(6), "Random weights") {
		fill_rand_weights(scene)
	}

	// particle count
	if rl.IsKeyPressed(.MINUS) do _target_particle_count -= 50
	if rl.IsKeyPressed(.EQUAL) do _target_particle_count += 50
	count := int(_target_particle_count)
	label := fmt.ctprintf("count: %v", count)
	rl.GuiSlider(_layout(7), "", label, &_target_particle_count, 2, 2000)
	if count != len(scene.particles) {
		resize_particles(scene, count)
	}

	// move particle on click
	if rl.IsMouseButtonPressed(.MIDDLE) {
		_scene.particles[0].pos = rl.GetMousePosition()
	}

	// draw weights
	// sz: f32 = math.min(_ui_width / max_clusters, 30) // variable size
	sz: f32 = 30
	for i in 0 ..< max_clusters {
		rl.DrawCircleV({sz * 2 + f32(i) * sz, sz}, sz / 3, scene.color_map[i])
		rl.DrawCircleV({sz, sz * 2 + f32(i) * sz}, sz / 3, scene.color_map[i])

		for j in 0 ..< max_clusters {
			rect := rl.Rectangle{sz * 1.5 + f32(i) * sz, sz * 1.5 + f32(j) * sz, sz, sz}
			weight := &scene.weights[i][j]
			// weight := i32(weight2^ * 10)
			color := rl.Fade(
				rl.ColorFromHSV(linalg.mix(f32(0), 120, (weight^ + 1) / 2), 0.5, 1),
				0.6,
			)
			rl.DrawRectangleRec(rect, color)
			rl.DrawRectangleLinesEx(rect, 3, color)

			// input to change weight values
			wheel := rl.GetMouseWheelMove()
			if rl.CheckCollisionPointRec(rl.GetMousePosition(), rect) {
				weight^ = math.max(math.min(weight^ + 0.2 * wheel, 1), -1)
			}

			// alternative using mouse clicks
			// if rl.IsMouseButtonDown(.LEFT) &&
			//    rl.CheckCollisionPointRec(rl.GetMousePosition(), rect) {
			// 	weight^ = math.min(weight^ + 0.02, 1)
			// }
			// if rl.IsMouseButtonDown(.RIGHT) &&
			//    rl.CheckCollisionPointRec(rl.GetMousePosition(), rect) {
			// 	weight^ = math.max(weight^ - 0.02, -1)
			// }
			// rl.GuiValueBox(rect, "", &weight, -10, 10, false)
			// scene.weights[i][j] = f32(weight) / 10
		}
	}

}

_layout :: proc(i: i32) -> rl.Rectangle {
	return rl.Rectangle{0, _scene.size.y - f32(i) * 20, _ui_width, 20}
}
