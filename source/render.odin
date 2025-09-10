package game

import "core:log"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

particle_size :: 3
_visual_debug :: false

render_scene :: proc(scene: Scene) {
	// IMPROV render circle once and reuse
	// defer rl.DrawFPS(i32(scene.size.x / 2), 0)
	for p in scene.particles {
		using p
		rl.DrawCircle(i32(pos.x), i32(pos.y), particle_size, scene.color_map[cluster])
	}
	draw_debug(scene)
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

	// tile size
	if rl.IsKeyPressed(.LEFT_BRACKET) {
		_target_tile_ratio -= 0.1
		scene.spatial = create_spatial(scene.size, scene.params.dist_max, _target_tile_ratio)
		log.infof("%v", _target_tile_ratio)
	}
	if rl.IsKeyPressed(.RIGHT_BRACKET) {
		_target_tile_ratio += 0.1
		scene.spatial = create_spatial(scene.size, scene.params.dist_max, _target_tile_ratio)
		log.infof("%v", _target_tile_ratio)
	}

	// move particle on click
	if rl.IsMouseButtonPressed(.LEFT) {
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

draw_debug :: proc(scene: Scene) {
	when _visual_debug {
		for i in 0 ..= scene.spatial.grid_size.x {
			x := f32(i) * scene.spatial.tile_size.x
			rl.DrawLineV({x, 0}, {x, scene.size.y}, rl.GRAY)
		}
		for j in 0 ..= scene.spatial.grid_size.y {
			y := f32(j) * scene.spatial.tile_size.y
			rl.DrawLineV({0, y}, {scene.size.x, y}, rl.GRAY)
		}

		if len(scene.particles) == 0 do return
		rl.DrawCircleLinesV(
			scene.particles[0].pos,
			scene.params.dist_max * scene.params.eq_ratio,
			rl.GREEN,
		)
		rl.DrawCircleLinesV(scene.particles[0].pos, scene.params.dist_max, rl.PURPLE)
	}
}
