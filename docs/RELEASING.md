# Releasing ModernCapitalism

Use Godot 4.7.2 and its matching Windows export templates. Set `GODOT` to the
console executable or pass `-Godot` explicitly. No personal machine path is required.

1. From the repository root, run an editor import (`godot --headless --editor
   --path . --quit`), `tests/milestone12_tests.gd`, and
   `tests/milestone12_integration.gd` with `--headless --path . --script`.
   The integration fixture runs exactly two 60-day scenarios. Do not substitute
   the historical regression wrappers or long balance matrices.
2. Run `godot --path . --script res://tests/milestone12_visual.gd` for the three
   1280×800 captures. Inspect them together; use at most one corrective capture.
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

If templates are missing, install the matching templates through Godot's export
template manager before step 4. A missing template is a build prerequisite, not a
reason to alter simulation or renderer settings.
