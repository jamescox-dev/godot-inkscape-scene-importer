@tool
class_name InkscapeNodeNames
extends RefCounted
## Converts SVG labels into names Godot accepts for nodes.

const INVALID_CHARACTERS := [
	".", ":", "@", "/", "\"", "\\",
]
const FALLBACK_SPRITE := "Sprite"


## Replaces invalid characters with underscores and applies [param fallback]
## when [param raw] is blank.
static func sanitize(raw: String, fallback: String) -> String:
	var node_name := raw.strip_edges()
	if node_name.is_empty():
		node_name = fallback

	for invalid in INVALID_CHARACTERS:
		node_name = node_name.replace(invalid, "_")

	if node_name.is_empty():
		return FALLBACK_SPRITE

	return node_name
