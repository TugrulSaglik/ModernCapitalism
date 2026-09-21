# Validation

## Milestone 1 baseline

Tested on Windows with Godot 4.7.2 stable, September 14, 2026. No external test
framework or runtime dependency was added.

## Automated coverage
The Godot-native harness checks inventory overdraw/negative requests and carrying
cost rounding; missing-input and cash-limited production; exact input/output and
capitalization; repeated production capacity limits; wholesale goods/cash
conservation; retail inventory/revenue/COGS; overhead; same-owner book transfers;
unaffordable/cross-city trades; price and quality demand direction; competition
and stockouts; public technology era/date gates; leap calendar; command timing,
ownership and price validation; snapshot detachment; identical same-seed/action
states every day and different-seed demand; continuous accounting invariants;
sustained sales and AI price decisions.

Result: **1,524 checks, zero failures**, including 365 days per era for three
economies each (same-seed replay pair and different-seed control).

## Independent longer runs (seed 42)

| Starting era | Days | Next date | Consumer units | Consumer revenue |
| --- | ---: | --- | ---: | ---: |
| 2012 | 3,650 | 2021-12-29 | 103,236 | $30,391,197.21 |
| 2022 | 1,825 | 2026-12-31 | 64,618 | $20,668,012.79 |

Every day's cash/inventory/accounting invariants passed. All five firms retained
positive cash and cumulative profit. Last-day finished stocks remained bounded
by replenishment targets; every retail outlet remained active. The 2012 run
crossed the 2020 technology gate and sold eight advanced phones on the final day.
The 2022 run sold nine advanced phones on its final day. There was no negative
stock, negative cash, orphan carrying cost or balance-sheet drift.

## Project validation
Editor import completed with no GDScript parse errors. The graphical smoke runner
loaded the real main scene, advanced 30 days and exited successfully. Its rendered
1200×720 screenshot was inspected: controls and company/facility values fit and
the invariant status was OK. `git diff --check` passed.

The restricted host emits a Godot root-certificate-store startup error. Editor
settings and graphical shader caching also cannot write to the host's global
user directory in this sandbox. These are environment messages; local log paths
were used for execution. No simulation or UI script errors remain.

## Milestone 1 historical compromises
- Cash grows steadily because consumer spending comes from an external sector
  and no expansion/capital spending, taxes or household budgets exist yet. This
  validates operations, not a balanced complete-game macroeconomy.
- At the Milestone 1 checkpoint, stable first-supplier/first-buyer order favored
  Orion over Nova. Milestone 2 replaced first-supplier choice with ranked and
  manually selectable sourcing; sequential scarce-stock allocation remains.
- Wholesale delivery is instantaneous within one city; facilities do not yet
  have capital costs or spatial footprints.
- Components stand in for paid external resources. Recipe and public technology
  dates are illustrative; production quality is not propagated through lots.
- Technology gates are implemented; company research is planned. Quality is a
  fixed per-facility scalar, and AI only adjusts retail prices weekly.
- Snapshots are detached/versioned, but restore/migration/replay persistence is
  not implemented. Deterministic comparisons require matching engine/data.

At that checkpoint no later milestone had been implemented, and no commit or branch
was created.

## Milestone 2 validation

Finalized on Windows with Godot 4.7.2 stable, September 15, 2026. The complete
PowerShell harness imports the project and runs all foundation, Milestone 2,
management-game and legacy-debug entry points.

- Foundation harness: **1,524 checks, zero failures**.
- Milestone 2 harness: **809 checks, zero failures**. Coverage includes all time
  speeds and pause/resume, command validation and tick-boundary timing, observable
  price effects on sales, deterministic supplier ranking and manual selection,
  definition-order independence, exact save/load round trips, queued commands,
  transactional rejection of invalid saves, and 365-day deterministic continuation
  after loading in both starting eras.
- Management-game smoke: **15 checks, zero failures**. The real main scene covers
  continuous advancement and pause, facility price submission, wheel zoom, camera
  translation, physics-ray facility selection, rival read-only controls, HUD
  save/load, Settings/Debug unlock, Debug cash, 2012 era-lock presentation and
  tutorial Debug hiding.
- Legacy debug-scene smoke: loaded and advanced 30 days with clean invariants.

Independent seed-42 headless runs also completed **3,650 days in each era**, with
daily balance and inventory invariants checked after every tick:

| Starting era | Days | Next date | Consumer units | Consumer revenue |
| --- | ---: | --- | ---: | ---: |
| 2012 | 3,650 | 2021-12-29 | 103,236 | $30,391,197.21 |
| 2022 | 3,650 | 2031-12-30 | 129,466 | $41,369,506.79 |

The 2012 run crossed the 2020 public technology gate without special era code.
Both runs ended with nonnegative company cash. A non-headless OpenGL run loaded
the real game scene, passed all 15 smoke checks and produced an inspected 1280×800
frame with the city, HUD and facility-management panel visible without clipping.
`git diff --check` passes; only the host root-certificate-store warning remains.

## Current compromises and deferred work

- Supplier offers are ranked fairly, but scarce wholesale stock is still allocated
  sequentially by stable buyer/facility order rather than through market clearing.
- Milestone 3 adds construction, placement, roads and warehouse buildings.
  Warehouse operations, shipments, lead times and transport costs remain deferred.
- Saves deliberately require the same format, schema, engine and catalog hash.
  No migration path or user-facing save browser exists yet.
- Debug unlock is a local development convenience, not a security boundary. Its
  effects are audited and saved; session access itself is always relocked on load.
- The original simplified economy still has external consumer funds, no household
  budgets, fixed quality, no active company research and only weekly retail-price AI.

Milestone 2 was finalized without creating a commit or branch.

## Milestone 3 validation

Validated on Windows / Godot 4.7.2, September 16, 2026. Git was clean before edits;
history and all project documentation were inspected. No branch or commit was made.
No Computer Use, external art, dependency or visible-editor automation was used.

### Baseline and complete regression results

| Suite | Before changes | Milestone 3 |
| --- | ---: | ---: |
| Foundation | 1,524 / 0 failures | 1,524 / 0 failures |
| Milestone 2 | 809 / 0 failures | 809 / 0 failures |
| Existing game smoke | 15 / 0 failures | 15 / 0 failures |
| Legacy debug smoke | Passed 30-day flow | Passed 30-day flow |
| Milestone 3 simulation | — | 7,410 / 0 failures |
| Construction smoke, headless | — | 18 / 0 failures |
| Construction smoke, rendered | — | 26 / 0 failures, including 8 PNG writes |

The complete `tests/run_tests.ps1` imports and runs all six headless entry points.
New tests cover deterministic/detached city serialization; every archetype;
bounds, roads/access, overlap, wrong city, unsupported products, era gates,
noninteger coordinates, insufficient cash and forged ownership; construction cost
and account invariants; real retail sourcing/sales; warehouse role; FIFO conflicts;
paused timing; suspension; demolition/inventory loss; supplier cleanup; stable IDs;
rebuilding freed land; exact saves with dynamic facilities and pending commands;
corrupt city rejection; replay and post-load long-run continuation. Existing Debug
unlock/cash controls are preserved and used in the new tests.

### Long runs with constructed businesses

Each era has a replay pair: construct a retailer, component plant and warehouse,
demolish the warehouse, modify retail price, save/load one copy and run 3,650 days.
Both copies check cash/inventory/account invariants every day, compare full state
annually and at completion, and finish identically.

| Era | Days per copy | Final date | Consumer units | Revenue, cents |
| --- | ---: | --- | ---: | ---: |
| 2012 | 3,650 | 2021-12-29 | 115,350 | 3,493,052,102 |
| 2022 | 3,650 | 2031-12-30 | 141,530 | 4,589,243,489 |

The new exact-load test exposed JSON rounding of floating-point market ratios;
format 2 now preserves their binary values in tagged records. Integer and RNG
precision protections remain. Schema 3 validates reconstructed city occupancy and
all dynamic facilities before replacing the live session. Old saves are rejected.

### Repeatable graphical validation

Run from the project root using the installed Godot console executable:

```powershell
& $godot --path . --log-file .godot/m3-visual.log --script res://tests/construction_smoke.gd
```

The harness loads the real main scene, pauses 2022, opens Build, chooses retail,
projects synthetic cursor motion onto invalid and valid ground, clicks placement,
checks cash/state/selection, ray-selects the built facility, changes price, builds
an assembly factory and warehouse, saves, confirms demolition, loads, compares
exact state, demolishes again, and repeats retail construction in 2012. It also
checks cancellation and the 2012 product menu. Headless mode runs the same actions
without image capture. Rendered mode uses `frame_post_draw` and viewport texture
capture, writing ignored artifacts to `.godot/m3-screenshots/`:

1. `01-overview.png`
2. `02-selected-retail.png`
3. `03-selected-factory.png`
4. `04-preview-invalid.png`
5. `05-preview-valid.png`
6. `06-expanded-city.png`
7. `07-after-demolition.png`
8. `08-city-2012.png`

Screenshots were directly inspected, then refined and recaptured. The first pass
had tiny labels, speckled cell seams and weak selection/ownership differentiation.
The refinement removed ground seams, enabled MSAA, enlarged selected-only labels,
added gold footprint outlines, tinted roofs by owner and unified the HUD background.
Warehouse text now states its passive role; demolition is near the operation button.
At 1280×800 the city fits, silhouettes differ, controls/preview reasons are readable,
and the scrollable inspector contains the longer sourcing list. The initial framing
leaves margin around the map for navigation; zoom reveals closer building detail.
These are procedural placeholders, not final art or a claim of final UI polish.

### Remaining limits

The map is fixed, flat and single-city; land is free, building orientation fixed,
construction instantaneous and costs expensed. Warehouses are passive placeholders
for operational logistics, with no transfer UI/capacity enforcement. Retail is
single-product using the existing small catalog. No HQ/R&D/advertising/stock-market
simulation, broader products, strategic AI, traffic, tutorial campaign or full
sandbox setup was added. Debug remains session-unlocked and relocks on load.
The host still reports its pre-existing root-certificate-store warning; no script
errors or failing assertions remain. `git diff --check` is part of final review.

### File inventory

New: `src/sim/city_map.gd`, `tests/milestone3_tests.gd`,
`tests/construction_smoke.gd`, and their Godot-generated `.uid` companions.

Modified: `src/sim/catalog.gd`, `src/sim/economy.gd`,
`src/session/game_session.gd`, `src/session/save_store.gd`,
`src/ui/city_view.gd`, `src/ui/game_screen.gd`, `src/ui/facility_panel.gd`,
`data/example_economy.json`, `tests/run_tests.ps1`, `README.md`, and existing
`docs/ARCHITECTURE.md`, `docs/ECONOMY.md`, `docs/GAME_DESIGN.md`,
`docs/TECHNOLOGY.md`, `docs/ROADMAP.md`, `docs/VALIDATION.md`.

Removed: `data/city_layout.json`; starting positions now belong to scenario data.
Main scene wiring remains unchanged and the existing tests were preserved.

## Milestone 4 final validation

Validated on Windows with Godot 4.7.2, September 16, 2026. The interrupted
worktree was preserved and inspected before fixes. No branch, commit, Computer
Use, external dependency or Milestone 5 work was added.

The complete `tests/run_tests.ps1` finished with zero failures: foundation
1,524 checks; Milestone 2 809; game smoke 15; legacy debug smoke passed;
Milestone 3 7,410; construction smoke headless 18; Milestone 4 7,394;
logistics smoke headless 38. The Milestone 3 construction/market fixture was
made independent of scarce upstream stock, which changed its expected timing
under explicit shipments.

Milestone 4 tests verify road-distance/freight quotes, nonzero delivery lead,
departure ownership and payment, in-transit assets, idempotent arrival,
unreachable-route rejection, warehouse capacity including inbound reservations,
owned transfers, factory input wait, replenishment accounting for incoming
goods, landed-cost/quality ranking and pinned suppliers. They also check
construction capitalization, daily depreciation, demolition book-value loss,
the fixed-asset balance invariant, current-month bars, TTM/calendar boundaries,
and corrupt-shipment rejection. Save/load with active shipments is exact; both
2012 and 2022 replay pairs then ran 3,650 days with daily invariant checks,
yearly state comparisons and identical final snapshots.

| Era | Days per replay copy | Final consumer units | Player freight, cents |
| --- | ---: | ---: | ---: |
| 2012 | 3,650 | 97,567 | 12,203,912 |
| 2022 | 3,650 | 116,619 | 12,279,002 |

The rendered `tests/logistics_smoke.gd` passed 44 checks and wrote six PNGs to
`.godot/m4-screenshots/`. It exercised factory → warehouse → retail transfers,
in-transit UI save/load, warehouse arrival, sales, monthly profit history,
middle-button drag, disabled WASD pan and dialog/text-focus input blocking.
The financial HUD, warehouse inspector and settings screenshots were inspected:
cash, TTM profit, monthly bars, shipment status, free capacity and controls fit
at 1280×800. Procedural city art remains a placeholder.

Current limits: route times are deterministic fixed quotes with no observed
supplier-reliability score, vehicles or traffic. One warehouse holds 100 total
units; its product targets share that capacity. Opening scenario buildings have
zero fixed-asset book value, while new construction depreciates over 3,650 days.
The aggregate ledger does not yet provide full statements, debt or taxes. The
host emitted its existing certificate-store warning and a rendered shader-cache
write warning; neither produced a script failure or failed assertion.

## Milestone 5 final validation

Validated September 19, 2026 on Windows / Godot 4.7.2. README, AGENTS, all design
documentation, Git history and the implementation were inspected before edits.
The starting working tree was clean. No Computer Use, branch, commit, external
dependency or new product catalog was introduced.

### Baseline and final regression

| Suite | Baseline checks | Final checks | Failures |
| --- | ---: | ---: | ---: |
| Foundation | 1,524 | 1,524 | 0 |
| Milestone 2 | 809 | 809 | 0 |
| Game smoke | 15 | 15 | 0 |
| Legacy debug smoke | 30-day flow | 30-day flow | 0 |
| Milestone 3 | 7,410 | 7,410 | 0 |
| Construction smoke, headless | 18 | 18 | 0 |
| Milestone 4 | 7,394 | 7,394 | 0 |
| Logistics smoke, headless | 38 | 38 | 0 |
| Milestone 5 | — | 28,093 | 0 |
| City smoke, headless | — | 17 | 0 |
| City smoke, rendered | — | 26 | 0 |

The complete PowerShell harness now includes the Milestone 5 and city smoke entry
points. Existing assertions were retained. Coordinate-specific historical tests
explicitly request the legacy board, preserving their exact route lengths, prices
and construction fixtures. The ordinary game smoke and new city suites use generated
cities. After the combined suite passed, two additional city checks (absence of old
layout data and transactional water rejection) were added and the city suite rerun.

Generated coverage includes seven seeds (0, 1, 2, 7, 42, 9173, 2147483647), a 60 × 42
configuration, invalid dimensions, exact same-seed equality, different coast/roads/
development/business positions, and a catalog without the legacy coordinate map.
Every occupied cell is checked for bounds, land, road exclusion and overlap.
Tests verify connected roads, valid frontage, room for every construction archetype,
stable ambient IDs, residential totals/capacities, district aggregation, bounded
land values and coast/road port interfaces. Corrupt terrain, road coordinates,
population, land values, ambient footprints/appearance, districts, port flags,
dimensions and economic plots are rejected.

Population tests cover increasing market size, zero/near-zero residents, purchasing
power, unchanged price/quality response and the actual daily economy reading city
population. Generated construction, demolition, real factory input sourcing,
factory → warehouse → retail shipments, freight/lead quotes, automatic targets,
saved active shipments, exact restoration and account/history invariants are covered.

### Long deterministic validation

Both eras have paired generated sessions with seed 42. They build a factory,
warehouse and retailer, run 30 days, dispatch real produced stock, save with active
shipments, load into a different-seed session, continue the transfer chain, replenish
the warehouse and build/demolish another store. They then advance 3,650 more days
per copy with daily accounting/inventory checks, annual full-state comparisons and
identical final snapshots.

| Era | Long-run days per copy | Residents | Final cumulative consumer units | Player freight, cents |
| --- | ---: | ---: | ---: | ---: |
| 2012 | 3,650 | 2,573 | 57,176 | 1,996,140 |
| 2022 | 3,650 | 2,573 | 69,694 | 1,996,040 |

These are fixture outcomes, including setup/transfer days, not a claim of completed
macroeconomic balancing. The 2012 run crosses the advanced-product availability date.
Historical Milestone 3 and 4 replay pairs also continue to run 3,650 days in both eras.

### Programmatic rendered workflow and inspection

Run:
```powershell
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . --log-file .godot/m5-visual.log --script res://tests/city_smoke.gd
```

The real game host is driven through session controls, synthetic ground-projected
mouse events, inspector price submission, HUD save/load, Settings/Debug and minimap
clicks. It checks known seed, generated population/coast, 30 days of actual trade,
legal construction and cost, management, exact save/load, monthly accounting, modal
camera blocking, same-seed reproduction, second-seed variation and 2012 gates.
Headless execution runs the same flow without PNG capture. Rendered capture waits
for frame_post_draw and writes viewport images to ignored .godot/m5-screenshots:

1. 01-overview.png — default inhabited coastal city, minimap and financial HUD.
2. 02-coastline.png — water, shoreline and waterfront business context.
3. 03-central-density.png — apartments, larger blocks, offices and businesses.
4. 04-residential.png — lower outskirts with houses and smaller buildings.
5. 05-player-selected.png — gold selection, ownership and logistics inspector.
6. 06-construction-preview.png — valid generated frontage and parcel land value.
7. 07-city-diagnostics.png — seed controls, population, Debug and site information.
8. 08-second-seed.png — seed 9173 with a different coast, streets and development.
9. 09-city-2012.png — same city foundation with the earlier economic era.

All nine were visually inspected. First-pass inspection found repetitive housing;
the refinement added pitched house roofs, doors, deterministic garden trees,
individual apartment windows and a shallow-water edge. Frames were recaptured and
inspected again. The coast remains intentionally cell-stepped. Ownership colors,
selected outline, construction preview, minimap and HUD are readable at 1280 × 800.
Zoomed district frames intentionally crop distant map edges; overview includes the
whole city. Inspector content scrolls. No final-art claim is made.

The first test pass also found insufficient water for one seed; the coast is now
bounded at 88% of width. A manual-transfer fixture was corrected to pin competing
automatic buyers, and the rendered test recalculates its click projection after the
construction panel resizes the viewport. These did not require logistics rewrites. A final typed-seed test exposed deferred SpinBox edits; New sandbox now explicitly applies text before reading the seed, and the rendered/headless workflow verifies that path.

Editor import and script checks passed; git diff --check passed. The existing host
editor-settings/shader-cache permission warnings remain; no GDScript error or failed
assertion remains in final test output.

### Files and remaining limits

New: src/sim/city_generator.gd, src/ui/city_minimap.gd,
tests/milestone5_tests.gd, tests/city_smoke.gd, and their Godot .uid companions.

Substantially extended: src/sim/city_map.gd, src/ui/city_view.gd,
src/ui/game_screen.gd. Integration edits: src/sim/economy.gd,
src/sim/demand.gd, src/sim/catalog.gd, src/session/game_session.gd and
src/session/save_store.gd. Historical tests received explicit fixture selection;
tests/run_tests.ps1 includes both new suites. README and the existing architecture,
economy, game-design, technology, roadmap and validation documents were updated.

Milestone 5 is complete as a single static-city foundation. Three simple districts,
an eastern sea, orthogonal streets and modest procedural geometry are deliberate
limits. No land purchase/site surcharge was added: land values do not yet create
owned assets. No rent, redevelopment, migration, operating ports, ships, international
trade, multiple cities, traffic, individual citizens, stock market, HQ, active R&D,
advertising, strategic AI expansion or full sandbox setup is implemented. These
remain explicit roadmap items. Recommended Milestone 6 is richer consumer segments
and trustworthy financial statements, using the new population input.

## Milestone 6 final validation

Finalized September 19, 2026 on Windows / Godot 4.7.2. The interrupted worktree,
recent `.godot` logs and all uncommitted changes were inspected before any test was
repeated. No branch, commit, Computer Use or external dependency was added.

### Complete regression

The final `tests/run_tests.ps1` run imports the project and exercises every headless
entry point against the same final working tree.

| Suite | Checks | Failures |
| --- | ---: | ---: |
| Foundation | 1,524 | 0 |
| Milestone 2 | 809 | 0 |
| Game smoke | 15 | 0 |
| Legacy debug smoke | 30-day flow | 0 |
| Milestone 3 | 7,410 | 0 |
| Construction smoke, headless | 18 | 0 |
| Milestone 4 | 7,394 | 0 |
| Logistics smoke, headless | 38 | 0 |
| Milestone 5 | 28,397 | 0 |
| City smoke, headless | 17 | 0 |
| Milestone 6 | 2,547 | 0 |
| Market smoke, headless | 20 | 0 |

The numeric suites and headless smoke workflows total **48,189 checks with zero
failures**, plus the successful legacy 30-day debug flow. The Milestone 5 check
count is 304 higher than its historical checkpoint because its data-driven loops
now inspect the expanded catalog and starting economy.

Milestone 6 coverage verifies all 26 catalog products, catalog/category/recipe
validation, three population-reconciling consumer segments, income composition,
category demand scaling, price and quality response, category-level competition,
stockouts, retail slot/category rules, independent prices and suppliers, factory
recipe switching without inventory conversion, downstream pin cleanup, shipments,
replenishment, consumer sales, AI operation of several lines, and 2012/2022 public
technology gates. It also verifies statement subtotals, the balance-sheet equation,
retained earnings, direct-method cash reconciliation, capitalization/depreciation,
monthly/year/TTM boundaries, archived months, schema-6 exact restore, corrupt-save
rejection and deterministic continuation.

### Long-run and deterministic validation

The generated-city Milestone 5 suite still completes paired 3,650-day runs in both
eras with daily invariants and exact replay checks:

| Era | Days per replay copy | Residents | Consumer units | Player freight, cents |
| --- | ---: | ---: | ---: | ---: |
| 2012 | 3,650 | 2,269 | 158,979 | 12,229,710 |
| 2022 | 3,650 | 2,269 | 186,214 | 12,225,164 |

Milestone 6 additionally warms each era for 90 days, restores an exact schema-6
snapshot, and advances both copies for another 1,100 days. Full snapshots match
every 100 days and at completion; accounting and rolling-cash invariants are checked
daily. The 2012 run sustains sales in computers, household goods, smartphones and
televisions before the wearable gate. The 2022 run also sustains wearables, for five
active consumer categories. All five AI/player companies finish each run with
nonnegative cash, reconciled equity and retained earnings. AI retailers continue
selling several lines and adjusting their per-product prices; AI does not yet build
missing supply chains or make strategic assortment/production investments.

### Programmatic rendered workflow

The final non-headless `tests/market_smoke.gd` workflow passed **29 checks with zero
failures** and wrote nine 1280 x 800 PNGs to `.godot/m6-screenshots/`: city/HUD,
multi-product electronics and department stores, factory recipe switching, market
report, Income Statement, Balance Sheet, Cash Flow and unobstructed financial HUD.
It exercises add-line, per-product price and supplier controls, manufacturing and
delivery, company tabs, monthly rollover, exact UI save/load continuation and the
2012 gates. The final frames confirm the report dialog fits the viewport and the
consumer-segment market layout remains readable after the clipping fixes.

### Remaining limits

Consumers remain aggregate external demand with no household cash, employment or
individual agents. Quality is a facility/offer scalar; input-lot provenance, active
R&D, branding and product design are deferred. The initial scenario demonstrates a
subset of catalog supply chains, and AI operates existing businesses but does not
expand strategically. Liabilities, debt, tax, dividends and ownership markets are
not implemented. Older save schemas intentionally have no migration path. Recommended
Milestone 7 is active R&D plus explicit product-quality and production-efficiency
progression, introducing quality provenance before inputs can affect output quality.


## Milestone 7A validation

Validated September 19, 2026 on Windows / Godot 4.7.2. The initial worktree was
clean. README, AGENTS, architecture, technology, roadmap, Milestone 6, validation
and the implementation were inspected before edits. No Computer Use, branch,
commit, dependency or product expansion was introduced.

Baseline: existing Milestone 6 suite **2,547 checks, zero failures**. During work,
the existing command/persistence suite passed **809 checks**, and game smoke passed
**15 checks**. Development used targeted tests instead of repeating the historical
3,650-day suites.

The new `milestone7a_tests.gd` targeted suite passes **134 checks, zero failures**.
It covers invalid research metadata/graphs, 2012 and 2022 knowledge, public Debug
versus knowledge, production/construction gates, retail resale, assignment,
duplicate exclusion, parallel different projects, suspension, insufficient funds,
retained progress, completion/dependencies, expenses, cash flow, retained earnings,
TTM, depreciation and balance identity. It saves after 17 funded days, reloads the
file, compares every complete snapshot for 50 continuation days, and checks the
same completion tick (59). Invalid knowledge/progress/prerequisites, duplicate or
wrong-behavior assignments, product/stock contamination and expense corruption are
rejected; failed session load leaves the prior session untouched.

### One focused 2012 research scenario

`--long-only` runs a generated seed-42 economy from 2012 through March 9, 2015.
The corrected run passed **1,165 checks, zero failures**. It checks daily economic,
accounting and logistics invariants while reaching the wearable public gate.
At January 1, 2015 it is public/researchable but still unknown. Nova's scenario
center selects wearables deterministically, spends 150,000 cents across 60 funded
days and completes at tick **1,155**. Nova can then manufacture earbuds and its
existing factory produces them; Orion remains unable to manufacture that recipe.
Final consumer units: **48,507**. The first attempt exposed Nova's old `ai=false`
scenario flag; enabling its minimal AI fixed participation, and the same focused
scenario was rerun. No additional broad research stress scenarios were introduced.

### Rendered R&D inspector

`tests/research_smoke.gd` passed **16 checks** rendered, including building an R&D
center without product selection, locked/researchable status, assignment, stop and
resume, 28.3% progress, completion, rival read-only controls and accounting checks.
Three 1280 × 800 frames were captured in `.godot/m7a-screenshots/`:

1. `01-available-project.png`
2. `02-active-progress.png`
3. `03-known-technology.png`

All three were inspected. One refinement renamed the tab to R&D and explicitly
identified the Debug public override; the three frames were recaptured and inspected.
Progress, prerequisites, funded-day ETA, costs and controls fit the existing inspector
without clipping. These screenshots accelerate public availability via the audited
Debug action; the long scenario above verifies normal calendar availability.

### Scope and files

New: `tests/milestone7a_tests.gd`, `tests/research_smoke.gd`, and their `.uid` files.
Substantially extended: catalog/economy/company/facility simulation, SaveStore,
facility inspector, construction UI and `data/example_economy.json`. Integration:
financial reports, consumer markets, sourcing/logistics, company reports, city
rendering and legacy Debug display. Historical tests only adopt explicit public
API names and allow productless construction in their archetype loop; their
assertions and long-run coverage remain. The full PowerShell wrapper includes the
new short R&D suite and headless research smoke; the focused long run is explicit.
README and existing architecture/economy/technology/roadmap/Milestone6/validation
documents are updated; no redundant milestone document was created.

Limits: research balancing is illustrative; 2022 starts know all current technologies.
Idle operating centers still incur overhead, and AI only assigns existing centers.
Research is expensed with no intangible capitalization. Schema 7/catalog 3 reject
older saves without migration. Quality remains the existing scalar. Milestone 7B
should add continuous product/process projects, attained quality/efficiency levels
and explicit component-quality provenance; no such effects are implemented in 7A.

### Final complete regression (one full run)

The final `tests/run_tests.ps1` completed successfully with **48,505 checks, zero
failures**, plus the legacy Debug 30-day flow. The existing suites account for
48,358 checks and the new short R&D/headless smoke suites add 147. Historical
counts increase because their data-driven loops now include the R&D archetype
and generated scenario facility; no old assertions or long replays were removed.

| Suite | Checks | Failures |
| --- | ---: | ---: |
| Foundation | 1,524 | 0 |
| Milestone 2 | 809 | 0 |
| Game smoke | 15 | 0 |
| Legacy Debug | 30-day flow | 0 |
| Milestone 3 | 7,413 | 0 |
| Construction smoke | 18 | 0 |
| Milestone 4 | 7,394 | 0 |
| Logistics smoke | 38 | 0 |
| Milestone 5 | 28,563 | 0 |
| City smoke | 17 | 0 |
| Milestone 6 | 2,547 | 0 |
| Market smoke | 20 | 0 |
| Milestone 7A | 134 | 0 |
| Research smoke, headless | 13 | 0 |

The wrapper imported the project and found no script/parse errors or failed
assertions. `git diff --check` passed. The restricted editor's existing global
settings-write warning appeared during the separate development import; it did
not prevent class registration or testing. Final logs are in ignored
`.godot/m7a-final-regression.log`, `.godot/m7a-long.log` and
`.godot/m7a-rendered.log`. No branch or commit was created.


## Milestone 7B1 validation

Validated September 20, 2026 on Windows / Godot 4.7.2. Initial working tree was
clean; project instructions, README, architecture, economy, technology, Milestone 6,
roadmap, validation and committed 7A implementation were inspected before edits.
No Computer Use, branch, commit, catalog change or external dependency was added.

The targeted baseline was the 7A suite: **134 checks, zero failures**. Development
validation used the new quality suite and directly affected historical suites:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| 7B1 quality provenance | 140 | 0 |
| Milestone 2 commands/persistence/sourcing | 809 | 0 |
| Milestone 4 logistics/accounting/replay | 7,394 | 0 |
| Milestone 6 consumer markets/accounting/replay | 2,547 | 0 |
| Quality rendered smoke | 7 | 0 |

Focused coverage includes equal/unequal pooling, integer residues, invalid requests,
partial/full removal and compatibility cost returns; deterministic manufacturing,
higher-quality inputs, mixed component weights and 1/100 endpoints; external-boundary
production; inter-company dispatch, warehouse blending, internal outbound transfer,
retail preservation and line differentiation; actual-quality consumer demand and
supplier ranking; invalid quality-save rejection and exact disk save continuation.
The factory-to-warehouse test saves during the warehouse-to-store leg, reloads, and
compares complete economy snapshots on all 20 continuation days. Accounting identities
remain exact. Historical sourcing fixtures now alter goods quality instead of the
process scalar; their ranking assertions are retained.

Initial focused-test failures were fixture errors: requesting a batch above the
existing factory capacity and changing a scenario AI flag that restore forbids.
The fixtures were corrected without relaxing production or restore validation.

Two final 1280 x 800 frames were inspected under `.godot/7b1-screenshots/`:
`01-retail-quality.png` and `02-market-quality.png`. The workflow uses normal
production/logistics and seven-day retail targets, without injecting inventory or
changing scenario definitions. It shows smartphone Q52 beside Q50 laptop/TV/earbud
lines, and corporate smartphone offers at Q52/Q52/Q51 alongside stock, prices,
realized market price and market share. Initial frames exposed normal stockouts;
the validation target was raised to retain inspectable stock. The retailer's
inventory area was increased slightly to expose all four quality-bearing lines.
No unrelated visual redesign was performed.

The complete regression wrapper includes the 7B1 suite and headless quality smoke.
Quality is current pooled stock metadata, not supplier lots or a historic sold-quality
average. Integer removal leaves rounding residues in the source. Older save schemas
have no migration. Local competition, brand/advertising, continuous improvements and
catalog expansion remain unimplemented. ROADMAP separates 7B2 Local-market/brand
foundation from 7B3 continuous product/process R&D.


### Final complete regression: one run

`tests/run_tests.ps1` completed with exit code 0 against the final code/data tree:
**48,650 checks, zero failures**, plus the successful legacy Debug 30-day flow.
Historical suites contributed 48,505 checks; 7B1 contributed 140 focused checks and
5 headless smoke checks. The wrapper imported the new scripts and found no script
errors or failed assertions. The final log is `.godot/7b1-final-regression.log`.
`git diff --check` passed. Only validation documentation was updated after the run;
no code/data changed, and the complete suite was not repeated.

## Milestone 7B2 validation

Validated September 20, 2026 on Windows / Godot 4.7.2. The fresh-session working
tree was clean at 3c9ceeb (committed 7B1). README, AGENTS, roadmap, Milestone 6,
economy, technology, architecture and validation documentation were read before
editing, alongside consumer allocation, goods quality, catalog, Markets UI and
SaveStore. No branch, commit, Computer Use or external dependency was used.

Targeted baseline: 7B1, **140 checks, zero failures**. Development verification:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| 7B2 Local/brand/averages/persistence | 240 | 0 |
| Milestone 6 consumer markets/finance/replay | 2,547 | 0 |
| Milestone 2 commands/persistence | 809 | 0 |
| Local Markets rendered smoke | 11 | 0 |
| Local Markets headless smoke after layout fix | 9 | 0 |

Focused tests cover all 17 consumer products and component exclusion, public
availability independent of knowledge, category/product defaults, invalid ratings,
Local-only clearing without corporate state mutation, corporate competition with
no AI supply, outside-option retention, low-brand demand, stock limits, seller
brand separate from goods, realized shares, independently calculated weighted
price/quality/brand, bounded Overall, zero-sales fallback, category history, exact
accounting/cash flow, disk persistence, invalid-save rejection, and 30-day complete
snapshot continuation in both eras. An initial test-only AI ID typo was corrected;
the clean rerun passed without script errors.

Exactly two 1280 × 800 programmatic frames were captured and inspected:
.godot/7b2-screenshots/smartphone.png and laptop.png. Local/Average and corporate
offers are readable in the existing dialog. Smartphone displayed Local 33.3%,
player combined 40.0% and rival 26.7%; laptop displayed Local 75.0% and rival 25.0%.
A clipped ancillary segment-summary row was split across the existing three columns
after inspection; headless UI checks passed. No additional frames or general
graphical polish were performed. The scrollable report retains its existing size.

Current intentional limitations: static brand and Local values; integer allocations
can produce zero sales for small offers; Local supply has no physical/accounting
simulation; no Concern display, advertising, loyalty, continuous improvements,
catalog expansion, save migration or new long-term charts. Existing strategic AI
and wholesale-allocation limitations remain. 7B3 should add funded repeatable
product/process improvements affecting newly produced goods, preserving inventory
quality provenance, brand independence, deterministic replay and exact accounts.

## Milestone 7B3A validation

Validated September 20, 2026 on Windows / Godot 4.7.2. The initial tree was clean
at committed 7B2. Required project documentation and the 7A/7B1/7B2 research,
quality, market, UI and persistence implementation were inspected before edits.
No branch, commit, Computer Use, dependency, catalog product, process-efficiency,
brand-growth or Local behavior change was introduced.

The targeted baseline was Milestone 7B2: **240 checks, zero failures**. The new
`milestone7b3a_tests.gd` suite passes **137 checks, zero failures**. It covers the
0–5 company/product level model; typed technology and quality projects; public,
knowledge, manufacturing-compatibility, exact-target, duplicate and maximum gates;
funding stalls; retained stop/resume progress; deterministic level completion and
scaling; research accounting; monotonic/bounded output; component and zero-input
formulas; non-retroactive factory/transit/warehouse state; improved shipment/retail
quality; normal consumer preference; unchanged Local/brand; deterministic AI
fallback; schema corruption rejection; exact partial restore and matching replay
completion tick. Directly affected Milestone 2, 6, 7A, 7B1 and 7B2 suites and the
historical R&D smoke also passed during development.

The exact implemented formula is
`effective_process_Q = clamp(facility_process_Q + 5 × level, 1, 100)` and, for
recipes with inputs, `output_Q = clamp(floor((effective_process_Q +
floor(consumed_quality_points / consumed_input_units)) / 2), 1, 100)`.
Zero-input products use `effective_process_Q`. Level L takes `300 × L` work and
costs `2,500 × L` cents per funded day. Completion affects only subsequently
manufactured units; existing pooled goods and shipments retain their points.

The non-headless programmatic workflow passed **15 checks, zero failures** and
captured exactly two inspected 1280 × 800 frames under `.godot/7b3a-screenshots/`:

1. `01-quality-project.png` shows smartphone L0 → L1, cap 5, 120/300 retained
   progress, $25/day project cost, 18 funded days remaining and active assignment.
2. `02-factory-quality.png` shows company smartphone level 1/5, effective process
   Q55 and newly produced physical stock Q52.

The required information is readable in the existing compact inspector. The factory
detail area remains scrollable as designed; no required row is clipped. No unrelated
visual polish was performed.

### Final complete regression: one run

`tests/run_tests.ps1` completed once against the final code/data tree with exit code
0: **49,049 checks, zero failures**, plus the successful legacy Debug 30-day flow.
The new suite contributed 137 checks and its headless smoke 13; all historical
milestone, long-run and smoke suites passed. The only recurring message was the
documented host root-certificate-store warning. `git diff --check` passed.

Economy schema **10**, catalog **5** and save format **2** persist complete levels,
sparse retained quality progress, structured active assignments and target levels.
Older schemas/catalog fingerprints remain intentionally incompatible. Save restore
rejects unknown products, levels outside 0–5, impossible targets, missing knowledge,
invalid progress and duplicate active assignments before replacing the session.

Substantial implementation changes are in company, facility, catalog, economy,
SaveStore and the compact facility inspector, plus catalog defaults and the new
focused/rendered tests. Documentation and the historical structured-project test
fixtures were synchronized. Current limits are deliberate: no efficiency/throughput,
conversion-cost, yield/scrap, advertising/brand, dynamic Local, patents, licensing,
staff or strategic AI. Recommended 7B3B is company/process efficiency levels through
the same typed, funded, persistent scheduler, with separately documented effects on
throughput and/or conversion cost and no retroactive inventory mutation.

## Milestone 7B3B validation

Validated September 20, 2026 on Windows / Godot 4.7.2. The initial tree was clean at
committed 7B3A. Required project documentation and the committed 7A/7B1/7B2/7B3A
research, production, accounting, UI and persistence implementation were inspected
before edits. No branch, commit, Computer Use, dependency, throughput/yield feature,
brand/Local change or strategic AI was introduced.

The targeted baseline was Milestone 7B3A: **137 checks, zero failures**. Development
validation used the new 7B3B suite and directly affected historical suites:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| 7B3B process efficiency | 137 | 0 |
| Foundation production/accounting | 1,524 | 0 |
| Milestone 2 commands/persistence | 809 | 0 |
| Milestone 6 markets/accounting/replay | 2,547 | 0 |
| Milestone 7A research | 134 | 0 |
| Milestone 7B3A product-quality research | 137 | 0 |
| Process R&D rendered workflow | 15 | 0 |

Focused coverage includes catalog validation; structured project eligibility;
retail-only, unknown-knowledge, skipped-target, maximum and duplicate rejection;
funding stalls; retained stop/resume work; exact completion; 0–5 monotonic costs;
25% maximum reduction; integer-floor and zero-cost behavior; zero-input production;
actual cash, `production_cash`, inventory value, COGS and balance identities; no
retroactive factory/transit/warehouse/retail or prior-production-cash mutation;
unchanged recipe quantities, physical quality, quality level, capacity, corporate
brand and Local; technology-first balanced AI behavior in 2022; corruption rejection;
and exact partial save/replay with a matching completion tick.

The exact implemented conversion formula is
`max(1, floor(base_cost × (100 - 5 × level) / 100))` for positive base costs;
zero stays zero. Only future production pays and capitalizes this reduced amount.
Research itself remains an operating research expense. Economy schema **11**,
catalog **6** and save format **2** persist complete levels, sparse partial progress,
structured active assignments and target levels. Restore validates product/public/
manufacturable state, technology knowledge, bounds, exact next target, progress and
duplicates before replacing the session.

Exactly two 1280 × 800 programmatic frames were captured and inspected under
`.godot/7b3b-screenshots/`:

1. `01-process-project.png` shows smartphone L0 → L1, 120/300 retained work,
   $25/day, 18 funded days remaining, 5% target reduction and $30.00 → $28.50.
2. `02-factory-process.png` shows process L1/5 and $30.00 → $28.50 beside the
   separate product-quality/effective-process-Q read model.

Both required read models are legible in the existing compact, scrollable inspector;
no clipping fix or additional frame was needed.

### Final complete regression: one run

`tests/run_tests.ps1` completed once against the final code/data tree with exit code
0: **49,199 checks, zero failures**, plus the successful legacy Debug 30-day flow.
The new focused suite contributed 137 checks and its headless smoke contributed 13;
all historical milestone, long-run and smoke suites passed. The only recurring
message was the documented Windows root-certificate-store warning. `git diff --check`
passed after the documentation update; the complete suite was not repeated for that
documentation-only change.

Current deliberate limits are no throughput/capacity research, material reduction,
yield/scrap, advertising/brand growth, dynamic Local, strategic ROI AI, patents,
licensing or R&D staff. Milestone 7 is complete. The recommended next milestone is
Milestone 8 — Competitive management, delivered in a separately scoped increment
rather than adding another research feature.

## Milestone 8A2B validation

Validated September 21, 2026 on Windows / Godot 4.7.2. The initial tree was clean.
The requested 8A1 and 8A2A baseline suites passed **31** and **25** checks respectively,
with zero failures. No branch, commit, Computer Use, dependency, catalog expansion,
strategic ROI logic or AI expansion behavior was introduced.

The focused 8A2B suite passes **39 checks, zero failures**. It covers player/AI
separation; public retail presence and commercial-activity eligibility; locked and
absent lines; stale-budget clearing; weekly cadence; below/equal/above-Local targets;
restart after decay; exact threshold/30 ceiling; aggregate cash cap; largest-deficit
priority and product-ID ties; zero cash; shared funded/unfunded daily behavior;
advertising expense, cash and balance reconciliation; unchanged research, quality,
process and Local state; preserved price AI; same-seed choices; and exact save/load
continuation. Economy schema **13**, catalog **6** and save format **2** are unchanged.

### Final complete regression: one run

`tests/run_tests.ps1` completed once against the final code and test tree with exit
code 0: **49,294 checks, zero failures**, plus the successful legacy Debug 30-day
flow. This includes the 8A1, 8A2A and 8A2B suites at 31, 25 and 39 checks. Every
historical long-run, persistence, accounting, market, research and headless smoke
suite passed. The complete output is in `.godot/m8a2b-final-regression.log`; the only
recurring host message is the documented Windows root-certificate-store warning.
`git diff --check` passed after this documentation-only result update, and the
successful complete suite was not rerun.
