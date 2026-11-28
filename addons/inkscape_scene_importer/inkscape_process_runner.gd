@tool
class_name InkscapeProcessRunner
extends RefCounted
## Runs external commands for the renderer.
##
## Isolating [OS.execute] lets tests supply results without launching Inkscape.


## Runs [param executable] with [param arguments] and captures both streams.
func run(executable: String, arguments: PackedStringArray) -> Result:
	var result := Result.new()
	result.exit_code = OS.execute(executable, arguments, result.output, true)
	return result


## Exit code and captured output of one process run.
class Result:
	var exit_code: int = -1
	var output: Array = []
