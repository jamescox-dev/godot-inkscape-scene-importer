@tool
extends EditorPlugin
## Registers the Inkscape Scene importer and its global settings.

const SETTINGS := preload("res://addons/inkscape_scene_importer/inkscape_importer_settings.gd")
const IMPORTER_SCRIPT := (
		preload("res://addons/inkscape_scene_importer/inkscape_scene_import_plugin.gd")
)

var importer: EditorImportPlugin


func _enter_tree() -> void:
	_register_setting()
	importer = IMPORTER_SCRIPT.new()
	add_import_plugin(importer)


func _exit_tree() -> void:
	if importer != null:
		remove_import_plugin(importer)
		importer = null


func _register_setting() -> void:
	var path := SETTINGS.EXECUTABLE
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, SETTINGS.DEFAULT_EXECUTABLE)

	ProjectSettings.set_initial_value(path, SETTINGS.DEFAULT_EXECUTABLE)
	ProjectSettings.add_property_info({
		"name": path,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": "",
	})
