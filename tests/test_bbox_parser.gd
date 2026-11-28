extends GutTest
## Tests parsing of `inkscape --query-all` output chunks.


func test_parses_ids_from_each_output_chunk() -> void:
	var output := [
		"layer,0,0,100,50\nbody,10,20,30,40",
		"warning from stderr\nhead,1,2,3,4\nmalformed,1,2",
	]
	var rows := InkscapeBboxParser.parse(output)

	assert_eq(rows.size(), 3)
	assert_eq(rows["layer"], Rect2(0, 0, 100, 50))
	assert_eq(rows["body"], Rect2(10, 20, 30, 40))
	assert_eq(rows["head"], Rect2(1, 2, 3, 4))


func test_empty_output_returns_no_rows() -> void:
	assert_eq(InkscapeBboxParser.parse([]).size(), 0)
