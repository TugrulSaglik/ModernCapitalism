# Technical architecture

## Boundaries and current modules
All `src/sim` scripts extend RefCounted, use typed GDScript, and have no scene,
rendering or input dependencies. The SceneTree test runner is only a host.

| Module | Responsibility / dependencies |
| --- | --- |
| Catalog | Read and validate JSON products, technologies, facility types and scenario; resolve era availability |
| SimClock | Gregorian calendar and explicit daily ticks |
| Inventory | Quantity and total carrying cost by stable product ID; atomic removals |
| Company | Cash, capital, revenue, operating expense, cost of goods sold and profit |
| Facility | Owner/city/type IDs, local inventory, recipe product, capacity, offers and quality |
| Demand | Pure price/quality preference and finite consumer allocation |
| Economy | Own state, seeded RNG, command queue, fixed phase orchestration, AI, trade, production and reports |
| Debug screen / CLI | Construct Economy, submit commands, advance ticks, read snapshots |

Dependencies flow from hosts to Economy to domain objects; Inventory and Demand
know nothing about the host. Catalog contains immutable definitions by convention;
runtime objects contain quantities and decisions. IDs, not Node references, connect
companies, products, technologies, facilities and cities.

## Commands, reads and reproducibility
UI queues validated plain-data commands with a target company and facility ID.
Milestone 1 supports `set_price`; later commands add build/source/research/finance.
Commands execute at the next tick boundary in submission order. A later player
session layer supplies authorization; the engine validates economic preconditions.
Hosts explicitly call `step`; real-time playback must use an accumulator around
this same method. UI reads detached snapshots, never edits inventory or cash.

One seeded RandomNumberGenerator belongs to each economy. Demand draws occur in
sorted product-ID order, even for unavailable products. Firms and facilities are
processed in sorted ID order. Recipe inputs also use sorted IDs. Never use wall
time, global random functions, frame deltas or unordered iteration to make decisions.
Reproducibility targets the same engine version and catalog; pin both for replays.

## State and persistence direction
Snapshots contain schema version, catalog version, scenario/era, clock, initial
seed, RNG state as a decimal string, pending commands, accounts, facilities,
inventories and market reports. Money is integer cents and goods integer units.
Snapshot export is implemented; restore, migrations and atomic disk saves are
future work. Preserve stable definition IDs and add migration aliases rather than
renaming persisted IDs. Before implementing saves, add round-trip and continuation
tests and definition-version compatibility checks.

## Extension seams (planned, not implemented)
- Logistics: replace instantaneous trade delivery with shipments between facility
  inventories; add warehouse capacity and route lead times. Keep ownership and
  payment timing explicit. Cities already have IDs on facilities.
- R&D: company technology records and projects consume funds/personnel, check the
  catalog prerequisite graph, unlock recipes and improve quality/efficiency.
- Headquarters: facilities enabling management services, budgets and overhead;
  do not turn the headquarters Node into the company model.
- Finance: replace aggregate accounts with journal entries and balance-sheet
  accounts; add debt, fixed assets, depreciation and taxes. A share registry and
  exchange operate on company IDs and settle through the same cash ledger.
  Ownership/control is separate from operational decision policy.
- AI: policy modules consume the same read models and produce the same commands
  as players. Current AI uses bounded weekly price commands only.
- Multiple cities: city demand populations, local offers and transport links;
  partition market clearing by city/product, retain one explicit scheduler.
- New sectors: recipes and facility definitions express extraction, farming,
  assembly and retail. Add genuinely different behavior (land, seasons, spoilage)
  as reusable systems rather than per-product branches.

Do not create empty framework classes for every future system now. Extract phase
services when complexity requires them, preserving the phase order and test seams.
