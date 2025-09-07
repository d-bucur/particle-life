package game

import "core:math/rand"
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
	particles:   [50]Particle,
	force_field: [max_colors][max_colors]f32,
	size:        Vec2,
}

init_scene_rand :: proc(scene: ^Scene) {
	for &p in scene.particles {
		using p
		cluster = rand.int31_max(max_colors)
		pos = {rand.float32() * 600 - 300, rand.float32() * 600 - 300}
		vel = {rand.float32() * 2 - 1, rand.float32() * 2 - 1}
	}
}

update_scene :: proc(scene: ^Scene) {
	for &p in scene.particles {
		using p
		// calculate accelerations
		// integrate velocity
		// integrate position
		pos += vel
		
		// handle out of bounds
		// could change to destroy particle
		margin :: particle_size
		if (pos.x > scene.size.x + margin) do pos.x = -margin
		if (pos.x < -margin) do pos.x = scene.size.x + margin
		if (pos.y > scene.size.y + margin) do pos.y = -margin
		if (pos.y < -margin) do pos.y = scene.size.y + margin
	}
}
