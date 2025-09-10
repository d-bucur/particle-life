package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:odin/ast"
import rl "vendor:raylib"

PosGrid :: distinct [2]int

SpatialIndex :: struct {
	grid:       [dynamic][dynamic]int, // each tile in the grid has a list of indices to the particle array
	// world_size = tile_size * grid_size
	tile_size:  Vec2,
	world_size: Vec2,
	grid_size:  [2]int,
}

// TODO handle resize (update rows)
// TODO update on dist changed
create_spatial :: proc(world_size: Vec2, dist_max: f32, preferred_ratio: f32) -> SpatialIndex {
	// world_size should always be a multiple of tile_size, otherwise weird things happen at the borders
	preferred := dist_max * preferred_ratio
	fits: = world_size / preferred
	tile_size := world_size / fits
	return SpatialIndex {
		tile_size = tile_size,
		grid_size = {
			int(math.ceil(world_size.x / tile_size.x)),
			int(math.ceil(world_size.y / tile_size.y)),
		},
		world_size = world_size,
	}
	// leaks initial array memory??
}

spatial_pos :: proc(spatial: SpatialIndex, pos: Vec2, wraparound: bool = true) -> PosGrid {
	pos := pos
	if wraparound {
		wrap_position(&pos, spatial.world_size)
	}
	row := int(math.floor(pos.x / spatial.tile_size.x))
	column := int(math.floor(pos.y / spatial.tile_size.y))

	return PosGrid{row, column}
}

spatial_pos_to_key :: proc(spatial: SpatialIndex, pos: PosGrid) -> int {
	assert(pos.x >= 0)
	assert(pos.x < spatial.grid_size.x)
	assert(pos.y >= 0)
	assert(pos.y < spatial.grid_size.y)
	return pos.y * spatial.grid_size.x + pos.x
}

spatial_rebuild :: proc(spatial: ^SpatialIndex, particles: [dynamic]Particle) {
	spatial.grid = make_dynamic_array_len(
		[dynamic][dynamic]int,
		spatial.grid_size.x * spatial.grid_size.y,
		allocator = context.temp_allocator,
	)
	for p, i in particles {
		key := spatial_pos_to_key(spatial^, spatial_pos(spatial^, p.pos))
		append(&spatial.grid[key], i)
	}
}

// IMPROV return tiles instead of single particles
// maybe can use some ideas form here: https://www.redblobgames.com/grids/circle-drawing/ ?
spatial_query :: proc(spatial: SpatialIndex, pos: Vec2, radius: f32, idx: int) -> [dynamic]int {
	result := make([dynamic]int, context.temp_allocator)

	corner1_unwrapped := spatial_pos(spatial, pos - {radius, radius}, false)
	corner2_unwrapped := spatial_pos(spatial, pos + {radius, radius}, false)
	diff := corner2_unwrapped - corner1_unwrapped
	corner_start := spatial_pos(spatial, pos - {radius, radius}) // IMPROV can cache with above

	// iterate grid indexes in range and wraparound
	for i := 0; i <= diff.x; i += 1 {
		x := corner_start.x + i
		if x >= spatial.grid_size.x do x -= spatial.grid_size.x
		for j := 0; j <= diff.y; j += 1 {
			y := corner_start.y + j
			if y >= spatial.grid_size.y do y -= spatial.grid_size.y

			key := spatial_pos_to_key(spatial, {x, y})
			append_elems(&result, ..spatial.grid[key][:])

			when _visual_debug {
				if idx == 0 {
					rl.DrawRectangleLinesEx(
						{
							f32(x) * spatial.tile_size.x,
							f32(y) * spatial.tile_size.y,
							spatial.tile_size.x,
							spatial.tile_size.y,
						},
						3,
						rl.SKYBLUE,
					)
				}
			}
		}
	}

	return result
}
