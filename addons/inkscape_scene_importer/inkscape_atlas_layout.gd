@tool
class_name InkscapeAtlasLayout
extends RefCounted
## Pure rectangle-packing logic for generated atlases.
##
## This class only decides sizes and positions. [InkscapeAtlasPacker] owns the
## images and blits them into the returned rectangles.

const DEFAULT_PADDING := 2
const MAX_SIDE := 4096


## Packs [param render_sizes] and returns the atlas size and sprite regions.
static func pack(
	render_sizes: Array[Vector2i],
	padding: int = DEFAULT_PADDING,
	mipmap_friendly: bool = false,
) -> Result:
	if render_sizes.is_empty():
		return _fail("No rendered boundaries to pack.")

	if padding < 0:
		return _fail("Atlas padding cannot be negative.")

	var sizes: Array[Vector2i] = []
	var total_area := 0
	var max_width := 0
	for size in render_sizes:
		if size.x <= 0 or size.y <= 0:
			return _fail("Inkscape produced an empty boundary image.")

		sizes.append(size)
		total_area += (size.x + padding) * (size.y + padding)
		max_width = maxi(max_width, size.x)

	if mipmap_friendly:
		return _pack_mipmap_friendly(sizes, padding)

	return _pack_simple(sizes, padding, total_area, max_width)


## Returns the smallest power of two greater than or equal to [param value].
static func next_pot(value: int) -> int:
	var result := 1
	while result < value:
		result <<= 1

	return result


## Rounds [param value] up to the next multiple of [param alignment].
static func align_up(value: int, alignment: int) -> int:
	if alignment <= 1:
		return value

	return ceili(float(value) / float(alignment)) * alignment


static func _pack_simple(
	sizes: Array[Vector2i],
	padding: int,
	total_area: int,
	max_width: int,
) -> Result:
	var widths: Array[int] = []
	var heights: Array[int] = []
	for size in sizes:
		widths.append(size.x)
		heights.append(size.y)
		if size.x + padding * 2 > MAX_SIDE or size.y + padding * 2 > MAX_SIDE:
			return _fail(
				"A boundary exceeds the %d x %d atlas limit."
				% [MAX_SIDE, MAX_SIDE]
			)

	var minimum_width := max_width + padding * 2
	var estimated_width := int(ceil(sqrt(float(total_area))))
	var atlas_width := clampi(estimated_width, minimum_width, MAX_SIDE)

	var placements: Array[Rect2i] = []
	var x := padding
	var y := padding
	var row_height := 0
	for i in sizes.size():
		if x + widths[i] + padding > atlas_width:
			x = padding
			y += row_height + padding
			row_height = 0

		if y + heights[i] + padding > MAX_SIDE:
			return _fail(
				"Atlas exceeds %d x %d. Reduce source dimensions or split it."
				% [MAX_SIDE, MAX_SIDE]
			)

		placements.append(Rect2i(x, y, widths[i], heights[i]))
		x += widths[i] + padding
		row_height = maxi(row_height, heights[i])

	var atlas_height := y + row_height + padding
	return _success(Vector2i(atlas_width, atlas_height), placements, sizes)


## Packs power-of-two padded parts on power-of-two aligned coordinates.
static func _pack_mipmap_friendly(
	sizes: Array[Vector2i],
	padding: int,
) -> Result:
	var padded_sizes: Array[Vector2i] = []
	for size in sizes:
		var pot_width := next_pot(size.x)
		var pot_height := next_pot(size.y)
		if pot_width > MAX_SIDE or pot_height > MAX_SIDE:
			return _fail(
				"A boundary exceeds the %d x %d atlas limit."
				% [MAX_SIDE, MAX_SIDE]
			)

		padded_sizes.append(Vector2i(pot_width, pot_height))

	var longest_side := 0
	var total_padded_area := 0
	for size in padded_sizes:
		longest_side = maxi(longest_side, maxi(size.x, size.y))
		total_padded_area += size.x * size.y

	var estimated_width := int(ceil(sqrt(float(total_padded_area))))
	var atlas_width := next_pot(maxi(estimated_width, longest_side))
	if atlas_width > MAX_SIDE:
		atlas_width = MAX_SIDE

	var placements: Array[Rect2i] = []
	var x := 0
	var y := 0
	var row_height := 0
	for i in padded_sizes.size():
		var width: int = padded_sizes[i].x
		var height: int = padded_sizes[i].y
		var aligned_x := align_up(x, width)
		var aligned_y := align_up(y, height)

		if aligned_x + width > atlas_width:
			x = 0
			y += row_height + padding
			row_height = 0
			aligned_x = align_up(x, width)
			aligned_y = align_up(y, height)

		if aligned_y + height > MAX_SIDE:
			return _fail(
				"Atlas exceeds %d x %d. Reduce source dimensions or split it."
				% [MAX_SIDE, MAX_SIDE]
			)

		placements.append(Rect2i(aligned_x, aligned_y, width, height))
		x = aligned_x + width + padding
		row_height = maxi(row_height, aligned_y + height - y)

	var atlas_height := next_pot(y + row_height)
	if atlas_height > MAX_SIDE:
		return _fail(
			"Atlas exceeds %d x %d. Reduce source dimensions or split it."
			% [MAX_SIDE, MAX_SIDE]
		)

	return _success(Vector2i(atlas_width, atlas_height), placements, sizes)


static func _success(
	atlas_size: Vector2i,
	placements: Array[Rect2i],
	render_sizes: Array[Vector2i],
) -> Result:
	var result := Result.new()
	result.ok = true
	result.atlas_size = atlas_size
	result.placements = placements
	result.render_sizes = render_sizes
	return result


static func _fail(message: String) -> Result:
	var result := Result.new()
	result.ok = false
	result.message = message
	return result


## Result of a packing attempt.
class Result:
	var ok: bool = false
	var message: String = ""
	var atlas_size: Vector2i = Vector2i.ZERO
	var placements: Array[Rect2i] = []
	var render_sizes: Array[Vector2i] = []
