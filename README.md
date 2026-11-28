# Inkscape Scene Importer

A Godot 4 editor plugin that turns an Inkscape SVG document into a `Sprite2D`
scene and a packed atlas texture. Uppercase-labelled SVG objects become
independently animatable sprites whose origins use Inkscape's rotation centres.

> [!NOTE]
> This plugin was developed with extensive use of AI agents. It is maintained
> and released by James Cox, who takes responsibility for the published code.

## Features

- Imports SVG files as `PackedScene` resources via **Import as Inkscape Scene**.
- Generates a hidden atlas texture and one `AtlasTexture` per export boundary.
- Honours Inkscape layer/group hierarchy and rotation centres.
- Optional power-of-two, mipmap-friendly atlas packing.
- Configurable Atlas/Padding and Atlas/Mipmap Friendly import options.

## Requirements

- Godot 4.6+ (the demo project uses the GL Compatibility renderer).
- Inkscape installed on the host and available on `PATH`, or configured as an
  absolute path in Project Settings.

## Installation

### From the Godot Asset Library

Install **Inkscape Scene Importer** from the Asset Library, then enable it in
*Project → Project Settings → Plugins*.

### From source

Copy `addons/inkscape_scene_importer/` into your Godot project's `addons/`
folder, then enable **Inkscape Scene Importer** in
*Project → Project Settings → Plugins*.

After enabling the plugin, check *Project Settings → addons →
inkscape_scene_importer → inkscape_executable*. The default is `inkscape`,
which works when Inkscape is on `PATH`. Set an absolute path if it is not.

The import dock exposes two atlas options:

- **Atlas/Padding** — transparent gap between packed sprites (0–32, default 2).
- **Atlas/Mipmap Friendly** — pack on power-of-two boundaries and generate
  mipmaps (default off).

The importer format version is `1`. If you upgrade from an earlier development
build, reimport your SVG assets once (select the SVG in the FileSystem dock and
press **Reimport** in the Import dock).

## SVG conventions

- Put the artwork inside an Inkscape layer (`inkscape:groupmode="layer"`).
  The layer becomes the `Node2D` root of the generated scene.
- Every group or shape whose `inkscape:label` starts with an **uppercase**
  letter is exported as its own `Sprite2D`. Lowercase labels are not boundaries.
- Each boundary must have an SVG `id`.
- Nested boundaries become children of their containing boundary. The parent's
  rendered image excludes them, so the atlas does not draw them twice.
- Inkscape's rotation centre (`inkscape:transform-center-x` and
  `inkscape:transform-center-y`) becomes the `Sprite2D` origin. Animate
  `rotation` on those nodes to pose the character.
- The generated root `Node2D` stays at `(0, 0)`. Children are positioned
  relative to the layer's bounding-box centre plus the layer's own transform
  centre. Layers without a transform centre use the bounding-box centre.

## Generated output

The exporter writes `<svg-basename>.tscn` next to the source SVG. The atlas PNG
is kept inside `addons/inkscape_scene_importer/generated/` and imported by Godot
to a hidden `.ctex` under `.godot/imported/`; the generated scene references that
imported texture. Each boundary uses an `AtlasTexture` sub-resource and is
parented according to the SVG group hierarchy. The import plugin registers the
scene as a generated file so it travels with project exports.

With **Mipmap Friendly** enabled, each sprite is padded to a power-of-two size
and placed on a power-of-two aligned atlas coordinate. Padding is a minimum gap:
alignment may add transparent space. The atlas itself is power-of-two sized,
mipmaps are generated, and sprite textures use mipmapped filtering with
`filter_clip` enabled to avoid bleeding between regions.

Temporary render files live in a subdirectory of Godot's cache and are removed
after each import.

## Example

Open `main.tscn` and press Play. `character_inherited.tscn` shows how to add an
`AnimationPlayer` on top of the imported scene without editing the generated
scene itself. After upgrading the plugin, reimport `character.svg` once so Godot
picks up the new importer version and global executable setting.

## Development

The addon code follows the
[Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
Tests use GUT 9.6.1 as a dev-only dependency; it is not part of the published
addon package.

```bash
./scripts/setup_testing.sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

See `AGENTS.md` for the import pipeline, coding conventions, and release
checklist.

## License

MIT — see [LICENSE](LICENSE). The plugin was developed with extensive use of
AI agents and is maintained by James Cox.
