@tool
class_name InkscapeSvgDocument
extends RefCounted
## Parses an SVG document and owns Inkscape-specific SVG semantics.

## Absolute filesystem path of the parsed SVG.
var absolute_path := ""

## Human-readable reason the last parse failed.
var error_message := ""

## Root element of the parsed SVG.
var root: SvgNode = null

## First Inkscape layer found in the document.
var character_layer: SvgNode = null

## Uppercase-labelled boundaries found below [member character_layer].
var boundaries: Array[SvgNode] = []


## Parses [param source_path] and populates this document.
func parse(source_path: String) -> bool:
	error_message = ""
	root = null
	character_layer = null
	boundaries.clear()

	if source_path.begins_with("res://"):
		absolute_path = ProjectSettings.globalize_path(source_path)
	else:
		absolute_path = source_path

	if not FileAccess.file_exists(absolute_path):
		error_message = "SVG file not found: " + absolute_path
		return false

	root = _parse_svg(absolute_path)
	if root == null:
		error_message = "Could not parse SVG."
		return false

	character_layer = _find_character_layer(root)
	if character_layer == null:
		error_message = (
				"No Inkscape layer found. Put the character inside a layer "
				+ "(inkscape:groupmode=\"layer\")."
		)
		return false

	_collect_boundaries(character_layer, boundaries)
	if boundaries.is_empty():
		error_message = "No uppercase-labelled export boundaries found."
		return false

	for boundary in boundaries:
		if boundary.id().is_empty():
			error_message = (
					"Every uppercase-labelled export boundary needs an SVG id."
			)
			return false

	return true


## Returns the root node name to use for the generated scene.
func layer_name() -> String:
	if character_layer != null and not character_layer.label().is_empty():
		return character_layer.label()
	return "Character"


## Serializes the document with nested boundaries removed from [param boundary].
##
## Nested boundaries are exported as their own sprites. Removing them here
## keeps the parent's rendered image from drawing those parts twice.
func serialize_without_nested_boundaries(boundary: SvgNode) -> String:
	var copy := _clone_without_nested_boundaries(root, boundary)
	var declaration := "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	return declaration + _serialize(copy)


## Converts an Inkscape transform centre into a scene-space pivot.
##
## [param bbox] must come from the unpruned document: Inkscape stores the
## transform-centre offsets relative to the complete object, including any
## nested boundaries. The stored Y axis points up, so it is flipped once.
func get_pivot(boundary: SvgNode, bbox: Rect2) -> Vector2:
	return _pivot_from_bbox(boundary.attrs, bbox)


## Returns the scene-space origin of the character layer.
##
## The layer centre is used when it has no `inkscape:transform-center-*`
## attributes. Children of the generated root are positioned relative to it.
func layer_pivot(bbox: Rect2) -> Vector2:
	if character_layer == null:
		return bbox.position + bbox.size * 0.5

	return _pivot_from_bbox(character_layer.attrs, bbox)


func _pivot_from_bbox(attrs: Dictionary, bbox: Rect2) -> Vector2:
	var center := bbox.position + bbox.size * 0.5
	var scale := _view_scale()
	var offset := Vector2(
			str(attrs.get("inkscape:transform-center-x", "0")).to_float() * scale,
			-str(attrs.get("inkscape:transform-center-y", "0")).to_float() * scale,
	)
	return center + offset


func _parse_svg(path: String) -> SvgNode:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		return null

	var stack: Array[SvgNode] = []
	var parsed_root: SvgNode
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node := SvgNode.new()
				node.name = parser.get_node_name()
				for i in parser.get_attribute_count():
					node.attrs[parser.get_attribute_name(i)] = (
							parser.get_attribute_value(i)
					)

				if stack.is_empty():
					parsed_root = node
				else:
					node.parent = stack.back()
					stack.back().children.append(node)

				if not parser.is_empty():
					stack.append(node)

			XMLParser.NODE_ELEMENT_END:
				if not stack.is_empty():
					stack.pop_back()

			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not stack.is_empty():
					stack.back().text += parser.get_node_data()

	return parsed_root


func _find_character_layer(node: SvgNode) -> SvgNode:
	if str(node.attrs.get("inkscape:groupmode", "")) == "layer":
		return node

	for child in node.children:
		var found := _find_character_layer(child)
		if found != null:
			return found

	return null


func _collect_boundaries(node: SvgNode, out: Array[SvgNode]) -> void:
	for child in node.children:
		if child.is_boundary():
			out.append(child)
		_collect_boundaries(child, out)


func _clone_without_nested_boundaries(source: SvgNode, boundary: SvgNode) -> SvgNode:
	var copy := SvgNode.new()
	copy.name = source.name
	copy.attrs = source.attrs.duplicate()
	copy.text = source.text

	var prune_children := source == boundary
	for child in source.children:
		if prune_children and child.is_boundary():
			continue
		var child_copy := _clone_without_nested_boundaries(child, boundary)
		child_copy.parent = copy
		copy.children.append(child_copy)

	return copy


func _serialize(node: SvgNode) -> String:
	var result := "<" + node.name
	for key in node.attrs:
		result += " %s=\"%s\"" % [str(key), _xml_escape(str(node.attrs[key]))]

	if node.children.is_empty() and node.text.is_empty():
		return result + "/>"

	result += ">" + _xml_escape(node.text)
	for child in node.children:
		result += _serialize(child)

	return result + "</" + node.name + ">"


func _xml_escape(value: String) -> String:
	var escaped := value.replace("&", "&amp;")
	escaped = escaped.replace("\"", "&quot;")
	escaped = escaped.replace("<", "&lt;")
	return escaped.replace(">", "&gt;")


func _view_scale() -> float:
	if root == null:
		return 1.0

	var width := str(root.attrs.get("width", "")).to_float()
	var height := str(root.attrs.get("height", "")).to_float()
	var view_box := str(root.attrs.get("viewBox", ""))
	var fields := view_box.replace(",", " ").split(" ", false)
	if width <= 0.0 or height <= 0.0 or fields.size() < 4:
		return 1.0

	var view_width := str(fields[2]).to_float()
	var view_height := str(fields[3]).to_float()
	if view_width <= 0.0 or view_height <= 0.0:
		return 1.0

	return minf(width / view_width, height / view_height)


## A single SVG element parsed from the source document.
class SvgNode:
	var name := ""
	var attrs: Dictionary = {}
	var children: Array = []
	var text := ""
	var parent: SvgNode


	## Returns this element's Inkscape label.
	func label() -> String:
		return str(attrs.get("inkscape:label", ""))


	## Returns this element's SVG id.
	func id() -> String:
		return str(attrs.get("id", ""))


	## Returns true when the label marks an export boundary.
	func is_boundary() -> bool:
		var value := label()
		if value.is_empty():
			return false

		var first := value[0]
		return first == first.to_upper() and first != first.to_lower()
