extends GutTest
## Tests Sprite2D transform calculations without building nodes.


func test_calculates_scale_offset_and_local_position() -> void:
	var layout := InkscapeSpriteLayout.calculate(
			Rect2(10, 20, 40, 30),
			Vector2(30, 35),
			Rect2i(2, 3, 8, 6),
			Vector2i(4, 3),
			Vector2(30, 35),
			Vector2.ONE,
	)

	assert_true(layout.scale.is_equal_approx(Vector2(10, 10)))
	assert_true(layout.offset.is_equal_approx(Vector2(2, 1.5)))
	assert_true(layout.position.is_equal_approx(Vector2.ZERO))


func test_accounts_for_parent_pivot_and_scale() -> void:
	var layout := InkscapeSpriteLayout.calculate(
			Rect2(0, 0, 20, 10),
			Vector2(30, 20),
			Rect2i(0, 0, 16, 8),
			Vector2i(10, 5),
			Vector2(10, 10),
			Vector2(2, 2),
	)

	assert_true(layout.scale.is_equal_approx(Vector2(2, 2)))
	assert_true(layout.offset.is_equal_approx(Vector2(-7, -6)))
	assert_true(layout.position.is_equal_approx(Vector2(10, 5)))


func test_zero_render_size_does_not_divide_by_zero() -> void:
	var layout := InkscapeSpriteLayout.calculate(
			Rect2(0, 0, 4, 4),
			Vector2(2, 2),
			Rect2i(0, 0, 4, 4),
			Vector2i.ZERO,
			Vector2(2, 2),
			Vector2.ONE,
	)

	assert_true(layout.scale.is_equal_approx(Vector2(4, 4)))
	assert_true(layout.position.is_equal_approx(Vector2.ZERO))
