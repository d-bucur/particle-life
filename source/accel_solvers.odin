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

_is_threaded :: thread.IS_SUPPORTED

// Accumulate acceleration for each particle
accumulate_accel :: proc(scene: ^Scene) {
	when _is_threaded {
		_accumulate_accel_multi_thread(scene)
	} else {
		_accumulate_accel_single_thread(scene)
	}
}

_calc_force :: #force_inline proc(r: f32, weight: f32, eq: f32, er: f32) -> f32 {
	if r < eq {
		return r / eq - 1
	} else if r < 1 {
		return weight * (1 - math.abs(2 * r - 1 - eq) * er)
	} else {
		return 0
	}
}

// single threaded using symmetry (updates both particles with single force calculation)
_accumulate_accel_single_thread :: proc(scene: ^Scene) {
	for particles_in_tile, tile_idx in &scene.spatial.grid {
		_accel_per_tile(particles_in_tile, tile_idx, scene)
	}
}

_accel_per_tile :: #force_inline proc(
	particles_in_tile: [dynamic]int,
	tile_idx: int,
	scene: ^Scene,
) {
	if len(particles_in_tile) == 0 do return
	y, x := math.divmod(tile_idx, scene.spatial.grid_size.x)
	c := Vec2{f32(x), f32(y)}
	// BUG minor: doesn't cover furthest tile when point is at the edges of the tile (reproduce with 1 particle)
	tile_center := c * scene.spatial.tile_size + scene.spatial.tile_size_half
	tiles_in_range := spatial_query(scene.spatial, tile_center, scene.params.dist_max)
	for i in particles_in_tile {
		p := &scene.particles[i]
		for tile_key in tiles_in_range {
			for j in scene.spatial.grid[tile_key] {
				// if single threaded then do symmetrical pass
				when _is_threaded {
					if i == j do continue
				} else {
					if i < j do continue
				}
				other := &scene.particles[j]
				delta := distance_wrapped(other.pos, p.pos, scene)
				l := la.length(delta)
				delta_norm := delta / l if l > 0.001 else 0
				r := l / scene.params.dist_max

				weight := scene.weights[p.cluster][other.cluster]
				p.accel +=
					delta_norm * _calc_force(r, weight, scene.params.eq_ratio, scene.cached.er) // no mass

				// if single threaded then apply symmetric force to other particle now
				when !_is_threaded {
					weight = scene.weights[other.cluster][p.cluster]
					other.accel -=
						delta_norm *
						_calc_force(r, weight, scene.params.eq_ratio, scene.cached.er) // no mass
				}
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
			runner.thread = thread.create(_accel_subset_thread)
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
		thread.terminate(t.thread, 1)
		thread.destroy(t.thread)
	}
	delete(_task_data)
	delete(_task_runners)
}

_accumulate_accel_multi_thread :: proc(scene: ^Scene) {
	_thread_scene = scene
	thread_count := len(_task_runners)
	count_per_task := len(scene.particles) / thread_count + 1
	tiles_max := len(scene.spatial.grid) - 1
	batch_count := 0
	batch_start := 0
	batch_num := 0
	for tile, i in scene.spatial.grid {
		assert(batch_num < thread_count)
		batch_count += len(tile)
		// IMPROV balancing. if current tile adds too many leave it for the next batch
		if batch_count >= count_per_task || i == tiles_max {
			// dispatch thread with current batch
			_task_data[batch_num].start = batch_start
			_task_data[batch_num].end = i + 1
			// fmt.printfln(
			// 	"Dispatched thread %v: [%v:%v] - count %v",
			// 	batch_num,
			// 	batch_start,
			// 	i + 1,
			// 	batch_count,
			// )
			intrinsics.atomic_add(&_task_runners[batch_num].lock, 1)
			sync.futex_signal(&_task_runners[batch_num].lock)
			batch_count = 0
			batch_start = i + 1
			batch_num += 1
		}
	}
	// wait for threads to finish
	for &t in _task_runners {
		sync.futex_wait(&t.lock, 1)
	}
}

_accel_subset_thread :: proc(t: ^thread.Thread) {
	data := (^TaskData)(t.data)
	context.temp_allocator = _task_runners[t.user_index].allocator
	sem := &_task_runners[t.user_index].lock

	for {
		sync.futex_wait(sem, 0)
		scene := _thread_scene
		for tile_idx in data.start ..< data.end {
			particles_in_tile := scene.spatial.grid[tile_idx]
			_accel_per_tile(particles_in_tile, tile_idx, scene)
		}
		intrinsics.atomic_sub(sem, 1)
		sync.futex_signal(sem)
		free_all(_task_runners[t.user_index].allocator)
	}
}
