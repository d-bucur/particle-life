package game

import "core:fmt"
import "core:log"
import "core:math"

PosGrid :: distinct [2]int

SpatialIndex :: struct {
	grid:            [dynamic][dynamic]int, // each tile in the grid has a list of indices to the particle array
	tile_width:      f32,
	tile_half_width: f32,
	row_size:        int,
	col_size:        int,
}

// TODO handle resize (update rows)
create_spatial :: proc(size: Vec2, dist_max: f32) -> SpatialIndex {
	// TODO update on dist changed
	// IMPROV width should depend on attraction radius so only adjacent cells are checked
	width := dist_max
	return SpatialIndex {
		tile_width = width,
		tile_half_width = width / 2,
		row_size = int(math.ceil((size.x / width))),
		col_size = int(math.ceil(size.y / width)),
	}
	// leaks initial array memory??
	// resize(&spatial.grid, rows * columns)
}

spatial_pos :: #force_inline proc(spatial: SpatialIndex, pos: Vec2) -> PosGrid {
	// should clamp instead of assert
	assert(pos.x < _scene.size.x, "x >= size.x")
	assert(pos.y < _scene.size.y, "y >= size.y")
	row := int(math.floor(pos.x / spatial.tile_width))
	column := int(math.floor(pos.y / spatial.tile_width))
	return PosGrid{row, column}
}

spatial_pos_to_key :: #force_inline proc(spatial: SpatialIndex, pos: PosGrid) -> int {
	assert(pos.x >= 0)
	assert(pos.x < spatial.row_size)
	assert(pos.y >= 0)
	assert(pos.y < spatial.col_size)
	return pos.y * spatial.row_size + pos.x
}

spatial_pos_wraparound :: #force_inline proc(spatial: SpatialIndex, pos: PosGrid) -> PosGrid {
	pos := pos
	if pos.x < 0 do pos.x += spatial.row_size
	else if pos.x >= spatial.row_size do pos.x -= spatial.row_size
	if pos.y < 0 do pos.y += spatial.col_size
	else if pos.y >= spatial.col_size do pos.y -= spatial.col_size
	return pos
}

spatial_rebuild :: proc(spatial: ^SpatialIndex, particles: [dynamic]Particle) {
	spatial.grid = make_dynamic_array_len(
		[dynamic][dynamic]int,
		spatial.col_size * spatial.row_size,
		allocator = context.temp_allocator,
	)
	for p, i in particles {
		key := spatial_pos_to_key(spatial^, spatial_pos(spatial^, p.pos))
		append(&spatial.grid[key], i)
	}
}

spatial_query :: proc(spatial: SpatialIndex, pos: Vec2, radius: f32) -> [dynamic]int {
	result := make([dynamic]int, context.temp_allocator)
	base := spatial_pos(spatial, pos)
	for i in -1 ..= 1 {
		for j in -1 ..= 1 {
			pos := spatial_pos_wraparound(spatial, base + {i, j})
			key := spatial_pos_to_key(spatial, pos)
			append_elems(&result, ..spatial.grid[key][:])
		}
	}
	return result
}
