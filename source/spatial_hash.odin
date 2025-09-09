package game

import "core:fmt"
import "core:log"
import "core:math"

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

spatial_pos_to_key :: #force_inline proc(spatial: SpatialIndex, pos: Vec2) -> int {
	// should clamp instead of assert
	assert(pos.x < _scene.size.x, "x >= size.x")
	assert(pos.y < _scene.size.y, "y >= size.y")
	row := int(math.floor(pos.x / spatial.tile_width))
	column := int(math.floor(pos.y / spatial.tile_width))
	return column * spatial.row_size + row
}

spatial_rebuild :: proc(spatial: ^SpatialIndex, particles: [dynamic]Particle) {
	spatial.grid = make_dynamic_array_len(
		[dynamic][dynamic]int,
		spatial.col_size * spatial.row_size,
		allocator = context.temp_allocator,
	)
	for p, i in particles {
		key := spatial_pos_to_key(spatial^, p.pos)
		append(&spatial.grid[key], i)
	}
}

spatial_query :: proc(spatial: SpatialIndex, pos: Vec2, radius: f32) -> [dynamic]int {
	result := make([dynamic]int, context.temp_allocator)
	key := spatial_pos_to_key(spatial, pos)
	append_elems(&result, ..spatial.grid[key][:])
	return result
}

// TODO use grid/query
