@tool
class_name InkscapeSceneBuilder
extends RefCounted
## Builds a Godot scene tree from rendered SVG boundaries.


## Builds and packs a scene from the rendered boundary data.
##
## Each item in [param rendered] must contain `node`, `image`, `bbox`, `pivot`,
## `region` and `render_size` keys. The root stays at the origin;
## [param layer_pivot] becomes the frame of reference for its children.
##
## Returns `null` if the tree cannot be packed.
static func build(
	root_name: String,
	layer,
	rendered: Array[Dictionary],
	atlas: Texture2D,
	mipmap_friendly: bool,
	layer_pivot: Vector2,
) -> PackedScene:
	var atlas_textures: Array[AtlasTexture] = []
	var by_id: Dictionary = {}

	for i in rendered.size():
		var region: Rect2i = rendered[i]["region"]
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = atlas
		atlas_texture.region = Rect2(
				region.position.x,
				region.position.y,
				region.size.x,
				region.size.y,
		)
		atlas_texture.filter_clip = mipmap_friendly
		atlas_textures.append(atlas_texture)

	for i in rendered.size():
		var boundary = rendered[i]["node"]
		by_id[boundary.id()] = i

	var context := BuildContext.new()
	context.rendered = rendered
	context.atlas_textures = atlas_textures
	context.by_id = by_id
	context.mipmap_friendly = mipmap_friendly

	var root := Node2D.new()
	root.name = InkscapeNodeNames.sanitize(root_name, "Character")
	_add_children(layer, root, root, layer_pivot, Vector2.ONE, context)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	root.free()
	if pack_error != OK:
		return null

	return packed_scene


static func _add_children(
	parent_node,
	parent_object: Node2D,
	scene_owner: Node,
	parent_pivot: Vector2,
	parent_global_scale: Vector2,
	context: BuildContext,
) -> void:
	for child in parent_node.children:
		if not context.by_id.has(child.id()):
			_add_children(
					child,
					parent_object,
					scene_owner,
					parent_pivot,
					parent_global_scale,
					context,
			)
			continue

		var index: int = context.by_id[child.id()]
		var item: Dictionary = context.rendered[index]
		var layout := InkscapeSpriteLayout.calculate(
				item["bbox"],
				item["pivot"],
				item["region"],
				item["render_size"],
				parent_pivot,
				parent_global_scale,
		)

		var sprite := Sprite2D.new()
		sprite.name = InkscapeNodeNames.sanitize(child.label(), child.id())
		sprite.texture = context.atlas_textures[index]
		sprite.position = layout.position
		sprite.offset = layout.offset
		sprite.scale = layout.scale
		if context.mipmap_friendly:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

		parent_object.add_child(sprite)
		sprite.owner = scene_owner

		# The node origin is the SVG pivot, so descendants position themselves
		# relative to it in document coordinates.
		_add_children(
				child,
				sprite,
				scene_owner,
				item["pivot"],
				parent_global_scale * layout.scale,
				context,
		)


## Shared data passed down the SVG hierarchy while building nodes.
class BuildContext:
	var rendered: Array[Dictionary] = []
	var atlas_textures: Array[AtlasTexture] = []
	var by_id: Dictionary = {}
	var mipmap_friendly: bool = false
