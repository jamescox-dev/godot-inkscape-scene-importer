@tool
class_name InkscapeAtlasStore
extends RefCounted
## Saves the generated atlas PNG and loads its imported texture.

## Human-readable reason the last save failed.
var error_message := ""

var _importer: InkscapeAtlasImporter


func _init(importer: InkscapeAtlasImporter) -> void:
	_importer = importer


## Writes [param atlas] to [param resource_path] and registers it for import.
func save(atlas: Image, resource_path: String, mipmap_friendly: bool) -> Error:
	error_message = ""
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		error_message = "Could not create the atlas cache directory."
		return ERR_CANT_CREATE

	if atlas.save_png(absolute_path) != OK:
		error_message = "Could not save atlas PNG."
		return ERR_CANT_CREATE

	var import_error := _importer.import_atlas(resource_path, mipmap_friendly)
	if import_error != OK:
		error_message = "Could not import generated atlas: %s" % error_string(import_error)

	return import_error


## Loads the imported texture referenced by the generated scene.
func load_texture(resource_path: String) -> Texture2D:
	return ResourceLoader.load(
			resource_path,
			"Texture2D",
			ResourceLoader.CACHE_MODE_IGNORE,
	) as Texture2D
