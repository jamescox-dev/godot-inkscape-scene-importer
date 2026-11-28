extends GutTest
## Verifies that the packer blits images into the regions it plans.


func _solid_image(width: int, height: int, color: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func test_pack_blits_each_image_into_its_region() -> void:
	var images: Array[Image] = [
		_solid_image(4, 4, Color(1, 0, 0, 1)),
		_solid_image(4, 4, Color(0, 1, 0, 1)),
	]
	var result := InkscapeAtlasPacker.pack(images, 2)

	assert_true(result["ok"], str(result.get("message", "")))
	var atlas: Image = result["image"]
	var regions: Array[Rect2i] = result["regions"]
	assert_eq(regions.size(), 2)
	assert_true(atlas.get_pixelv(regions[0].position) == Color(1, 0, 0, 1))
	assert_true(atlas.get_pixelv(regions[1].position) == Color(0, 1, 0, 1))


func test_mipmap_pack_pads_images_to_power_of_two() -> void:
	var images: Array[Image] = [_solid_image(3, 3, Color(0, 0, 1, 1))]
	var result := InkscapeAtlasPacker.pack(images, 2, true)

	assert_true(result["ok"], str(result.get("message", "")))
	var atlas: Image = result["image"]
	var regions: Array[Rect2i] = result["regions"]
	assert_eq(atlas.get_size(), Vector2i(4, 4))
	assert_eq(regions[0].size, Vector2i(4, 4))
	assert_true(atlas.get_pixel(0, 0) == Color(0, 0, 1, 1))
	assert_true(atlas.get_pixel(3, 3) == Color(0, 0, 0, 0))


func test_pack_reports_layout_failures() -> void:
	var images: Array[Image] = []
	var result := InkscapeAtlasPacker.pack(images)

	assert_false(result["ok"])
	assert_eq(result["message"], "No rendered boundaries to pack.")
