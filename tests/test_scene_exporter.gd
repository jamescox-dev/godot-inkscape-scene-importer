extends GutTest
## Tests exporter orchestration using doubles for external effects.

const SOURCE_PATH := "res://tests/tmp_importer_source.svg"
const SCENE_PATH := "res://tests/tmp_importer_source.tscn"
const ATLAS_PATH := "res://addons/inkscape_scene_importer/generated/test_doubles.png"


class FakeDocument extends InkscapeSvgDocument:
	func parse(source_path: String) -> bool:
		absolute_path = source_path
		error_message = ""
		var layer := SvgNode.new()
		layer.name = "g"
		layer.attrs = {"id": "layer", "inkscape:label": "Character"}
		var body := SvgNode.new()
		body.name = "g"
		body.attrs = {"id": "body", "inkscape:label": "Body"}
		body.parent = layer
		layer.children.append(body)
		root = layer
		character_layer = layer
		boundaries.append(body)
		return true

	func layer_name() -> String:
		return "Character"

	func serialize_without_nested_boundaries(_boundary) -> String:
		return "<svg/>"

	func get_pivot(_boundary, bbox: Rect2) -> Vector2:
		return bbox.position + bbox.size * 0.5

	func layer_pivot(bbox: Rect2) -> Vector2:
		return bbox.position + bbox.size * 0.5


class FakeRenderer extends InkscapeRenderer:
	var prepare_result := true
	var cleanup_count := 0

	func _init() -> void:
		super("fake")

	func prepare() -> bool:
		return prepare_result

	func query_bbox(_svg_path: String, _element_id: String) -> Rect2:
		return Rect2(0, 0, 8, 8)

	func render(_svg_text: String, _element_id: String, _index: int) -> Dictionary:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		return {
			"ok": true,
			"image": image,
			"bbox": Rect2(0, 0, 8, 8),
		}

	func cleanup() -> void:
		cleanup_count += 1


class FakeStore extends InkscapeAtlasStore:
	var saved_path := ""
	var texture: Texture2D

	func _init() -> void:
		super(InkscapeAtlasImporter.new())

	func save(_atlas: Image, resource_path: String, _mipmap_friendly: bool) -> Error:
		saved_path = resource_path
		return OK

	func load_texture(_resource_path: String) -> Texture2D:
		return texture


class FakeDependencies extends InkscapeExporterDependencies:
	var document: FakeDocument
	var renderer: FakeRenderer
	var store: FakeStore

	func create_document() -> InkscapeSvgDocument:
		return document

	func create_renderer(_executable: String) -> InkscapeRenderer:
		return renderer

	func create_atlas_store(_importer: InkscapeAtlasImporter) -> InkscapeAtlasStore:
		return store


var _dependencies: FakeDependencies


func before_each() -> void:
	var source := FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	source.store_string("<svg/>")
	source.close()

	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_dependencies = FakeDependencies.new()
	_dependencies.document = FakeDocument.new()
	_dependencies.renderer = FakeRenderer.new()
	_dependencies.store = FakeStore.new()
	_dependencies.store.texture = ImageTexture.create_from_image(image)


func after_each() -> void:
	for path in [SOURCE_PATH, SCENE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_export_writes_scene_and_cleans_up_renderer() -> void:
	var exporter := InkscapeSceneExporter.new(_dependencies)
	var result := exporter.export(
			ProjectSettings.globalize_path(SOURCE_PATH),
			"inkscape",
			ATLAS_PATH,
			2,
			false,
			InkscapeAtlasImporter.new(),
	)

	assert_true(result["ok"], str(result.get("message", "")))
	assert_eq(result["scene_path"], SCENE_PATH)
	assert_true(FileAccess.file_exists(SCENE_PATH))
	assert_eq(_dependencies.store.saved_path, ATLAS_PATH)
	assert_eq(_dependencies.renderer.cleanup_count, 1)


func test_export_rejects_missing_executable() -> void:
	var exporter := InkscapeSceneExporter.new(_dependencies)
	var result := exporter.export(
			ProjectSettings.globalize_path(SOURCE_PATH),
			"",
			ATLAS_PATH,
			2,
			false,
			InkscapeAtlasImporter.new(),
	)

	assert_false(result["ok"])
	assert_string_contains(result["message"], "not configured")
	assert_eq(_dependencies.renderer.cleanup_count, 0)
