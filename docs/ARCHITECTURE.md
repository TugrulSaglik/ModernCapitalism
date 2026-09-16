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
| SupplierMarket | Produce deterministic eligible offers ranked by price per quality point |
| GameSession | Own the Economy, player authorization, mode, save/load and Debug access |
| GameTime | Convert frame deltas and selected speed into bounded calls to `Economy.step` |
| SaveStore | Validate, encode, atomically write and transactionally restore session state |
| CityMap | Serializable cells, road mask, ownership/footprints and monotonic facility IDs |
| City / management UI | Render snapshots, select facilities and submit plain-data commands |
| Debug screen / CLI | Construct Economy, submit commands, advance ticks, read snapshots |

Dependencies flow from hosts to Economy to domain objects; Inventory and Demand
know nothing about the host. Catalog contains immutable definitions by convention;
runtime objects contain quantities and decisions. IDs, not Node references, connect
companies, products, technologies, facilities and cities.

## Commands, reads and reproducibility
UI queues validated plain-data commands with a target company and facility ID.
The current command set changes price, operating state, stock target and
per-product supplier policy. Commands execute at the next tick boundary in
submission order. GameSession injects the authorized player company; Economy
validates ownership, types, bounds and economic preconditions. AI pricing uses the
same queue. GameTime is an accumulator around the same explicit daily `step`, with
a 64-tick per-frame cap that retains excess elapsed time. UI reads snapshots and
read models and does not mutate inventory or cash.

One seeded RandomNumberGenerator belongs to each economy. Demand draws occur in
sorted product-ID order, even for unavailable products. Firms and facilities are
processed in sorted ID order. Recipe inputs also use sorted IDs. Never use wall
time, global random functions, frame deltas or unordered iteration to make decisions.
Reproducibility targets the same engine version and catalog; pin both for replays.

## State and persistence
Schema-4 economy snapshots contain city and logistics state plus catalog/scenario/era identity, clock, initial
seed, RNG state as a decimal string, pending commands and results, accounts,
facilities, inventories, sourcing state, recent activity, market reports and Debug
effects. The session snapshot adds mode, authorized company and time-controller
state. SaveStore format 2 tags integers and binary floating-point values before JSON encoding, fingerprints the catalog,
pins the Godot engine version, writes through a same-directory temporary file, and
validates all restored state before replacing the live session. Unsupported format,
schema, engine or catalog versions are rejected; migrations are not yet provided.
Money is integer cents and goods integer units. Preserve stable definition IDs and
add migration aliases rather than renaming persisted IDs.

## Extension seams (planned, not implemented)
- Logistics: extend current road-routed shipments with traffic, vehicle fleets,
  route capacity and multiple cities when needed.
- R&D: company technology records and projects consume funds/personnel, check the
  catalog prerequisite graph, unlock recipes and improve quality/efficiency.
- Headquarters: facilities enabling management services, budgets and overhead;
  do not turn the headquarters Node into the company model.
- Finance: replace aggregate accounts with journal entries and balance-sheet
  accounts; add debt and taxes. Aggregate fixed assets and depreciation now exist.
  A share registry and
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

## City, construction and rendering (Milestone 3)
Economy owns one CityMap for `metro`: a 32 × 24 grass grid with roads on rows
6/13/20 and columns 1/30. All other in-bounds, unoccupied cells are buildable.
Plots map facility IDs to integer origin, width, depth and owner. The facility
holds its city/type ID; type is the archetype. Scenario starting positions live
in the catalog's `scenario.city_layout`, replacing the former presentation file.
Save validation reconstructs occupancy and rejects overlaps, changed roads,
wrong owners, invalid footprints and reused construction IDs.

`build_facility` specifies archetype, product, integer x/y and optional city ID.
The session injects the player owner. Economy validates type/product availability,
cash, bounds, non-overlap, road exclusion and at least one orthogonally adjacent
road cell. Successful construction capitalizes the catalog cost, assigns a monotonic
`built_000001`-style ID, creates an ordinary SimFacility and occupies the plot.
Manufacturing and retail use the existing daily phases, sourcing and accounts.
Storage has no production or retail phase; warehouses source toward per-product
targets and accept manual transfers, with incoming stock reserving capacity.

`demolish_facility` requires ownership. It writes off inventory, removes the plot
and facility, clears supplier policies pointing to it (returning them to automatic),
and removes live last-source references. Historical company/market totals remain.
There is no refund, land purchase, construction delay or rotation. Demolition
also writes off remaining fixed-asset book value.

GameSession submits build/demolish to the existing FIFO and immediately flushes
all pending commands at the current between-day boundary. Earlier management
commands execute first. Preconditions are rechecked per command; rejection consumes
neither money nor an ID. No clock, demand RNG or production advances. This explicit
boundary action works identically when running or paused. Normal management alone
still waits for the next daily tick. Direct headless queued construction also works
at the normal tick boundary and survives saving. Placement UI state is transient;
load/new session cancels the preview, while accepted commands and city state persist.

CityView reads snapshots and builds procedural meshes and collision bodies tagged
with facility IDs. Its ground-ray projection maps cursor position to integer cells;
the preview calls the same economic validation as construction. The HUD submits
commands and refreshes buildings/list selection after structural changes. Scene
nodes never own city state. Owner-tinted roofs/signs, shop windows/awnings, factory
equipment/stacks and warehouse loading bays express category and ownership. Selected
facilities show a footprint outline and billboard label. Orthographic navigation
retains WASD/arrows and wheel zoom, with focus limits ±22/±17 and zoom 18–65.

Future land prices/districts/zones can attach cell metadata; logistics can use grid
positions and road cells. Multiple cities can index CityMap by city ID without
moving simulation into scenes. Corporate archetypes can extend the same catalog
and command path when their behavior exists; no empty HQ/R&D systems were added.

Save format 2 preserves floating-point report values through binary tags because
Godot JSON parsing can otherwise change the final bits of ratios. Schema 4 restores
both scenario and constructed facilities, including deletions. Old schema/format
saves are deliberately rejected, not migrated. Engine/catalog matching and
transactional candidate validation still apply.

## Logistics and finance (Milestone 4)

`CityMap.road_distance` breadth-first searches road cells between orthogonal
facility access points and adds two access legs. `Logistics.quote` turns distance
into freight and a minimum one-day lead. `dispatch` removes source inventory,
settles purchase and freight at departure, then records the buyer-owned goods in
transit. `deliver` adds them to the destination at the promised tick. Same-owner
transfers preserve book cost and create no sale. Warehouse capacity counts local
and inbound units; replenishment subtracts incoming goods from the target.

The aggregate balance invariant is cash + local and in-transit inventory + net
fixed assets = contributed capital + cumulative profit. New buildings depreciate
straight line over 3,650 daily ticks. Company history records daily profit deltas
and monthly totals, including a zero current-month entry after a month rollover.
The HUD reads these records and does not own any economic state. Save restoration
validates shipment endpoints, timing, route quotes, assets and histories before
replacing the live economy.
