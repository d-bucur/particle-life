package game

import "core:math"
import la "core:math/linalg"
import "core:math/rand"

import rl "vendor:raylib" // used for debug

// particle life cluster simulator
// inspired by https://www.ventrella.com/Clusters/intro.html

Vec2 :: [2]f32

Particle :: struct {
	pos:     Vec2,
	vel:     Vec2,
	accel:   Vec2,
	cluster: i32,
}

max_colors :: 3
Scene :: struct {
	// turn into soa later
	particles: [100]Particle,
	weights:   [max_colors][max_colors]f32,
	size:      Vec2,
	params:    SimParams,
}

SimParams :: struct {
	friction:        f32,
	force_mult:      f32,
	dist_attraction: f32, // r1
	dist_max:        f32, // r2
	peak_repulsion:  f32, // f1
	peak_attraction: f32, // f2
	cutoff_force:    f32, // f3
}

init_scene_rand :: proc(scene: ^Scene) {
	scene.params = {
		friction        = 0.5, // actually inverted: higher value means less friction
		force_mult      = 0.2,
		dist_attraction = 10000,
		dist_max        = 40000,
		peak_repulsion  = -1,
		peak_attraction = 1,
		cutoff_force    = 0,
	}
	for &p in scene.particles {
		using p
		cluster = rand.int31_max(max_colors)
		pos = {rand.float32() * scene.size.x, rand.float32() * scene.size.y}
		vel = {rand.float32() * 1, rand.float32() * 1}
	}
	for &row, i in scene.weights {
		for &v, j in row {
			v = rand.float32() * 2 - 1
			// v = 1 if i == j else -1
		}
	}
}

update_scene :: proc(scene: ^Scene, dt: f32) {
	if dt == 0 do return // nothing to update
	dt := dt * 100 // avoid rounding errors by staying close to 1

	for &p, i in &scene.particles {
		using p
		// calculate accelerations
		accel = {0, 0}
		for other, j in scene.particles {
			// TODO optimize calculations
			delta := distance_wrapped(other.pos, pos, scene.size)
			len_sqr := la.length2(delta)
			if len_sqr < 0.01 || len_sqr > scene.params.dist_max do continue
			force: f32
			if (len_sqr) < scene.params.dist_attraction {
				force = la.lerp(
					scene.params.peak_repulsion,
					scene.params.peak_attraction,
					len_sqr / scene.params.dist_attraction,
				)
			} else {
				force = la.lerp(
					scene.params.peak_attraction,
					scene.params.cutoff_force,
					(len_sqr - scene.params.dist_attraction) /
					((scene.params.dist_max - scene.params.dist_attraction)),
				)
			}
			weight := scene.weights[p.cluster][other.cluster]
			accel += weight * force * la.normalize(delta)
		}
		accel *= scene.params.force_mult

		rl.DrawLineV(pos, pos + accel, color_map[cluster])
		if i == 0 {
			rl.DrawCircleLinesV(pos, math.sqrt(scene.params.dist_attraction), rl.GREEN)
			rl.DrawCircleLinesV(pos, math.sqrt(scene.params.dist_max), rl.PURPLE)
		}

		// integrate velocity
		vel = vel * scene.params.friction + accel * dt // how to use dt in friction?

		// integrate position
		pos += vel * dt
		wrap_position(&pos, scene.size)
	}
}

distance_wrapped :: proc(a: Vec2, b: Vec2, size: Vec2) -> Vec2 {
	r := a - b
	if math.abs(r.x) > size.x do r.x = size.x - r.x
	if math.abs(r.y) > size.y do r.y = size.y - r.y
	return r
}

wrap_position :: proc(pos: ^Vec2, size: Vec2) {
	// handle out of bounds
	// could change to destroy particle
	margin :: particle_size
	if (pos.x > size.x + margin) do pos.x = -margin
	if (pos.x < -margin) do pos.x = size.x + margin
	if (pos.y > size.y + margin) do pos.y = -margin
	if (pos.y < -margin) do pos.y = size.y + margin
}
