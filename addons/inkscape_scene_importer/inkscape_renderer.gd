@tool
class_name InkscapeRenderer
extends RefCounted
## Runs Inkscape for the importer and caches bounding-box queries.

const SETTINGS := preload("res://addons/inkscape_scene_importer/inkscape_importer_settings.gd")
## Temporary render files live below the atlas folder so cleanup never removes
## the generated atlas PNG.
const CACHE_FOLDER := "inkscape_scene_importer/temp"

## Human-readable reason the last operation failed.
var error_message := ""

var _executable: String
var _temp_dir: String
var _query_cache: Dictionary = {}
var _temp_files: Array[String] = []
var _process_runner: InkscapeProcessRunner


func _init(executable: String, process_runner: InkscapeProcessRunner = null) -> void:
	_executable = executable.strip_edges()
	_temp_dir = ProjectSettings.globalize_path("res://.godot/" + CACHE_FOLDER)
	_process_runner = process_runner if process_runner != null else InkscapeProcessRunner.new()


## Prepares a clean cache directory and clears cached query results.
func prepare() -> bool:
	error_message = ""
	_query_cache.clear()
	_temp_files.clear()

	if _executable.is_empty():
		error_message = (
				"Inkscape executable is not configured. Set "
				+ SETTINGS.EXECUTABLE
				+ " in Project Settings."
		)
		return false

	if DirAccess.make_dir_recursive_absolute(_temp_dir) != OK:
		error_message = "Could not create Inkscape cache directory: " + _temp_dir
		return false

	var dir := DirAccess.open(_temp_dir)
	if dir == null:
		error_message = "Could not open Inkscape cache directory: " + _temp_dir
		return false

	for file_name in dir.get_files():
		dir.remove(file_name)

	return true


## Renders one pruned SVG and returns its image and bounding box.
func render(svg_text: String, element_id: String, index: int) -> Dictionary:
	var svg_path := _temp_dir.path_join("part_%03d.svg" % index)
	var png_path := _temp_dir.path_join("part_%03d.png" % index)

	var svg_file := FileAccess.open(svg_path, FileAccess.WRITE)
	if svg_file == null:
		error_message = "Could not write temporary SVG: " + svg_path
		return _fail(error_message)

	var declaration := "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	svg_file.store_string(declaration + svg_text)
	svg_file.close()
	_temp_files.append(svg_path)
	_temp_files.append(png_path)

	var arguments := PackedStringArray([
			"--export-id=" + element_id,
			"--export-id-only",
			"--export-area-drawing",
			"--export-background-opacity=0",
			"--export-filename=" + png_path,
			svg_path,
	])
	var process_result := _process_runner.run(_executable, arguments)
	if process_result.exit_code != 0 or not FileAccess.file_exists(png_path):
		error_message = (
				"Inkscape failed rendering '%s'. Check the executable path and SVG."
				% element_id
		)
		return _fail(error_message)

	var image := Image.load_from_file(png_path)
	if image == null or image.is_empty():
		error_message = "Inkscape produced an unreadable image for " + element_id
		return _fail(error_message)

	return {
		"ok": true,
		"image": image,
		"bbox": query_bbox(svg_path, element_id),
	}


## Returns the bounding box of [param element_id] in [param svg_path].
##
## `--query-all` is run at most once per file per import.
func query_bbox(svg_path: String, element_id: String) -> Rect2:
	if not _query_cache.has(svg_path):
		_query_cache[svg_path] = _query_all(svg_path)

	var rows: Dictionary = _query_cache[svg_path]
	if not rows.has(element_id):
		return Rect2()

	return rows[element_id]


## Removes temporary files created by this renderer.
func cleanup() -> void:
	for path in _temp_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	_temp_files.clear()
	DirAccess.remove_absolute(_temp_dir)


func _query_all(svg_path: String) -> Dictionary:
	var rows: Dictionary = {}
	var arguments := PackedStringArray(["--query-all", svg_path])
	var process_result := _process_runner.run(_executable, arguments)
	if process_result.exit_code != 0:
		return rows

	return InkscapeBboxParser.parse(process_result.output)


func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
