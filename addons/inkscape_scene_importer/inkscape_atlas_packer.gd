@tool
class_name InkscapeAtlasPacker
extends RefCounted
## Packs rendered boundary images into a single transparent atlas.
##
## Rectangle layout lives in [InkscapeAtlasLayout]; this class owns the images.

const DEFAULT_PADDING := 2
const MAX_SIDE := InkscapeAtlasLayout.MAX_SIDE


## Packs [param images] and returns the atlas, regions and original sizes.
##
## Each entry in `regions` is the atlas rectangle for the matching image.
## `render_sizes` keeps the unpadded image size for pivot and scale math.
static func pack(
	images: Array[Image],
	padding: int = DEFAULT_PADDING,
	mipmap_friendly: bool = false,
) -> Dictionary:
	var render_sizes: Array[Vector2i] = []
	for image in images:
		render_sizes.append(Vector2i(image.get_width(), image.get_height()))

	var layout := InkscapeAtlasLayout.pack(render_sizes, padding, mipmap_friendly)
	if not layout.ok:
		return _fail(layout.message)

	var atlas := Image.create(
			layout.atlas_size.x,
			layout.atlas_size.y,
			false,
			Image.FORMAT_RGBA8,
	)
	atlas.fill(Color(0, 0, 0, 0))

	for i in images.size():
		if mipmap_friendly:
			_blit_padded(atlas, images[i], render_sizes[i], layout.placements[i])
		else:
			atlas.blit_rect(
					images[i],
					Rect2i(Vector2i.ZERO, render_sizes[i]),
					layout.placements[i].position,
			)

	return {
		"ok": true,
		"image": atlas,
		"regions": layout.placements,
		"render_sizes": layout.render_sizes,
	}


static func _blit_padded(
	atlas: Image,
	image: Image,
	render_size: Vector2i,
	placement: Rect2i,
) -> void:
	var padded_size := Vector2i(
			InkscapeAtlasLayout.next_pot(render_size.x),
			InkscapeAtlasLayout.next_pot(render_size.y),
	)
	var padded := Image.create(
			padded_size.x,
			padded_size.y,
			false,
			Image.FORMAT_RGBA8,
	)
	padded.fill(Color(0, 0, 0, 0))
	padded.blit_rect(image, Rect2i(Vector2i.ZERO, render_size), Vector2i.ZERO)
	atlas.blit_rect(
			padded,
			Rect2i(Vector2i.ZERO, padded_size),
			placement.position,
	)


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
