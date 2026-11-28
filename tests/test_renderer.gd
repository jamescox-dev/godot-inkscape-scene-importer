extends GutTest
## Tests renderer caching with a process double instead of launching Inkscape.


class FakeRunner extends InkscapeProcessRunner:
	var runs: Array[PackedStringArray] = []
	var query_output: Array = []

	func run(_executable: String, arguments: PackedStringArray) -> InkscapeProcessRunner.Result:
		runs.append(arguments)
		var result := InkscapeProcessRunner.Result.new()
		result.exit_code = 0
		result.output = query_output
		return result


func test_query_bbox_caches_query_all_per_file() -> void:
	var runner := FakeRunner.new()
	runner.query_output = ["body,10,20,30,40\n"]
	var renderer := InkscapeRenderer.new("inkscape", runner)

	assert_eq(renderer.query_bbox("/tmp/part.svg", "body"), Rect2(10, 20, 30, 40))
	assert_eq(renderer.query_bbox("/tmp/part.svg", "body"), Rect2(10, 20, 30, 40))
	assert_eq(runner.runs.size(), 1)


func test_unknown_id_returns_empty_rect() -> void:
	var runner := FakeRunner.new()
	runner.query_output = ["body,10,20,30,40\n"]
	var renderer := InkscapeRenderer.new("inkscape", runner)

	assert_eq(renderer.query_bbox("/tmp/part.svg", "missing"), Rect2())
