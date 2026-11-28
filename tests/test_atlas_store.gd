extends GutTest
## Tests atlas writes and import registration with a double importer.

const TEST_PATH := "user://gut_atlas_store.png"


class FakeImporter extends InkscapeAtlasImporter:
	var calls: Array = []
	var result: Error = OK

	func import_atlas(atlas_path: String, mipmap_friendly: bool) -> Error:
		calls.append([atlas_path, mipmap_friendly])
		return result


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _atlas() -> Image:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return image


func test_save_writes_png_and_registers_import() -> void:
	var importer := FakeImporter.new()
	var store := InkscapeAtlasStore.new(importer)

	assert_eq(store.save(_atlas(), TEST_PATH, true), OK)
	assert_true(FileAccess.file_exists(TEST_PATH))
	assert_eq(importer.calls.size(), 1)
	assert_eq(importer.calls[0][0], TEST_PATH)
	assert_eq(importer.calls[0][1], true)


func test_save_reports_import_failure() -> void:
	var importer := FakeImporter.new()
	importer.result = ERR_CANT_CREATE
	var store := InkscapeAtlasStore.new(importer)

	assert_eq(store.save(_atlas(), TEST_PATH, false), ERR_CANT_CREATE)
	assert_string_contains(store.error_message, "Could not import generated atlas")
