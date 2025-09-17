package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

particle_radius :: 3
_visual_debug :: false
_particle_texture: rl.RenderTexture2D
_scene_texture: rl.RenderTexture2D
_background_color := rl.ColorFromHSV(0, 0.1, 0.1)
_camera := rl.Camera2D {
	zoom = 1,
}

init_render :: proc() {
	sz: i32 = particle_radius * 3
	_scene_texture = rl.LoadRenderTexture(i32(_scene.size.x), i32(_scene.size.y))
	_particle_texture = rl.LoadRenderTexture(sz, sz)
	rl.BeginTextureMode(_particle_texture)
	// rl.ClearBackground(rl.WHITE) // square particle
	rl.DrawCircleGradient(particle_radius, particle_radius, particle_radius, rl.GRAY, rl.WHITE)
	rl.EndTextureMode()
}

render_scene :: proc(scene: Scene) {
	for p in scene.particles {
		rl.DrawTextureV(
			_particle_texture.texture,
			p.pos - particle_radius,
			scene.color_map[p.cluster],
		)
	}
	draw_debug(scene)
}

_ui_width :: 200
draw_ui :: proc(scene: ^Scene) {
	rl.GuiSliderBar(_layout(1), "", "speed", &scene.speed, 0, 2)
	rl.GuiSlider(_layout(2), "", "friction", &scene.params.friction, 0.01, 1)
	rl.GuiSlider(_layout(3), "", "force", &scene.params.force_mult, 1000, 4000)
	rl.GuiSlider(_layout(4), "", "equilibrium dist", &scene.params.eq_ratio, 0.001, 1)

	dist_max := scene.params.dist_max
	rl.GuiSlider(_layout(5), "", "max dist", &dist_max, 1, 800)
	if dist_max != scene.params.dist_max {
		scene.params.dist_max = dist_max
		_scene.spatial = create_spatial(_scene.size, _scene.params.dist_max, _target_tile_ratio)
	}

	if rl.GuiButton(_layout(6), "Random weights") {
		fill_rand_weights(scene)
	}

	// particle count
	if rl.IsKeyPressed(.MINUS) do _target_particle_count -= 50
	if rl.IsKeyPressed(.EQUAL) do _target_particle_count += 50
	count := int(_target_particle_count)
	label := fmt.ctprintf("count: %v", count)
	rl.GuiSlider(_layout(7), "", label, &_target_particle_count, 1, 4000)
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

finish_render :: proc() {
	handle_input()

	// Draw repeating scene to the screen
	rl.BeginMode2D(_camera)
	source := rl.Rectangle {
		0,
		0,
		f32(_scene_texture.texture.width),
		-f32(_scene_texture.texture.height),
	}
	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			rl.DrawTexturePro(
				_scene_texture.texture,
				source,
				rl.Rectangle{0, 0, _scene.size.x, _scene.size.y},
				-{f32(i) * _scene.size.x, f32(j) * _scene.size.y},
				0,
				rl.WHITE,
			)
		}
	}
	rl.EndMode2D()

	draw_ui(&_scene)

	// Drraw render stats
	when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
		rl.DrawFPS(i32(_scene.size.x / 2), 0)
	} else {
		rl.DrawText(fmt.ctprintf("%6.f", _update_time), i32(_scene.size.x / 2), 0, 20, rl.GREEN)
		rl.DrawText(fmt.ctprintf("%6.f", _render_time), i32(_scene.size.x / 2), 20, 20, rl.YELLOW)
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
		rl.DrawRectangleLines(0, 0, i32(scene.size.x), i32(scene.size.y), rl.PURPLE)
	}
}
