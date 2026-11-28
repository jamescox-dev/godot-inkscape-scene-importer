@tool
extends EditorImportPlugin
## Editor import plugin for Inkscape SVG scenes.

const SETTINGS := preload("res://addons/inkscape_scene_importer/inkscape_importer_settings.gd")
const EXPORTER_SCRIPT := preload("res://addons/inkscape_scene_importer/inkscape_scene_exporter.gd")
## Generated atlases live inside the addon instead of beside the source SVG.
## Godot imports them to hidden .ctex files, so no visible PNG sidecar is kept.
const ATLAS_FOLDER := "res://addons/inkscape_scene_importer/generated"
const ERROR_PREFIX := "Inkscape Scene Importer: "


func _get_importer_name() -> String:
	return "inkscape_importer.scene"


func _get_visible_name() -> String:
	return "Inkscape Scene"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["svg"])


func _get_save_extension() -> String:
	return "scn"


func _get_resource_type() -> String:
	return "PackedScene"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "atlas/padding",
			"default_value": 2,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,32,1",
		},
		{
			"name": "atlas/mipmap_friendly",
			"default_value": false,
		},
	]


func _get_format_version() -> int:
	return 1


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	_platform_variants: Array[String],
	gen_files: Array[String],
) -> Error:
	var configured := ProjectSettings.get_setting(
			SETTINGS.EXECUTABLE,
			SETTINGS.DEFAULT_EXECUTABLE,
	)
	var executable := str(configured).strip_edges()
	if executable.is_empty():
		executable = SETTINGS.DEFAULT_EXECUTABLE

	var padding := clampi(int(options.get("atlas/padding", 2)), 0, 32)
	var mipmap_friendly := bool(options.get("atlas/mipmap_friendly", false))

	# Keep the source atlas inside the addon. The scene references the imported
	# .ctex, so no visible .png sidecar is left next to the SVG.
	var source_name := source_file.get_file().get_basename()
	if source_name.is_empty():
		source_name = "atlas"
	var atlas_path := ATLAS_FOLDER.path_join(source_name + ".png")

	var exporter = EXPORTER_SCRIPT.new()
	var atlas_importer := InkscapeAtlasImporter.new(Callable(self, "_import_atlas"))
	var result: Dictionary = exporter.export(
			source_file,
			executable,
			atlas_path,
			padding,
			mipmap_friendly,
			atlas_importer,
	)
	if not bool(result.get("ok", false)):
		push_error(ERROR_PREFIX + str(result.get("message", "Import failed.")))
		return ERR_CANT_CREATE

	var scene_path := str(result.get("scene_path", ""))
	if not scene_path.begins_with("res://"):
		push_error(ERROR_PREFIX + "Generated scene must be inside the project.")
		return ERR_INVALID_PARAMETER

	if not FileAccess.file_exists(scene_path):
		push_error(ERROR_PREFIX + "Expected generated .tscn file.")
		return ERR_FILE_NOT_FOUND

	# Register the scene as a generated resource so Godot tracks it as an
	# output of this SVG import and includes it in project exports.
	if not gen_files.has(scene_path):
		gen_files.append(scene_path)

	var generated_scene := ResourceLoader.load(
			scene_path,
			"PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE,
	) as PackedScene
	if generated_scene == null:
		push_error(ERROR_PREFIX + "Could not load generated scene: " + scene_path)
		return ERR_CANT_OPEN

	var output_path := save_path + "." + _get_save_extension()
	var save_error := ResourceSaver.save(generated_scene, output_path)
	if save_error != OK:
		push_error(
				ERROR_PREFIX
				+ "Could not save imported PackedScene: %s" % error_string(save_error)
		)
		return save_error

	return OK


## Imports the generated atlas from inside the importer callback.
##
## Only an [EditorImportPlugin] may call `append_import_external_resource()`, so
## the exporter reaches this method through [InkscapeAtlasImporter].
func _import_atlas(atlas_path: String, mipmap_friendly: bool) -> Error:
	# A PNG written during import is not in the filesystem database yet.
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.update_file(atlas_path.get_base_dir())
	filesystem.update_file(atlas_path)

	if mipmap_friendly:
		return append_import_external_resource(
				atlas_path,
				{"mipmaps/generate": true},
		)

	return append_import_external_resource(atlas_path)
