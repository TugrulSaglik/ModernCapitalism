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
