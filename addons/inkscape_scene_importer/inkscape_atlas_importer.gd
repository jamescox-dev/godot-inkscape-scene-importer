@tool
class_name InkscapeAtlasImporter
extends RefCounted
## Adapts editor-only atlas import registration for the exporter.
##
## The import plugin supplies a callback because only an [EditorImportPlugin]
## may call `append_import_external_resource()`. Tests can supply a double.

var _callback: Callable


func _init(callback: Callable = Callable()) -> void:
	_callback = callback


## Registers the generated atlas PNG with Godot's importer.
func import_atlas(atlas_path: String, mipmap_friendly: bool) -> Error:
	if not _callback.is_valid():
		return ERR_UNAVAILABLE

	var result: Error = _callback.call(atlas_path, mipmap_friendly)
	return result
