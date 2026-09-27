# Milestone 12 — Modes and complete-game production

Implementation is complete and the primary roadmap is marked complete. A Windows
binary was not produced: the single export attempt found no Godot 4.7.2 Windows
export templates. No template installation or export retry was attempted.

## Startup and modes

`project.godot` starts `scenes/title.tscn`. Title provides New Sandbox, Tutorial,
Load Game, Settings and Quit. Load reuses the shared dynamic SaveBrowser and enters
GameScreen with the restored session. The in-game menu retains save/load/settings
and adds confirmed Return to Title because unsaved progress may be lost.

Sandbox setup uses `SessionSetup`: company display name (stable ID `player`),
2012/2022, Relaxed/Standard/Competitive, numeric/randomized seed, seeded random
cities or exactly three unique manually selected real profiles, and starting
capital of $100,000/$200,000/$500,000/$1,000,000 (default $200,000). Profile names,
countries and reference populations are displayed; the first city is primary.
Starting capital changes only the root player company. Difficulty remains AI policy.

`TutorialController` contains ordered data definitions and simulation predicates.
GameScreen presents instructions and supplies observed navigation; it does not
implement a second economy. The fixed setup is 2022 Standard, seed 12022, Istanbul,
Sydney and Vancouver, Learning Company, and $1,000,000, initially paused.

1. Camera, pause and time controls.
2. Company overview and statements.
3. Select the existing retail facility.
4. Configure product sourcing.
5. Advance time and record a real retail sale.
6. Construct and operate production.
7. Build a warehouse and configure replenishment.
8. Assign R&D.
9. Fund advertising and build market presence.
10. Build headquarters and hire staff.
11. Develop or acquire property.
12. Perform regional trade and introduce corporate finance.

The panel supports previous explanations and skipping. Existing satisfied
prerequisites count; failed simulation commands do not satisfy action objectives.
Completion leaves ordinary gameplay available. Tutorial step, observations and
skip state persist through the shared session save system.

## Catalog and balancing

The final catalog has **68 products**, **18 facility archetypes**, **12 technologies**
and **15 categories**. New categories are materials, food, beverages, apparel,
furniture, personal care and automotive; existing electronics/appliance categories
remain. New products include steel, plastic, glass, rubber, chemicals, fabric,
lumber, paper, packaging, grain, flour, milk, coffee beans, bread, cereal, dairy
foods, snacks, pasta, biscuits, drinks, shirts, jeans, jackets, sneakers, chairs,
tables, sofas, beds, mattresses, cabinets, toiletries, compact cars, SUVs and EVs.

New archetypes: materials plant, food factory, textile factory, furniture factory,
personal/household goods plant, automobile factory, supermarket, clothing store,
furniture store and car dealership. Warehouse compatibility includes all products.
New technologies: materials, food processing, textile manufacturing, woodworking,
advanced materials, automotive and electric vehicles. Conventional vehicles are
available in 2012; EV capability opens in 2018 and is available at the 2022 start.

The existing generic demand, Local competition, manufacturing, retail, sourcing,
trade and AI compatibility paths handle these definitions. No per-product AI or
sector-specific management screen was introduced. Recipes leave positive margins
at reference input prices before overhead/freight; food and low-value inputs use
explicit cases/lots to fit integer logistics. Automotive production capacity is
two vehicles/day and dealership throughput three/day. Automotive category demand
was raised from 8 to 30 after a focused fixture exposed integer segment rounding
that prevented ordinary dealership sales. This is a catalog calibration, not a
new demand algorithm or a guarantee of profitability.

## Presentation and persistence

`AmbientDetails` batches body, pitched roof, chimney, door, windows, side glazing,
parapet, utility and awning components by kind/tone/orientation/detail. Roof metadata
controls ridge direction. Coordinate-based selection and generator geometry remain
unchanged; windows are MultiMesh instances rather than separate scene nodes.
Facilities retain ownership accents, with additional HQ, department-store and
automotive silhouettes. The compact toolbar expands usable city space and the
unused inspector no longer consumes a blank sidebar.

Six original synthesized PCM WAV cues cover click, success, rejection, construction,
research and tutorial completion. `UIService` centralizes playback and preferences;
`tools/generate_ui_audio.py` reproduces the assets without external samples.
`AppPreferences` stores master/UI volume, mute, 100/110/125% UI scale, high contrast
and tooltips in `user://settings.cfg`, outside saves. High contrast changes theme
separation, focus and placement colors while retaining textual placement feedback.

Final versions: **economy schema 22 / catalog 13 / save format 2 / CityGenerator 3**.
Economy already owns era, seed, difficulty, city identities, display name and opening
capital; the session does not duplicate those values. Save validation accepts the
configured player name/capital and strictly validates modes and tutorial state.
Older schema/catalog saves remain incompatible under the existing no-migration policy.

## Completed validation

- Small startup/catalog baseline passed, before and after catalog expansion.
- Original focused suite: **581 checks, zero failures**.
- Tutorial completed all 12 objectives in **19 simulation days**, with exact
  mid-course save/resume and valid accounting; remaining cash was $821,972.07.
- Sector fixtures passed for bread, shirt, chair and compact car. The real AI
  planner selected compatible retail and vertically integrated manufacturing;
  production, sourcing, sales, relevant research and invariants were exercised.
- Final 2022 Standard integration: **60 days**, Tokyo/New York/Hong Kong,
  **26 facilities**, player retail revenue **$216,193.25**, cash **$124,401.01**.
- Final 2012 Standard integration: **60 days**, Istanbul/New York/Athens,
  **25 facilities**, player retail revenue **$232,225.75**, cash **$431,091.86**.
- Both final integrations passed invariants, property/trade/finance checks, AI
  activity and exact day-59 save/load through day-60 continuation.
- Final rendered smoke completed with **zero capture failures**. On the 384×288
  Jakarta fixture, **1,372 ambient properties** used **367 detail batches**;
  the city scene contained approximately **736 descendant nodes**. No FPS claim
  was measured. Driver shader-cache write errors appeared, but captures succeeded.
- Existing `git diff --check` completed with no whitespace errors. It was not
  repeated during the final documentation continuation.

One later extension of the focused suite ran 591 checks and reported one failure:
`UI scale applies` compared the engine's floating-point property with exact equality.
The assertion now uses `is_equal_approx`; that assertion correction was not rerun,
in accordance with the continuation's no-rerun instruction. The original 581-check
pass is retained as evidence; this report does not claim a 591-check clean run.
The completed import encountered an editor-settings write restriction; subsequent
startup and final rendered runs parsed and executed the production scripts.
No historical regression, city-generation battery or multi-year soak was run.

## Final screenshots

All three final captures are **1280×800**, produced by the one permitted corrective
cycle and inspected together. No further render was performed in the continuation.

- [Gameplay city](images/city-gameplay.png): pitched house roofs, doors/windows,
  detailed tower facades, rooftop accents and factories are visible. The shortened
  toolbar leaves adequate city area and no giant blank inspector.
- [Sandbox setup](images/sandbox-setup.png): all required choices are legible,
  including the three city identities and starting capital.
- [Tutorial](images/tutorial.png): the compact guide and gameplay remain readable.

No visible UI clipping or horizontal overflow was found in these final captures.

## Repository and release preparation

README is a project front page with screenshots, features, modes, controls, running,
building and documentation links. `DEVELOPMENT_HISTORY.md` preserves the former
README and detailed roadmap checkpoints. `ROADMAP.md` marks the primary work
complete and separates optional extensions. `RELEASING.md` documents validation,
Windows export, ZIP packaging and manual GitHub Release publication.

`export_presets.cfg` targets Windows x86_64 release output. The overridable
`tools/export_windows.ps1` creates `dist/`, exports and optionally ZIPs the build.
Generated binaries remain ignored. Missing Godot 4.7.2 export templates blocked
the single export attempt, so executable startup could not be verified. No binary,
release, branch or commit was created.

Substantial source changes are in the catalog, GameSession/SaveStore/SessionSetup,
title and game screens, TutorialController, AmbientDetails/CityView, UI theme,
AppPreferences/PreferencesPanel/UIService, audio assets, focused/sector/integration/
visual fixtures, project metadata, export configuration and documentation.

Manufacturer brand provenance, debt/taxes, traffic/transit, deeper AI personalities
and more art/audio remain optional future extensions, not unfinished core milestones.

## Final release-polish pass — September 2026

This closes presentation issues on the completed roadmap; it adds no simulation
systems. Context navigation now uses facility/product/company names and property
types with district display names. Property statistics use real-person population
units, and development quotes distinguish selected-cell value from the summed
cost of additional footprint cells. Public roads/water explain why they cannot
be purchased. Right click clears ordinary context or cancels placement; Escape
opens Game Menu. Controls text matches that policy.

The zoomed-out black band was caused by the orthographic camera staying too close
to its focus: foreground terrain crossed behind the camera/near plane. Camera
distance and far plane now scale with the map diagonal, and picking rays use the
same far distance. The minimap is a clipped overlay anchored inside the city
workspace. Wheel input respects gesture magnitude. Scrollbars have visible
tracks/thumbs, and the Game Menu no longer expands excessively on first opening.

Title and Game Menu share a dynamic save browser, with no fixed save-count cap.
It discovers JSON files in `user://saves/`, newest first. Generated safe filenames
are separate from editable label/timestamp metadata. Create, Rename, confirmed
Overwrite, Load and confirmed single-file Delete retain the existing temporary
write/replace behavior. Rename preserves authoritative session state. Compatible
legacy slot files remain discoverable/loadable without migration; incompatible
files remain visible with a reason, disabled Load and available Delete.

Validation performed for this pass:

- Startup/catalog baseline: 68 products.
- Focused release-polish suite: **292 checks, 0 failures**. This covers saves,
  labels/property output, input/modal handling and camera bounds/clipping on
  192×144, 300×240 and 384×288 maps, using disposable test saves.
- Targeted wheel/menu/scrollbar follow-up: **7 checks, 0 failures**.
- Computer Use: Title and in-game dynamic browsers, scrolling beyond three saves,
  named saves and all three legacy entries, legacy loading, Create/Rename/
  Overwrite and disposable-save deletion. Incompatible saves were visibly
  unloadable with Delete available. The final in-game Load check retained January
  23 at 4× while the browser was open and after returning to Game Menu.
- Computer Use: representative player/competitor facilities, unowned/owned
  properties, vacant parcel and regional port; readable labels/statistics and
  reconciled land costs; right-click clear/cancel and Escape menu. Maximum zoom,
  map edges/corners and minimap navigation showed no band cutting valid terrain.
- Final editor import completed with no script/parser errors. The sandbox could
  not save the editor's separate AppData preferences; this did not block import.

Economy schema **22**, Catalog **13**, Save format **2**, CityGenerator **3** remain
unchanged. No historical suites, long integrations or city-generation battery
were run for this polish pass. Broader UI-scale/tutorial/exported-build acceptance
was not repeated in this continuation. Windows export and GitHub packaging remain
a separate step; no export, commit, branch or publication was performed here.
