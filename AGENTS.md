# Agent guide

## What this project is

A Godot 4 editor plugin that imports Inkscape SVG documents as `Sprite2D`
scenes with a generated atlas texture. This repository is also a small Godot
project containing a demo character and animation.

The code was developed with extensive use of AI agents. James Cox reviews the
work and takes responsibility for the published plugin.

## Repository layout

- `addons/inkscape_scene_importer/` — the publishable addon. Everything needed
  by users lives here, plus `plugin.cfg` and generated cache placeholders.
- `tests/` — GUT test suites for pure helpers and orchestration with doubles.
- `scripts/setup_testing.sh` — installs the pinned, dev-only GUT dependency.
- `character.svg`, `character.tscn`, `character_inherited.tscn`, `main.tscn` —
  demo source, generated scene, example animation, and demo scene.
- `.godot/` — Godot cache, ignored by Git. Temporary render files and imported
  atlases live here.
- `addons/inkscape_scene_importer/generated/` — generated atlas PNG sources,
  ignored by Git except for `.gitkeep`.

## Import pipeline

1. `plugin.gd` registers the global Inkscape executable setting and the import
   plugin. All addon scripts use `@tool` because they run in the editor.
2. `inkscape_scene_import_plugin.gd` supplies import options, creates an
   `InkscapeAtlasImporter` adapter, and calls the exporter. Only the import
   plugin may call `append_import_external_resource()`, so the adapter keeps
   that editor-only call in one place. It also registers the generated scene
   in `gen_files` so exports include it.
3. `inkscape_scene_exporter.gd` coordinates the stages: parse the SVG, query
   bounds and render each boundary with Inkscape, pack the atlas, write and
   import the atlas, build the scene, and save the `.tscn` sidecar. It obtains
   collaborators through `InkscapeExporterDependencies` so tests can supply
   doubles. All failure paths clean up renderer temporary files.
4. `inkscape_svg_document.gd` owns SVG parsing and Inkscape semantics.
   `inkscape_renderer.gd` runs Inkscape through `InkscapeProcessRunner` and
   caches `--query-all` results parsed by `inkscape_bbox_parser.gd`.
   `inkscape_atlas_layout.gd` plans rectangle placements;
   `inkscape_atlas_packer.gd` blits images into the atlas.
   `inkscape_sprite_layout.gd` computes sprite transforms;
   `inkscape_node_names.gd` sanitises labels; `inkscape_scene_builder.gd`
   creates the `Node2D`/`Sprite2D` hierarchy.
5. `inkscape_atlas_store.gd` writes the atlas PNG and loads the imported
   texture. The scene references the hidden `.ctex` in `.godot/imported/`.

## SVG conventions

- Artwork must be inside an Inkscape layer (`inkscape:groupmode="layer"`).
  The layer becomes the root `Node2D`.
- Groups or shapes with an uppercase `inkscape:label` become separate sprites.
  Each boundary needs an SVG `id`.
- Nested boundaries become child sprites and are pruned from the parent's
  rendered SVG so they are not drawn twice.
- Inkscape transform centres (`inkscape:transform-center-x` and `-y`) become
  sprite origins. The layer's transform centre offsets the generated root's
  children when present.
- Pivots use bounds from the unpruned document: Inkscape stores centres
  relative to the complete object.

## Important invariants

- Keep `@tool` on every script under `addons/inkscape_scene_importer/`.
- `importer_version` in committed `*.svg.import` files must match
  `_get_format_version()` in `inkscape_scene_import_plugin.gd`. It is `1` for
  the initial release. Bump it when the generated format changes incompatibly,
  then reimport example SVGs and commit refreshed `.import` metadata.
- Generated atlas PNGs under `addons/inkscape_scene_importer/generated/` must
  stay out of Git; `.godot/` is ignored too.
- New addon scripts need a `.uid` file committed alongside the `.gd` file;
  Godot generates it on the first editor scan.
- Follow the [Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):
  tabs, LF, two blank lines between functions/classes, lines under 100
  characters, trailing commas in multiline literals, documented public API,
  and Godot naming conventions.

## Tests

GUT is a dev-only dependency and is not shipped with the Asset Store addon.

```bash
./scripts/setup_testing.sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Use Godot 4.6 or newer. Tests prefer pure helpers and small doubles for the
process runner, atlas importer, and exporter dependencies; avoid monkey-patching
engine internals. Keep tests out of the release package.

## Release checklist

- Run the test suite and a headless editor import of `character.svg`.
- Confirm `plugin.cfg` version, README, and `LICENSE` are current.
- Confirm `importer_version` is `1` and the demo still plays.
- Confirm GUT is absent from the published addon package.
- Only rewrite or force-push history after the plugin has been verified.
