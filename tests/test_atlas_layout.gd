extends GutTest
## Tests the pure rectangle-packing logic without creating images.


func test_empty_input_fails() -> void:
	var sizes: Array[Vector2i] = []
	var result := InkscapeAtlasLayout.pack(sizes)

	assert_false(result.ok)
	assert_eq(result.message, "No rendered boundaries to pack.")


func test_negative_padding_fails() -> void:
	var sizes: Array[Vector2i] = [Vector2i(4, 4)]
	var result := InkscapeAtlasLayout.pack(sizes, -1)

	assert_false(result.ok)
	assert_eq(result.message, "Atlas padding cannot be negative.")


func test_empty_boundary_fails() -> void:
	var sizes: Array[Vector2i] = [Vector2i(0, 4)]
	var result := InkscapeAtlasLayout.pack(sizes)

	assert_false(result.ok)
	assert_eq(result.message, "Inkscape produced an empty boundary image.")


func test_simple_pack_applies_padding_and_wraps_rows() -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(6, 4),
		Vector2i(6, 4),
	]
	var result := InkscapeAtlasLayout.pack(sizes, 2)

	assert_true(result.ok, result.message)
	assert_eq(result.atlas_size, Vector2i(10, 14))
	assert_eq(result.placements.size(), 2)
	assert_eq(result.placements[0], Rect2i(2, 2, 6, 4))
	assert_eq(result.placements[1], Rect2i(2, 8, 6, 4))
	assert_eq(result.render_sizes, sizes)


func test_mipmap_pack_uses_power_of_two_regions() -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(3, 5),
		Vector2i(7, 3),
	]
	var result := InkscapeAtlasLayout.pack(sizes, 2, true)

	assert_true(result.ok, result.message)
	assert_eq(result.atlas_size, Vector2i(8, 16))
	assert_eq(result.placements[0], Rect2i(0, 0, 4, 8))
	assert_eq(result.placements[1], Rect2i(0, 12, 8, 4))


func test_boundary_larger_than_atlas_limit_fails() -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(InkscapeAtlasLayout.MAX_SIDE + 1, 1),
	]
	var result := InkscapeAtlasLayout.pack(sizes, 2, true)

	assert_false(result.ok)
	assert_string_contains(result.message, "atlas limit")


func test_next_pot_rounds_up() -> void:
	assert_eq(InkscapeAtlasLayout.next_pot(0), 1)
	assert_eq(InkscapeAtlasLayout.next_pot(3), 4)
	assert_eq(InkscapeAtlasLayout.next_pot(5), 8)
	assert_eq(InkscapeAtlasLayout.next_pot(16), 16)


func test_align_up_handles_invalid_alignment() -> void:
	assert_eq(InkscapeAtlasLayout.align_up(5, 4), 8)
	assert_eq(InkscapeAtlasLayout.align_up(5, 1), 5)
	assert_eq(InkscapeAtlasLayout.align_up(5, 0), 5)
