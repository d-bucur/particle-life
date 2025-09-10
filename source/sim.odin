package game

import "core:log"
import "core:math"
import la "core:math/linalg"
import "core:math/rand"

import rl "vendor:raylib"

Vec2 :: [2]f32

Particle :: struct {
	pos:        Vec2,
	vel:        Vec2,
	accel:      Vec2,
	cluster:    i32,
	birth_time: f32,
}

max_particles :: 1000
max_clusters :: 4
max_velocity :: 2
_useless_comparisons: int // used for profiling

Scene :: struct {
	// IMPROV turning into #soa doesn't improve perf at all??
	particles: [dynamic]Particle,
	weights:   [max_clusters][max_clusters]f32,
	size:      Vec2,
	params:    SimParams,
	speed:     f32,
	color_map: [max_clusters]rl.Color,
	cached:    Cached,
	spatial:   SpatialIndex,
}

Cached :: struct {
	size_half: Vec2,
	er:        f32,
}

SimParams :: struct {
	friction:   f32, // actually inverted. higher values means less friction
	force_mult: f32, // multiply force by factor
	dist_max:   f32, // maximum attraction range
	eq_ratio:   f32, // 0..=1 equilibrium ratio as percentage from dist_max
	// Not sure I like how this works now
	life_time:  f32, // after this time the particle will die and a new one will be spawned
}

init_scene_static :: proc(scene: ^Scene) {
	scene.speed = 1
	scene.params = SimParams {
		friction   = 0.5,
		force_mult = 0.1,
		eq_ratio   = 0.3,
		dist_max   = 200,
		life_time  = 20,
	}
	scene.spatial = create_spatial(scene.size, scene.params.dist_max, _target_tile_ratio)
}

init_scene_rand :: proc(scene: ^Scene) {
	reserve(&scene.particles, max_particles)
	fill_rand_weights(scene)
	golden_ratio := (math.sqrt_f32(5) + 1) / 2
	offset := rand.float32() * golden_ratio
	for &color, i in scene.color_map {
		hue: f32 = math.remainder(f32(i) * golden_ratio + offset, 1)
		color = rl.ColorFromHSV(hue * 360, 0.7, 1)
	}
}

init_scene_test :: proc(scene: ^Scene) {
	_target_particle_count = 2
	scene.params.life_time = 10000
	append(&scene.particles, Particle{pos = {50, 250}, cluster = 0})
	append(&scene.particles, Particle{pos = {scene.size.x - 50, 250}, cluster = 1})
	scene.weights[0][1] = 1
	scene.weights[1][0] = 1
	scene.color_map[0] = rl.RED
	scene.color_map[1] = rl.YELLOW
}

resize_particles :: proc(scene: ^Scene, num_particles: int) {
	diff := num_particles - len(scene.particles)
	switch {
	case diff > 0:
		for i in 0 ..< diff {
			p := Particle{}
			randomize_particle(&p, scene^, (rand.float32() - 1) * scene.params.life_time)
			append(&scene.particles, p)
		}
	case diff < 0:
		resize(&scene.particles, num_particles)
	}
}

randomize_particle :: #force_inline proc(p: ^Particle, scene: Scene, time: f32) {
	p.cluster = rand.int31_max(max_clusters)
	p.pos = {rand.float32() * scene.size.x, rand.float32() * scene.size.y}
	p.vel = {rand.float32() * 1, rand.float32() * 1}
	p.birth_time = time
}

fill_rand_weights :: proc(scene: ^Scene) {
	for &row, i in scene.weights {
		for &v, j in row {
			v = rand.float32() * 2 - 1
			// v = 1 if i == j else -1
		}
	}
}

rebuild_cache :: proc(scene: ^Scene) {
	scene.cached.size_half = scene.size / 2
	scene.cached.er = 1 / (1 - scene.params.eq_ratio)
}

update_scene :: proc(scene: ^Scene, dt: f32) {
	if dt == 0 do return // nothing to update
	dt := dt * 100 * scene.speed // avoid rounding errors by staying close to 1

	// cached values
	eq := scene.params.eq_ratio
	_useless_comparisons = 0

	// IMPROV soa and memcopy over
	for &p in &scene.particles {
		p.accel = {0, 0}
	}

	spatial_rebuild(&scene.spatial, scene.particles)

	// pass to accumulate accelerations
	for &p, i in &scene.particles {
		// query particles in range
		tiles_in_range := spatial_query(scene.spatial, p.pos, scene.params.dist_max, i)
		for tile_key in tiles_in_range {
			for j in scene.spatial.grid[tile_key] {
				if i < j do continue
				other := &scene.particles[j]
				delta := distance_wrapped(other.pos, p.pos, scene)
				l := la.length(delta)
				delta_norm := delta / l if l > 0.001 else 0
				r := l / scene.params.dist_max

				// TODO don't repeat code
				force: f32
				// particle 1
				weight := scene.weights[p.cluster][other.cluster]
				if r < eq {
					force = r / eq - 1
				} else if r < 1 {
					force = weight * (1 - math.abs(2 * r - 1 - eq) * scene.cached.er)
				} else {
					_useless_comparisons += 1
					force = 0
				}
				p.accel += force * delta_norm // no mass

				// particle 2
				force = 0
				weight = scene.weights[other.cluster][p.cluster]
				if r < eq {
					force = r / eq - 1
				} else if r < 1 {
					force = weight * (1 - math.abs(2 * r - 1 - eq) * scene.cached.er)
				} else {
					_useless_comparisons += 1
					force = 0
				}
				other.accel -= force * delta_norm // no mass
			}
		}
	}

	// integration pass
	for &p in &scene.particles {
		p.accel *= scene.params.force_mult

		// integrate velocity and clamp
		// friction does not depend on dt. inconsistent at different speeds
		p.vel = p.vel * scene.params.friction + p.accel * dt
		p.vel.x = math.clamp(p.vel.x, -max_velocity, max_velocity)
		p.vel.y = math.clamp(p.vel.y, -max_velocity, max_velocity)

		// integrate position
		p.pos += p.vel * dt
		wrap_position(&p.pos, scene.size)
	}

}

distance_wrapped :: #force_inline proc(a: Vec2, b: Vec2, scene: ^Scene) -> Vec2 {
	r := a - b
	h := scene.cached.size_half
	if r.x > h.x do r.x -= scene.size.x
	else if r.x < -h.x do r.x += scene.size.x
	if r.y > h.y do r.y -= scene.size.y
	else if r.y < -h.y do r.y += scene.size.y
	return r
}

wrap_position :: #force_inline proc(pos: ^Vec2, size: Vec2) {
	// MAYBE re-add margins
	margin :: 0
	if (pos.x >= size.x + margin) do pos.x -= size.x - margin
	else if (pos.x < -margin) do pos.x += size.x + margin
	if (pos.y >= size.y + margin) do pos.y -= size.y - margin
	else if (pos.y < -margin) do pos.y += size.y + margin

	// BUG can still assert if diff > size (ie. when minimizing the game, or very fast speeds)
	// worth it to do division here?
	// assert(pos.x >= 0)
	// assert(pos.x < size.x)
	// assert(pos.y >= 0)
	// assert(pos.y < size.y)
}

cleanup_particles :: proc(scene: ^Scene, time: f32) {
	max_life := scene.params.life_time
	for &p in scene.particles {
		life_time := time - p.birth_time
		if life_time >= max_life {
			randomize_particle(&p, scene^, time)
		}
	}
}
