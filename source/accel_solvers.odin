package game

import "base:intrinsics"
import "core:fmt"
import "core:log"
import "core:math"
import la "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:sync"
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

@(private = "file")
_task_runners: [dynamic]TaskRunner
@(private = "file")
_task_data: [dynamic]TaskData
@(private = "file")
_thread_scene: ^Scene // not ideal as a global, but at least don't have to set it for each thread

@(private = "file")
TaskRunner :: struct {
	allocator: mem.Allocator,
	arena:     mem.Dynamic_Arena,
	thread:    ^thread.Thread,
	lock:      sync.Futex,
}

@(private = "file")
TaskData :: struct {
	// MAYBE can work with slice?
	// particles: []Particle, // slice of particles that a task processes
	start: int,
	end:   int,
}

init_solvers :: proc() {
	when thread.IS_SUPPORTED {
		thread_count := info.cpu.logical_cores
		resize(&_task_runners, thread_count)
		resize(&_task_data, thread_count)

		for &runner, i in _task_runners {
			mem.dynamic_arena_init(&runner.arena)
			runner.allocator = mem.dynamic_arena_allocator(&runner.arena)
			runner.thread = thread.create(_accel_particles)
			runner.thread.data = &_task_data[i]
			runner.thread.user_index = i
			log.infof("Starting thread %v", runner.thread.user_index)
			thread.start(runner.thread)
		}
		log.infof("Thread pool intitialized with %v threads", thread_count)
	}
}

destroy_solvers :: proc() {
	for &t in _task_runners {
		thread.destroy(t.thread)
	}
	delete(_task_runners)
	delete(_task_data)
}

_accumulate_accel_multi_thread :: proc(scene: ^Scene) {
	_thread_scene = scene
	task_count := len(_task_runners)
	count_per_task := len(scene.particles) / task_count
	for &runner, i in _task_runners {
		_task_data[i].start = i * count_per_task
		_task_data[i].end = (i + 1) * count_per_task
		// TODO missing remainder particles in last slice
		intrinsics.atomic_add(&runner.lock, 1)
		sync.futex_signal(&runner.lock)
	}
	// wait for threads to finish
	for &t in _task_runners {
		sync.futex_wait(&t.lock, 1)
	}
	// BUG: hangs on pressing ESC, probably due to wait here
}

_accel_particles :: proc(t: ^thread.Thread) {
	data := (^TaskData)(t.data)
	context.temp_allocator = _task_runners[t.user_index].allocator
	sem := &_task_runners[t.user_index].lock

	for {
		sync.futex_wait(sem, 0)
		scene := _thread_scene
		eq := scene.params.eq_ratio
		for &p, i in _thread_scene.particles[data.start:data.end] {
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
		intrinsics.atomic_sub(sem, 1)
		sync.futex_signal(sem)
		free_all(_task_runners[t.user_index].allocator)
	}
}
