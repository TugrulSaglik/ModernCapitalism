# Releasing ModernCapitalism

Use Godot 4.7.2 and its matching Windows export templates. Set `GODOT` to the
console executable or pass `-Godot` explicitly. No personal machine path is required.

1. From the repository root, run an editor import (`godot --headless --editor
   --path . --quit`). For changes affecting release polish, run
   `tests/release_polish.gd` and `tests/release_polish_followup.gd` with
   `--headless --path . --script`. These tests use ignored test save directories.
   The release-polish pass recorded 292/292 and 7/7 checks; do not repeat completed
   suites without a relevant change. Historical wrappers, long integrations and
   balance matrices are not required for this packaging pass.
2. Use a bounded interactive check of context labels, property values,
   right-click clear/cancel, Escape menu, minimap and maximum zoom.
   Check the shared save browser with more than three saves, legacy saves and an
   incompatible file. Use `-- --save-dir=res://.godot/release-qa-saves` for
   disposable QA data; never delete real saves to test deletion. Completed
   acceptance need not be repeated before exporting unchanged code.
3. Run `git diff --check` and review source changes.
4. Run `./tools/export_windows.ps1 -Godot <executable> -Zip`. The script exports
   the Windows Desktop release preset into `dist/ModernCapitalism-Windows/`
   and creates `dist/ModernCapitalism-Windows.zip` when `-Zip` is supplied.
5. Start the exported executable and verify Title → Sandbox/Tutorial/Load/Settings.
   Keep its `.pck` beside the executable. The build needs no development tools.
6. Manually create a GitHub Release for the chosen tag and attach the ZIP.
   This repository does not publish releases automatically.

`dist/` is ignored. Source, export preset, and build script are tracked. Tests,
documentation, authoring scripts and debug scenes are excluded from the release
package. Saves are engine/catalog-specific: schema 22, catalog 13, save format 2;
older schema/catalog saves are rejected rather than silently migrated. Application
preferences are stored independently in `user://settings.cfg`.

The shared Title/Game Menu browser discovers user-managed `.json` saves in
`user://saves/`, newest first, without a fixed slot limit. Safe generated filenames
are independent of editable names. Optional label/timestamp metadata keeps save
format 2 compatible with existing `slot_1.json`, `slot_2.json` and `slot_3.json`
files of the supported engine/catalog/schema. Legacy files are not automatically
migrated or deleted. Invalid files stay visible with a reason and can be deleted,
but cannot be loaded. Overwrite and delete require confirmation; writes retain
the temporary-file replacement path. CityGenerator remains version 3.

If templates are missing, install the matching templates through Godot's export
template manager before step 4. A missing template is a build prerequisite, not a
reason to alter simulation or renderer settings.
