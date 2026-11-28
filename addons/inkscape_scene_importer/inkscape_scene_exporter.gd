@tool
class_name InkscapeSceneExporter
extends RefCounted
## Coordinates the importer's parse, render, pack and scene-build stages.

const SETTINGS := preload("res://addons/inkscape_scene_importer/inkscape_importer_settings.gd")

var _dependencies: InkscapeExporterDependencies


func _init(dependencies: InkscapeExporterDependencies = null) -> void:
	_dependencies = dependencies if dependencies != null else InkscapeExporterDependencies.new()


## Exports [param source_path] to a hidden PNG atlas and a `.tscn` sidecar.
##
## [param importer] adapts the editor-only atlas import step. The importer
## plugin supplies the real adapter; tests can supply a double.
##
## Returns a dictionary with `ok`, `message`, `atlas_path` and `scene_path`.
func export(
	source_path: String,
	executable: String,
	atlas_resource_path: String,
	padding: int,
	mipmap_friendly: bool,
	importer: InkscapeAtlasImporter,
) -> Dictionary:
	if executable.is_empty():
		return _fail(
				"Inkscape executable is not configured. Set "
				+ SETTINGS.EXECUTABLE
				+ " in Project Settings."
		)

	if not atlas_resource_path.begins_with("res://"):
		return _fail("The atlas path must be inside the project.")

	if importer == null:
		return _fail("The importer did not provide an atlas import adapter.")

	var document := _dependencies.create_document()
	if not document.parse(source_path):
		return _fail(document.error_message)

	var renderer := _dependencies.create_renderer(executable)
	if not renderer.prepare():
		return _fail(renderer.error_message)

	var layer_id := document.character_layer.id()
	if layer_id.is_empty():
		return _fail_with_cleanup(
				renderer,
				"The Inkscape layer needs an SVG id so its origin can be measured.",
		)

	var layer_bbox := renderer.query_bbox(document.absolute_path, layer_id)
	if layer_bbox.size.x <= 0.0 or layer_bbox.size.y <= 0.0:
		return _fail_with_cleanup(
				renderer,
				"Could not determine drawing bounds for the Inkscape layer.",
		)

	var layer_pivot := document.layer_pivot(layer_bbox)
	var rendered: Array[Dictionary] = []

	var boundaries: Array = document.boundaries
	for i in boundaries.size():
		var boundary = boundaries[i]
		var svg_text := document.serialize_without_nested_boundaries(boundary)
		var render_result := renderer.render(svg_text, boundary.id(), i)
		if not bool(render_result.get("ok", false)):
			return _fail_with_cleanup(
					renderer,
					str(render_result.get("message", "Inkscape render failed.")),
			)

		# The pruned SVG defines the rendered image bounds. Nested boundaries
		# are excluded so they do not affect sprite scale or texture offset.
		var bbox: Rect2 = render_result["bbox"]
		if bbox.size.x <= 0.0 or bbox.size.y <= 0.0:
			return _fail_with_cleanup(
					renderer,
					"Could not determine drawing bounds for '%s'." % boundary.label(),
			)

		# Inkscape's transform centre is relative to the complete object,
		# including nested boundaries, so query the original document here.
		var full_bbox := renderer.query_bbox(document.absolute_path, boundary.id())
		if full_bbox.size.x <= 0.0 or full_bbox.size.y <= 0.0:
			return _fail_with_cleanup(
					renderer,
					"Could not determine rotation bounds for '%s'." % boundary.label(),
			)

		rendered.append({
			"node": boundary,
			"image": render_result["image"],
			"bbox": bbox,
			"pivot": document.get_pivot(boundary, full_bbox),
		})

	var images: Array[Image] = []
	for item in rendered:
		images.append(item["image"])

	var packed := _dependencies.pack_images(images, padding, mipmap_friendly)
	if not bool(packed.get("ok", false)):
		return _fail_with_cleanup(
				renderer,
				str(packed.get("message", "Could not pack the atlas.")),
		)

	var atlas_image: Image = packed["image"]
	var regions: Array[Rect2i] = packed["regions"]
	var render_sizes: Array[Vector2i] = packed["render_sizes"]
	for i in rendered.size():
		rendered[i]["region"] = regions[i]
		rendered[i]["render_size"] = render_sizes[i]

	var scene_path := (
			ProjectSettings.localize_path(document.absolute_path.get_basename())
			+ ".tscn"
	)
	if not scene_path.begins_with("res://"):
		return _fail_with_cleanup(
				renderer,
				"The SVG must be inside the Godot project to generate resources.",
		)

	var store := _dependencies.create_atlas_store(importer)
	var save_error := store.save(atlas_image, atlas_resource_path, mipmap_friendly)
	if save_error != OK:
		var message := store.error_message
		if message.is_empty():
			message = "Could not prepare the generated atlas: %s" % error_string(save_error)
		return _fail_with_cleanup(renderer, message)

	# Loading by source path returns the imported CompressedTexture2D, whose
	# resource path points into .godot/imported. The generated scene therefore
	# references the hidden .ctex instead of a visible PNG sidecar.
	var atlas_texture := store.load_texture(atlas_resource_path)
	if atlas_texture == null:
		return _fail_with_cleanup(renderer, "Could not load the imported atlas texture.")

	var packed_scene := _dependencies.build_scene(
			document.layer_name(),
			document.character_layer,
			rendered,
			atlas_texture,
			mipmap_friendly,
			layer_pivot,
	)
	if packed_scene == null:
		return _fail_with_cleanup(renderer, "Could not pack the generated scene.")

	if ResourceSaver.save(packed_scene, scene_path) != OK:
		return _fail_with_cleanup(renderer, "Could not save the generated scene.")

	renderer.cleanup()
	return {
		"ok": true,
		"message": "Generated %s (%d sprites)." % [scene_path, rendered.size()],
		"atlas_path": atlas_resource_path,
		"scene_path": scene_path,
	}


func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}


func _fail_with_cleanup(renderer: InkscapeRenderer, message: String) -> Dictionary:
	renderer.cleanup()
	return _fail(message)
