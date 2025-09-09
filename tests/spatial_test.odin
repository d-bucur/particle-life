package tests

import game "../source"
import "core:testing" // is this best way to import own code?

@(test)
example_test :: proc(t: ^testing.T) {
	n := 2 + 2

	// Check if `n` is the expected value of `4`.
	// If not, fail the test with the provided message.
	testing.expect(t, n == 4, "2 + 2 failed to equal 4.")
}

@(test)
spatial_key :: proc(t: ^testing.T) {
	using testing
	/* width: 3
    keys:
    0 1 2
    3 4 5
    6 7 8
    */
	game._scene.size = {9, 9}
	spatial := game.SpatialIndex {
		tile_width      = 3,
		tile_half_width = 1.5,
		row_size        = 3,
	}
	expect_value(t, game.spatial_pos_to_key(spatial, {0, 0}), 0)
	expect_value(t, game.spatial_pos_to_key(spatial, {0.5, 0.5}), 0)
	expect_value(t, game.spatial_pos_to_key(spatial, {3, 0}), 1)
	expect_value(t, game.spatial_pos_to_key(spatial, {8, 0}), 2)
	expect_value(t, game.spatial_pos_to_key(spatial, {0, 3}), 3)
	expect_value(t, game.spatial_pos_to_key(spatial, {7, 7}), 8)

	// MAYBE clamp values out of range?
	// testing.expect_value(t, game.spatial_pos_to_key(spatial, {-1, 0}), 0)
	// testing.expect_value(t, game.spatial_pos_to_key(spatial, {10, 0}), 2)

	// testing.expect_assert(t, "x > size.x")
	// game.spatial_pos_to_key({9, 0}, spatial)
	// testing.expect_assert(t, "y > size.y")
	// game.spatial_pos_to_key({0, 9}, spatial)
}

@(test)
wrap_position :: proc(t: ^testing.T) {
	t_wrap_pos :: proc(p: game.Vec2, size: game.Vec2) -> game.Vec2 {
		c := p
		game.wrap_position(&c, size)
		return c
	}
	using testing
	using game
	size := Vec2{100, 100}

	expect_value(t, t_wrap_pos({50, 50}, size), Vec2{50, 50})
	expect_value(t, t_wrap_pos({0, 0}, size), Vec2{0, 0})
	expect_value(t, t_wrap_pos({100, 0}, size), Vec2{0, 0})
	expect_value(t, t_wrap_pos({100, 100}, size), Vec2{0, 0})
	expect_value(t, t_wrap_pos({0, 100}, size), Vec2{0, 0})
	expect_value(t, t_wrap_pos({110, 0}, size), Vec2{10, 0})
	expect_value(t, t_wrap_pos({-10, 0}, size), Vec2{90, 0})
	expect_value(t, t_wrap_pos({0, 110}, size), Vec2{0, 10})
	expect_value(t, t_wrap_pos({0, -10}, size), Vec2{0, 90})
}
