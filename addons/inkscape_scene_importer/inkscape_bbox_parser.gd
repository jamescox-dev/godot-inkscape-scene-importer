@tool
class_name InkscapeBboxParser
extends RefCounted
## Parses the output of `inkscape --query-all` into SVG id to bounds entries.
##
## stdout and stderr arrive as separate Array entries when the process runner
## reads both streams, so every chunk is scanned independently.


## Returns a dictionary mapping SVG ids to their [Rect2] bounds.
static func parse(output: Array) -> Dictionary:
	var rows: Dictionary = {}
	for chunk in output:
		for line in str(chunk).split("\n", false):
			var fields := line.strip_edges().split(",")
			if fields.size() < 5:
				continue

			rows[fields[0]] = Rect2(
					Vector2(fields[1].to_float(), fields[2].to_float()),
					Vector2(fields[3].to_float(), fields[4].to_float()),
			)

	return rows
