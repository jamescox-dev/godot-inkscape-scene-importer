@tool
class_name InkscapeExporterDependencies
extends RefCounted
## Creates the collaborators used by [InkscapeSceneExporter].
##
## Tests can extend this class to replace external effects with doubles.


func create_document() -> InkscapeSvgDocument:
	return InkscapeSvgDocument.new()


func create_renderer(executable: String) -> InkscapeRenderer:
	return InkscapeRenderer.new(executable)


func create_atlas_store(importer: InkscapeAtlasImporter) -> InkscapeAtlasStore:
	return InkscapeAtlasStore.new(importer)


func pack_images(
	images: Array[Image],
	padding: int,
	mipmap_friendly: bool,
) -> Dictionary:
	return InkscapeAtlasPacker.pack(images, padding, mipmap_friendly)


func build_scene(
	root_name: String,
	layer,
	rendered: Array[Dictionary],
	atlas: Texture2D,
	mipmap_friendly: bool,
	layer_pivot: Vector2,
) -> PackedScene:
	return InkscapeSceneBuilder.build(
			root_name,
			layer,
			rendered,
			atlas,
			mipmap_friendly,
			layer_pivot,
	)
