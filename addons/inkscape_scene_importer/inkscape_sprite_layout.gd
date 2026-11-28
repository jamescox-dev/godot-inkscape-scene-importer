@tool
class_name InkscapeSpriteLayout
extends RefCounted
## Computes Sprite2D transforms for exported SVG boundaries.
##
## Keeping the transform math separate from scene construction makes it
## possible to test placement and scaling without building Godot nodes.

const EPSILON := 0.000001


## Returns the scale, offset and local position for one exported boundary.
##
## [param atlas_region] may be power-of-two padded in mipmap mode, while
## [param render_size] is the dimensions of the original rendered image.
static func calculate(
	boundary_bbox: Rect2,
	boundary_pivot: Vector2,
	atlas_region: Rect2i,
	render_size: Vector2i,
	parent_pivot: Vector2,
	parent_global_scale: Vector2,
) -> Result:
	# The raster bounds can be fractional while PNG dimensions are integral.
	# Scale against the original render size so the artwork keeps its size.
	var scale := Vector2(
		boundary_bbox.size.x / maxf(float(render_size.x), 1.0),
		boundary_bbox.size.y / maxf(float(render_size.y), 1.0),
	)
	var offset := Vector2(
		float(atlas_region.size.x) * 0.5
			+ (boundary_bbox.position.x - boundary_pivot.x) / maxf(scale.x, EPSILON),
		float(atlas_region.size.y) * 0.5
			+ (boundary_bbox.position.y - boundary_pivot.y) / maxf(scale.y, EPSILON),
	)
	var position := Vector2(
		(boundary_pivot.x - parent_pivot.x) / maxf(parent_global_scale.x, EPSILON),
		(boundary_pivot.y - parent_pivot.y) / maxf(parent_global_scale.y, EPSILON),
	)

	var result := Result.new()
	result.scale = scale
	result.offset = offset
	result.position = position
	return result


## Transform values applied to one generated Sprite2D.
class Result:
	var scale: Vector2 = Vector2.ONE
	var offset: Vector2 = Vector2.ZERO
	var position: Vector2 = Vector2.ZERO
