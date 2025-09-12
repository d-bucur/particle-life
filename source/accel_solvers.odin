package game

import "core:fmt"
import "core:log"
import "core:math"
import la "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:sys/info"
import "core:thread"

// Accumulate acceleration for each particle
accumulate_accel :: proc(scene: ^Scene) {
	when thread.IS_SUPPORTED {
		_accumulate_accel_multi_thread(scene)
	} else {
		_accumulate_accel_single_thread(scene)
	}
}

// single threaded using symmetry (updating both particles with single force calculation)
_accumulate_accel_single_thread :: proc(scene: ^Scene) {
	eq := scene.params.eq_ratio
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
}

_pool: thread.Pool
_task_runners: [dynamic]TaskRunner
_task_data: [dynamic]TaskData

@(private = "file")
TaskRunner :: struct {
	allocator: mem.Allocator,
	arena:     mem.Dynamic_Arena,
}

@(private = "file")
TaskData :: struct {
	// Simpler way? Tried slice but didn't work
	// particles: []Particle, // slice of particles that a task processes
	start:     int,
	end:       int,
	particles: ^[dynamic]Particle,
	scene:     ^Scene,
}

init_solvers :: proc() {
	when thread.IS_SUPPORTED {
		thread_count := info.cpu.physical_cores
		thread.pool_init(&_pool, context.allocator, thread_count)
		resize(&_task_runners, thread_count)
		resize(&_task_data, thread_count)
		log.infof("Thread pool intitialized with %v threads", thread_count)

		for &alloc in _task_runners {
			mem.dynamic_arena_init(&alloc.arena)
			alloc.allocator = mem.dynamic_arena_allocator(&alloc.arena)
		}
	}
}

destroy_solvers :: proc() {
	thread.pool_stop_all_tasks(&_pool)
	thread.pool_destroy(&_pool)
	delete(_task_runners)
	delete(_task_data)
}

// multi threaded using a task pool
_accumulate_accel_multi_thread :: proc(scene: ^Scene) {
	thread.pool_start(&_pool)
	task_count := len(_task_runners)
	count_per_task := len(scene.particles) / task_count
	for t, i in _task_runners {
		// data[i].particles = scene.particles[i:i + count_per_task]
		_task_data[i].start = i * count_per_task
		_task_data[i].end = (i + 1) * count_per_task
		// TODO missing remainder particles in last slice
		_task_data[i].particles = &scene.particles
		_task_data[i].scene = scene
		thread.pool_add_task(&_pool, t.allocator, _accel_particles, rawptr(&_task_data[i]), i)
	}
	thread.pool_finish(&_pool)
	clear(&_pool.tasks_done) // grows too much, need to clear
}

_accel_particles :: proc(t: thread.Task) {
	data := (^TaskData)(t.data)
	scene := data.scene
	eq := scene.params.eq_ratio
	context.temp_allocator = _task_runners[t.user_index].allocator
	for &p, i in data.particles[data.start:data.end] {
		// query particles in range
		tiles_in_range := spatial_query(scene.spatial, p.pos, scene.params.dist_max, i)
		for tile_key in tiles_in_range {
			for j in scene.spatial.grid[tile_key] {
				if i == j do continue
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
			}
		}
	}
	free_all(_task_runners[t.user_index].allocator)
}
