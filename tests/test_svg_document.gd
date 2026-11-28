extends GutTest
## Tests SVG parsing and Inkscape conventions with temporary real files.

const TEST_PATH := "user://gut_svg_document.svg"


func _write_svg(lines: Array[String]) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _sample_svg() -> Array[String]:
	return [
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		"<svg xmlns=\"http://www.w3.org/2000/svg\" "
			+ "xmlns:inkscape=\"http://www.inkscape.org/namespaces/inkscape\" "
			+ "width=\"200\" height=\"100\" viewBox=\"0 0 100 50\">",
		"  <g id=\"layer\" inkscape:groupmode=\"layer\" inkscape:label=\"Hero\" "
			+ "inkscape:transform-center-x=\"10\" inkscape:transform-center-y=\"20\">",
		"    <g id=\"body\" inkscape:label=\"Body\">",
		"      <rect x=\"0\" y=\"0\" width=\"20\" height=\"20\"/>",
		"      <g id=\"eye\" inkscape:label=\"Eye\"><circle cx=\"5\" cy=\"5\" r=\"2\"/></g>",
		"    </g>",
		"    <g id=\"hat\" inkscape:label=\"Hat\"><rect x=\"0\" y=\"0\" width=\"10\" height=\"5\"/></g>",
		"  </g>",
		"</svg>",
	]


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_parse_collects_layer_and_boundaries() -> void:
	_write_svg(_sample_svg())
	var document := InkscapeSvgDocument.new()

	assert_true(document.parse(ProjectSettings.globalize_path(TEST_PATH)))
	assert_eq(document.root.name, "svg")
	assert_eq(document.character_layer.id(), "layer")
	assert_eq(document.boundaries.size(), 3)
	assert_eq(document.boundaries[0].id(), "body")
	assert_eq(document.boundaries[1].id(), "eye")
	assert_eq(document.boundaries[2].id(), "hat")
	assert_eq(document.layer_name(), "Hero")


func test_pivots_include_view_scale_and_transform_centre() -> void:
	_write_svg(_sample_svg())
	var document := InkscapeSvgDocument.new()
	assert_true(document.parse(ProjectSettings.globalize_path(TEST_PATH)))

	var bbox := Rect2(0, 0, 100, 50)
	var layer_pivot := document.layer_pivot(bbox)
	assert_true(layer_pivot.is_equal_approx(Vector2(70, -15)))

	var boundary_pivot := document.get_pivot(document.boundaries[0], bbox)
	assert_true(boundary_pivot.is_equal_approx(Vector2(50, 25)))


func test_serialization_prunes_nested_boundaries() -> void:
	_write_svg(_sample_svg())
	var document := InkscapeSvgDocument.new()
	assert_true(document.parse(ProjectSettings.globalize_path(TEST_PATH)))

	var serialized := document.serialize_without_nested_boundaries(document.boundaries[0])
	assert_true(serialized.begins_with("<?xml"))
	assert_false(serialized.contains("id=\"eye\""))
	assert_true(serialized.contains("id=\"hat\""))


func test_parse_resets_state_from_previous_document() -> void:
	_write_svg(_sample_svg())
	var document := InkscapeSvgDocument.new()
	assert_true(document.parse(ProjectSettings.globalize_path(TEST_PATH)))

	_write_svg(["<svg><g id=\"plain\"/></svg>"])
	assert_false(document.parse(ProjectSettings.globalize_path(TEST_PATH)))
	assert_eq(document.root.name, "svg")
	assert_null(document.character_layer)
	assert_eq(document.boundaries.size(), 0)
	assert_string_contains(document.error_message, "No Inkscape layer found")
