# Milestone 1 validation

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

## Design compromises and observed behavior
- Cash grows steadily because consumer spending comes from an external sector
  and no expansion/capital spending, taxes or household budgets exist yet. This
  validates operations, not a balanced complete-game macroeconomy.
- Stable first-supplier/first-buyer order favors Orion over Nova. Both remain
  viable; fair allocation and supplier selection belong in milestone 2.
- Wholesale delivery is instantaneous within one city; facilities do not yet
  have capital costs or spatial footprints.
- Components stand in for paid external resources. Recipe and public technology
  dates are illustrative; production quality is not propagated through lots.
- Technology gates are implemented; company research is planned. Quality is a
  fixed per-facility scalar, and AI only adjusts retail prices weekly.
- Snapshots are detached/versioned, but restore/migration/replay persistence is
  not implemented. Deterministic comparisons require matching engine/data.

No later milestone has been implemented, and no commit or branch was created.
