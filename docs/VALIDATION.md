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
- The isometric city provides spatial context, camera controls and selection only.
  Construction, placement, warehouses, shipments, lead times and transport costs
  remain Milestone 3 work.
- Saves deliberately require the same format, schema, engine and catalog hash.
  No migration path or user-facing save browser exists yet.
- Debug unlock is a local development convenience, not a security boundary. Its
  effects are audited and saved; session access itself is always relocked on load.
- The original simplified economy still has external consumer funds, no household
  budgets, fixed quality, no active company research and only weekly retail-price AI.

Milestone 2 was finalized without creating a commit or branch.
