# Technical architecture

## Current milestone

[Milestone 6](MILESTONE6.md) extends these boundaries with ConsumerMarket (pure
segment/category market clearing), FinancialReports (derived statements), and
CompanyReports (dismissible tabbed UI). SimFacility has product-keyed assortments,
prices and sales records; manufacturing still has one selected recipe at a time.
SimCompany records categorized account deltas and archives monthly closes. Save
schema 6 hydrates these states transactionally; format 2 is unchanged. The older
milestone sections below remain architectural history.

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
| CityGenerator | Seeded terrain, streets, parcels, initial site allocation and ambient development |
| CityMinimap | Compact derived map and camera navigation; no simulation ownership |
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
Schema-6 economy snapshots contain city and logistics state plus catalog/scenario/era identity, clock, initial
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

## Historical city, construction and rendering (Milestone 3)
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

## Procedural city and land (Milestone 5 foundation)

Economy owns CityMap; CityGenerator fills it before any rendering. GameSession.start
accepts optional city settings after mode, and Economy.initialize accepts them after
catalog path. Default settings are width 48, depth 36; supported integer ranges are
40–96 and 30–72 respectively. The bounds are performance/scenario limits, not fixed
coordinates in routing or construction. The existing nine scenario facilities retain
their company, role, product, quality and capacity. An optional city_layout is used
only by the explicit {"preset": "legacy"} regression fixture. Normal sandbox,
tutorial and headless sessions use the generator and the same economic systems.

The generator owns a separate RNG seeded from the game's numeric seed. City creation
does not consume economic demand draws. Metadata stores generator version 1, seed as
a decimal string, resolved settings and preset. The same engine, definitions, seed
and settings produce equal authoritative records, independent of rendered nodes.
The UI offers seeds 0–2,147,483,647 and entropy only in the Random seed button.
Starting either era with the same seed/settings creates the same city.

Generation proceeds in a fixed order:
1. A bounded coastline random walk changes by up to two cells every three rows.
   The mainland occupies roughly 68–88% of each row; the remainder is one continuous
   eastern sea. There are no islands, bridges, ships or navigable water routes.
2. Seeded streets are spaced seven to nine cells apart. Horizontal streets extend
   toward the coast and intersect an inland spine. Vertical roads lie inside the
   minimum coastline extent. Consequently every road belongs to one component.
   Major/local metadata affects presentation; logistics still uses shortest cell
   distance plus two access legs, preserving freight and lead-time formulas.
3. Every cell has a stable parcel ID, terrain, district, road access, land value,
   waterfront and potential-port flags, plus a zoning placeholder. Occupancy is
   derived from authoritative economic plots and ambient footprints rather than
   duplicated in each parcel. placement_error enforces bounds, water, roads,
   frontage and both kinds of occupancy for the whole requested footprint.
4. Economic facilities are placed first in stable ID order. Each chooses among
   valid candidates using seeded samples and maximum minimum separation from
   already placed businesses. No old scenario coordinates enter this selection.
5. Ambient development fills road frontage, with occasional vacant blocks retained
   for construction. Housing type/density favors the center. Five data records in
   CityGenerator.KINDS define houses, apartments, larger blocks, offices and generic
   commercial buildings. Properties have stable coordinate IDs, footprints, district,
   capacity, occupied residents, empty owner ID and saved appearance fields.
   They have no SimFacility, company, inventory, ledger or daily economic tick.

Districts are West Gardens, Central Quarter and Harbor District. Each stores a
development character, purchasing power, population, capacity and average land value.
Population and averages aggregate property/cell data. See ECONOMY.md for formulas.

Waterfront means land with orthogonally adjacent water. Port eligibility additionally
requires road frontage, a non-road cell and a non-edge row. This is an interface
candidate, not permission for an operational port or a guarantee that a future port's
larger footprint fits. parcel_info also exposes occupancy. A future port can reference
a coastal site, existing road access and a separate water-network endpoint without
putting transport state into scene nodes.

CityView reads saved terrain and property appearance, drawing simple procedural
geometry. Houses, apartments, offices and economic facilities have distinct details;
economic ownership remains roof/band color and selection remains a gold outline.
Coordinates, initial framing, maximum zoom and pan bounds derive from dimensions.
Middle drag, wheel zoom and contextual selection/cancellation remain; WASD is disabled.
CityMinimap draws land/water, roads, ambient footprints, economic ownership, selection
and camera focus; clicking changes camera focus only. Existing text/modal input
protections also guard minimap navigation. Debug adds statistics, site information
and an occupancy-aware vacant-frontage overlay.

Persistence remains format 2 with exact integer/float tags, catalog hash and engine
pinning. Economy schema is now 5; schemas 1–4 are rejected, without migration.
Saves contain the actual water mask, roads/classes, parcels, districts, ambient
properties/appearance, population, economic positions and metadata. Restore initializes
economic definitions using the small fixture, then hydrates and validates the saved
city; it never calls procedural generation. It checks coordinates, duplicates,
land/road conflicts, connectivity, footprints, ownership, waterfront flags, values,
appearance ranges and recomputed demographic/district totals. Generator algorithm
changes cannot silently change an existing save. Changes to the property record
contract or kind definitions require explicit schema/version review.
