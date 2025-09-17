package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:odin/ast"
import rl "vendor:raylib"

PosGrid :: distinct [2]int

SpatialIndex :: struct {
	// each tile in the grid has a list of indices to the particle array
	grid:           [dynamic][dynamic]int,
	// world_size = tile_size * grid_size
	tile_size:      Vec2,
	tile_size_half: Vec2,
	world_size:     Vec2,
	grid_size:      [2]int,
}

_target_tile_ratio: f32 = 0.3 // tiles in spatial grid try to be this ratio of the dist_max

create_spatial :: proc(world_size: Vec2, dist_max: f32) -> SpatialIndex {
	// world_size should always be a multiple of tile_size, otherwise weird things happen at the borders
	preferred := dist_max * _target_tile_ratio
	fits := world_size / preferred
	fits = {math.floor(fits.x), math.floor(fits.y)} // no array programming bruh?
	tile_size := world_size / fits
	return SpatialIndex {
		tile_size = tile_size,
		tile_size_half = tile_size / 2,
		grid_size = {
			int(math.ceil(world_size.x / tile_size.x)),
			int(math.ceil(world_size.y / tile_size.y)),
		},
		world_size = world_size,
	}
	// leaks initial array memory??
}

spatial_pos :: proc "contextless" (
	spatial: SpatialIndex,
	pos: Vec2,
	wraparound: bool = true,
) -> PosGrid {
	pos := pos
	if wraparound {
		wrap_position(&pos, spatial.world_size)
	}
	row := _fast_int(pos.x / spatial.tile_size.x)
	column := _fast_int(pos.y / spatial.tile_size.y)
	return PosGrid{row, column}
}

// avoid extra modf of floor(), works in most cases
_fast_int :: proc "contextless" (v: f32) -> int {
	return int(v) if v >= 0 else int(v - 1)
}

spatial_pos_to_key :: #force_inline proc(spatial: SpatialIndex, pos: PosGrid) -> int {
	// assert(pos.x >= 0)
	// assert(pos.x < spatial.grid_size.x)
	// assert(pos.y >= 0)
	// assert(pos.y < spatial.grid_size.y)
	return pos.y * spatial.grid_size.x + pos.x
}

spatial_rebuild :: proc(spatial: ^SpatialIndex, particles: [dynamic]Particle) {
	// override allocator bc i'm not sure how pass the temp one to the internal array
	// and this leaks otherwise
	prev_allocator := context.allocator
	defer context.allocator = prev_allocator
	context.allocator = context.temp_allocator
	avg_particles := len(particles) / (spatial.grid_size.x * spatial.grid_size.x)

	spatial.grid = make_dynamic_array_len(
		[dynamic][dynamic]int,
		spatial.grid_size.x * spatial.grid_size.y,
	)
	// IMPROV clear and reuse same arrays from previous frame
	// >50% of time spent on reserving arrays
	for &tile in spatial.grid {
		reserve(&tile, avg_particles)
	}
	for p, i in particles {
		pos := spatial_pos(spatial^, p.pos)
		key := spatial_pos_to_key(spatial^, pos)
		append(&spatial.grid[key], i)
	}
}

// Returns keys in spatial grid for tiles that might overlap. Tiles have to be iterated manually by caller
spatial_query :: proc(
	spatial: SpatialIndex,
	pos: Vec2,
	radius: f32,
	allocator := context.temp_allocator,
) -> [dynamic]int {
	// MAYBE test octree implementation: https://en.wikipedia.org/wiki/Quadtree#Pseudocode
	// MAYBE can use some ideas from here: https://www.redblobgames.com/grids/circle-drawing/ ?

	corner1_unwrapped := spatial_pos(spatial, pos - {radius, radius}, false)
	corner2_unwrapped := spatial_pos(spatial, pos + {radius, radius}, false)
	// IMPROV clamp diff to max world size for worst case scenario
	diff := corner2_unwrapped - corner1_unwrapped
	corner_start := spatial_pos(spatial, pos - {radius, radius})

	result := make_dynamic_array_len_cap([dynamic]int, 0, 50, allocator)
	// iterate grid indexes in range and wraparound
	// manual indices to avoid divisions
	x := corner_start.x
	for i := 0; i <= diff.x; i += 1 {
		if x >= spatial.grid_size.x do x -= spatial.grid_size.x
		y := corner_start.y
		for j := 0; j <= diff.y; j += 1 {
			if y >= spatial.grid_size.y do y -= spatial.grid_size.y

			key := spatial_pos_to_key(spatial, {x, y})
			if (len(spatial.grid[key]) > 0) do append(&result, key)

			// highlight tiles that are included in the query result
			// when _visual_debug {
			// 	rl.DrawRectangleLinesEx(
			// 		{
			// 			f32(x) * spatial.tile_size.x,
			// 			f32(y) * spatial.tile_size.y,
			// 			spatial.tile_size.x,
			// 			spatial.tile_size.y,
			// 		},
			// 		3,
			// 		rl.SKYBLUE,
			// 	)
			// }
			y += 1
		}
		x += 1
	}

	return result
}
