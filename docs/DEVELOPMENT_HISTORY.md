# Development history

## Implemented milestones

1. Deterministic daily production, retail, accounting and technology gates.
2. Player commands, continuous time, saves and management host.
3. Construction, demolition and procedural facility silhouettes.
4. Warehouses, road logistics, inventory in transit and financial history.
5. Procedural cities, population, parcels and minimap.
6. Segmented consumer markets, broader electronics catalog and reports.
7. Company research, physical quality, Local competition and repeatable R&D.
8. Advertising, headquarters, staffing, management UI, StrategicAI and difficulty.
9. Shares, dividends, corporate control and managed subsidiaries.
10. Real estate, rent, depreciation, employment and migration.
11. Regional cities, ports and trade. 11R/11R2 introduced batched metropolitan
    rendering, 36 real profiles and generator v3's one-cell street network.
12. Title/setup flow, a twelve-objective tutorial on the real simulation, 68
    products, sector archetypes, ambient detail batching, audio/preferences,
    release preparation and a project front page.

## Archived README checkpoints

The following records preserve the previous README's historical details, commands
and limitations. Version numbers, planned features and old validation commands
below describe their respective checkpoints, not the current release workflow.
Use [Releasing](RELEASING.md) for current bounded validation.

---

# ModernCapitalism

A personal business simulation game inspired by classic economic management games.

## Core concept

The player creates and manages companies operating across retail, manufacturing,
research, logistics, and other industries in a simulated economy.

The game should emphasize:

- Supply chains
- Manufacturing
- Retail
- Product quality
- Brand value
- Pricing
- Research and development
- Competition between firms
- Consumer demand
- Corporate finance
- Technology progression

## Game modes

### Tutorial

A guided scenario that teaches the major game systems progressively.

### Sandbox

A configurable free-play mode with difficulty and simulation settings.

## Starting eras

### 2012

The game begins with technology appropriate to 2012.

More advanced technologies and product categories must become available through
technological progress and research as the simulation advances.

### 2022

Modern product categories and technologies are already available at the start.

Research remains important because companies can continuously improve product
technology and quality even after a product category has been unlocked.

## Technology

Engine: Godot 4
Language: Typed GDScript

## Milestone 11R2

11R2 — Metropolitan city profiles and street-network correction — implemented.
Normal games select three unique real coastal/port cities from a static 36-profile
UN World Urbanization Prospects 2025 pool. Population-dependent base maps range
from **192 × 144 to 384 × 288**, with modest compactness/aspect variation. Generator
v3 replaces random branches with spaced one-cell arterials, connectors and street
blocks. Population targets use one simulation unit per 1,000 residents; the UI
shows real-person scale. MultiMesh rendering, the neighborhood camera, minimap,
regional economics and the fixed regression board are retained.

Current versions: **economy schema 21 / catalog 12 / save format 2 / generator 3**.
See [city generation](docs/CITY_GENERATION.md). Milestone 12 remains next.

## Milestone 11 (historical checkpoint)

Milestone 11 is implemented. Procedural sandbox games now simulate Metro, Harbor
and Highland as one region. The city selector changes the active map and build
location; companies, corporate finance and accounting remain regional. Each city
has independent population, real estate and consumer demand, plus a public port.
Port routed freight connects cities and the external import/export market. The
Company → Markets location selector and Trade tab expose regional activity.
StrategicAI can expand across cities. At that checkpoint versions were **economy schema 19 /
catalog 11 / save format 2**. See [regional trade](docs/REGIONAL_TRADE.md).

## Milestone 10 (historical checkpoint)

Milestone 10 is implemented. Procedural cities now have company-owned land at cost,
acquirable ambient buildings, residential/office/commercial development and
redevelopment, gradual monthly migration, aggregate employment, rent, maintenance,
and building depreciation. Facilities automatically acquire unowned land when
constructed. Property activity flows through company accounts and statements;
StrategicAI may make one conservative property investment instead of a facility
investment in its monthly capital pass. City selection and the Company → Properties
tab expose land, occupancy, costs, rent and city growth. Current versions are
**economy schema 18 / catalog 10 / save format 2** at that checkpoint. See [real-estate rules](docs/REAL_ESTATE.md).

Milestone 11 supersedes the single-city scope described here.

## Milestone 9 (historical checkpoint)

Milestone 9 is implemented. The Company → Finance tab now shows deterministic
public securities, share portfolios, cost basis, capital structure and recent daily
prices. Player Electronics starts private; Circuit Supply, Orion, Nova and Metro
start public with 400,000 founder shares and 600,000 public-float shares each.
Corporate cash can buy and sell float shares, issue new shares, and pay immediate
dividends. Ownership above 50% grants control; the managed-company selector lets
players run controlled subsidiaries and suppresses their autonomous StrategicAI.
Financial statements carry investments at cost and classify investment and capital
cash flows separately. Current versions are **economy schema 17 / catalog 9 / save
format 2**. See [corporate finance rules](docs/CORPORATE_FINANCE.md).


## Milestone 8D

Milestone 8 is complete. Each session now has a fixed **Relaxed**, **Standard** or
**Competitive** difficulty that changes only StrategicAI policy: retained reserve,
opportunity threshold, retailer cap, warehouse timing and pre-hire payroll runway.
Prices, costs, demand, research, staff effects, starting cash and every other economic
rule remain identical. Standard preserves the Milestone 8C baseline. Settings shows
the current immutable difficulty and selects the next sandbox difficulty; saves and
slot summaries preserve it exactly. At that checkpoint versions were **economy schema
16 / catalog 9 / save format 2**. The deterministic five-case balance matrix is documented in
[balancing](docs/BALANCING.md).

## Milestone 8B3

Milestones **8B1, 8B2 and 8B3 are implemented**. Companies can construct one
Corporate headquarters and hire aggregate operations, marketing, R&D and finance
managers up to its capacity of eight. Complete daily payroll is processed before
advertising. Only a staffed company whose payroll was fully funded and whose HQ is
configured as operating receives the bounded management effects: operations raises
production/retail daily throughput, marketing raises funded advertising progress,
R&D raises funded research work, and finance lowers ordinary facility overhead.
Suspension still leaves payroll due but disables every effect. At that checkpoint,
saves used **economy schema 15 / catalog 9 / format 2**.

## Milestone 8A2B

Players can set a daily advertising budget for each public consumer product from
Company → Markets. Fully funded daily spending is expensed immediately and retained
progress raises the existing company-product market-presence brand with transparent
diminishing returns. Public products now track consecutive days without actual funded
advertising: after 30 grace days, brand loses one point at each following 30-day
interval, down to zero. Funded spending resets inactivity without erasing retained
progress. On the existing weekly decision tick, AI companies advertise commercially
active products configured in their retail facilities while their brand is below
Local. Their daily budgets target one point per 30 funded days and share a deterministic
cash cap; there is no ROI or market-entry strategy. Brand remains seller state rather
than inventory provenance; Local and product quality are unchanged. Current saves:
**economy schema 13 / catalog 6 / format 2**.

## Milestone 7B3B

R&D now also supports repeatable company/product process-efficiency projects through
level 5. Each level reduces conversion cash for future production by 5%, up to 25%,
without changing recipes, capacity or physical quality. Actual reduced cash is
capitalized into new inventory and later flows through COGS; existing inventory and
shipments are never repriced. At that checkpoint saves used **economy schema 11 / catalog 6 /
format 2**. See [technology and project rules](docs/TECHNOLOGY.md),
[the cost and accounting formula](docs/ECONOMY.md#milestone-7b3b-repeatable-process-efficiency-rd),
and [validation](docs/VALIDATION.md).

## Milestone 7B3A (historical checkpoint)

R&D now supports repeatable company/product quality projects through level 5.
Each completed level improves only newly manufactured goods; existing factory,
transit, warehouse and retail inventory keeps its physical pooled quality. Projects
share the funded 7A scheduler, accounting and stop/resume behavior. Current saves:
**economy schema 10 / catalog 5 / format 2**. See
[technology and project rules](docs/TECHNOLOGY.md),
[the manufacturing formula](docs/ECONOMY.md#milestone-7b3a-repeatable-product-quality-rd),
and [validation](docs/VALIDATION.md). Process efficiency is implemented by 7B3B above.

## Milestone 7B2 (historical checkpoint)

Public consumer goods now compete with a synthetic **Local** offer as well as
the separate no-purchase option. Company/product brand is static and read-only.
Company → Markets compares Local and realized market averages, corporate prices,
stocked quality, brands, sales and shares. Shares include Local purchases.
Current saves: **economy schema 9 / catalog 4 / format 2**; older saves are incompatible.
See [model and formulas](docs/ECONOMY.md#milestone-7b2-local-market-and-brand-foundation)
and [validation](docs/VALIDATION.md). Focused tests: tests/milestone7b2_tests.gd;
two-frame programmatic workflow: tests/local_market_smoke.gd.
Product-quality improvement and process efficiency are superseded by 7B3A/7B3B
above; advertising remains deferred.

## Milestone 7B1 (historical checkpoint)

Manufactured goods now carry integer pooled quality through components, warehouses,
shipments and retail. Consumer and supplier offers use actual stocked product
quality. Stores do not change goods quality. Saves use **economy schema 8 / catalog 3
/ format 2**; older schemas are incompatible. [Quality rules](docs/ECONOMY.md#milestone-7b1-product-quality-provenance).
Run `tests/milestone7b1_tests.gd` for focused checks and `tests/quality_smoke.gd`
for two programmatic rendered frames. Local/brand is superseded by 7B2 above; continuous R&D remains deferred.

## Milestone 7A (historical checkpoint)

Company knowledge is now separate from public technology. Starting knowledge is
2012/2022 era-appropriate; later public technologies require company research for
manufacturing. Retailers may buy/resell public finished goods without recipe knowledge.
Build an **R&D center** under Corporate, select it, and assign or stop research in
the R&D inspector. Stopped progress is retained. Projects cost money daily and
completion unlocks the owner's recipes. Nova has a scenario R&D center and a simple
deterministic research policy. Continuous quality/process improvements remain Milestone 7B3.

At the 7A checkpoint saves used **economy schema 7 / catalog version 3 / format 2**; older saves are
incompatible. See [technology and R&D rules](docs/TECHNOLOGY.md) and
[validation](docs/VALIDATION.md). Focused checks and three rendered screenshots:

```powershell
& $godot --headless --path . --log-file .godot/m7a-tests.log --script res://tests/milestone7a_tests.gd
& $godot --headless --path . --log-file .godot/m7a-long.log --script res://tests/milestone7a_tests.gd -- --long-only
& $godot --path . --log-file .godot/m7a-visual.log --script res://tests/research_smoke.gd
```

## Milestone 6 foundation

Consumer markets now use three income-sensitive segments and category competition.
The catalog has 26 products/components. Stores manage several product lines with
independent prices and suppliers; factories can switch compatible recipes without
converting existing inventory. **Company** opens Income Statement, Balance Sheet,
Cash Flow, Markets, History and Companies tabs. The persistent TTM/monthly HUD
reads the same financial history. At that milestone saves used economy schema 6 / format 2; old saves
are intentionally incompatible.

See [Milestone 6 rules and controls](docs/MILESTONE6.md) and
[validation](docs/VALIDATION.md). Programmatic rendered validation:

```powershell
& $godot --path . --log-file .godot/m6-visual.log --script res://tests/market_smoke.gd
```

## Milestone 5 foundation

Sandbox now starts a deterministic **48 × 36 procedural coastal city**. Settings
lets you enter a numeric city/game seed or choose a random seed before starting
2012 or 2022. Streets, business sites, residential density and ambient buildings
come from that seed. Residents and district purchasing power scale consumer
markets. Land values and waterfront/port candidates are stored for future use;
land purchases, rent and operating ports are not implemented.

The compact minimap shows water, roads, development and business ownership;
click it to navigate. Middle-drag, wheel zoom and selection remain available.
Construction excludes water and ambient properties. Sandbox Debug adds city
statistics, selected-site metadata and a vacant-frontage overlay.

Implemented: the deterministic daily economy from Milestone 1 plus a continuous
game session with pause, 1x, 2x, 4x and Max speeds; player price, operation, stock
target and supplier commands; ranked and manually selectable suppliers; versioned
atomic save/load with deterministic continuation; and a playable management host.
The main scene presents an orthographic isometric city, selectable facilities,
facility and company information, sandbox settings, and a session-scoped Debug
panel. Starting years 2012 and 2022 continue to use the same data-driven public
technology gates.

Milestone 3 adds a deterministic city grid, roads and occupied footprints; six
data-defined construction choices; placement previews; immediate paused
construction; and owned-facility demolition. Shops, factories and warehouses
have distinct procedural silhouettes and ownership colors. City and economy
restore together using schema 5 / save format 2 (older schemas are rejected).

Milestone 4 adds road-routed shipments with delivery dates, freight, in-transit
inventory, warehouse capacity and replenishment targets. Supplier rankings include
landed cost and lead time. Construction creates a fixed asset depreciated over
3,650 days. Cash, trailing-12-month profit and monthly history stay in the bottom HUD.

Use **Build**, choose a facility and product, then click a green site touching a
road. Red previews explain invalid sites. Right-click or Escape cancels. Select
an owned facility to manage or demolish it. Demolition requires confirmation,
writes off inventory and remaining fixed-asset book value, and pays no refund.
Select an owned facility to transfer stock to another owned site. Warehouse targets
order goods automatically. The inspector shows shipment status, routes, freight,
ETAs and free capacity. Middle-mouse drag pans the city.

Open `project.godot` in Godot 4 (tested with **4.7.2**) and press **F5**. Game time
runs continuously at one simulated day per real second at 1x. The legacy economic
debug scene remains available through **F6**. Rendering and UI are hosts only; no
city node is required for an economic calculation.

### Command line (PowerShell, from repository root)

Use your installed Godot console executable. On this machine:

```powershell
$godot = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
# Register classes on a fresh checkout (opening the editor also does this).
& $godot --headless --path . --editor --quit
# Run the management game.
& $godot --path .
# Complete automated harness, including construction, persistence and long runs.
./tests/run_tests.ps1 -Godot $godot
# Direct Godot-native harness (also works outside Windows).
& $godot --headless --path . --script res://tests/run_tests.gd
# Longer headless scenario; output is a state snapshot followed by a summary.
& $godot --headless --path . --script res://src/headless.gd -- --days=3650 --era=2012 --seed=42
# Load the legacy debug scene and exercise its 30-day advance.
& $godot --path . --script res://tests/debug_smoke.gd
# Load the real game scene, exercise management integration, and capture a frame.
& $godot --path . --script res://tests/game_smoke.gd
# Repeatable construction workflow and eight rendered screenshots.
& $godot --path . --log-file .godot/m3-visual.log --script res://tests/construction_smoke.gd
# End-to-end logistics, finance and input workflow with six rendered screenshots.
& $godot --path . --log-file .godot/m4-visual.log --script res://tests/logistics_smoke.gd
# Generated-city end-to-end flow and nine rendered screenshots, including two seeds.
& $godot --path . --log-file .godot/m5-visual.log --script res://tests/city_smoke.gd
```

The PowerShell wrapper fails on nonzero exit codes, failed assertions and Godot
script errors. Debug smoke saves a screenshot under ignored `.godot/` when run
with rendering. In a restricted environment, pass `--log-file .godot/run.log`
to avoid attempts to write the default user log directory.

### Design documentation

- [Game design](docs/GAME_DESIGN.md)
- [Architecture and extension seams](docs/ARCHITECTURE.md)
- [Economic rules and accounting](docs/ECONOMY.md)
- [Technology and starting eras](docs/TECHNOLOGY.md)
- [Product taxonomy and supply chains](docs/PRODUCT_CHAINS.md)
- [Full-project roadmap](docs/ROADMAP.md)
- [Validation results and limitations](docs/VALIDATION.md)

Screenshots are written to `.godot/m3-screenshots/`,
`.godot/m4-screenshots/` and `.godot/m5-screenshots/`.
The old fixed board is retained only as an explicit regression fixture.
Milestone 6 screenshots are in `.godot/m6-screenshots/`. R&D screenshots are in `.godot/m7a-screenshots/`.
Strategic AI, session difficulty and the Milestone 8 balance checkpoint are complete;
Corporate Finance, city growth, and regional trade are implemented.


## Archived detailed roadmap

# Roadmap

| Milestone | Deliverable | Dependencies |
| --- | --- | --- |
| 1 — Foundation (implemented) | Deterministic daily economy, production, trade, retail, accounting, AI pricing and era gates | Empty Godot project |
| 2 — Player operations (implemented) | Management/sourcing commands, time, versioned saves, Debug and isometric host | 1 |
| 3 — Construction (implemented) | City occupancy, construction/demolition, archetypes and screenshot regression workflow | 2 |
| 4 — Warehouses and logistics (implemented) | Road shipments, freight, lead times, landed-cost sourcing, depreciation and TTM/monthly HUD | 3 |
| 5 — Procedural city, population and land (implemented) | Seeded coast/roads/parcels, ambient development, districts/population, demand scaling, land values, waterfront candidates and minimap | 1–4 |
| 6 — Consumer/product economy and financial statements (implemented) | Aggregate segments, category competition, 26 products, multi-product retail, recipe selection, financial statements and monthly history | 2–5 |
| 7A — Company research core (implemented) | Company knowledge, active R&D projects, technology unlocks, non-product facilities, expense accounting and exact persistence | 3–6 |
| 7B1 - Product quality provenance (implemented) | Integer pooled goods quality, component inputs, shipments, retail and sourcing | 7A |
| 7B2 - Local-market baseline competitor and brand foundation (implemented) | Transparent baseline supply competition and minimal brand state/read-model foundation | 7B1 |
| 7B3A — Repeatable product-quality R&D (implemented) | Funded company/product quality levels affecting only newly manufactured goods | 7B2 |
| 7B3B — Production/process-efficiency R&D (implemented) | Repeatable conversion-cost improvements without changing product-quality provenance | 7B3A |
| 8A1 — Player advertising and brand growth (implemented) | Daily company-product budgets, operating expense and deterministic brand growth | 7B2–7B3B |
| 8A2A — Brand decay dynamics (implemented) | Actual-spend inactivity tracking and deterministic company-product brand decay | 8A1 |
| 8A2B — AI advertising policy (implemented) | Deterministic competitor advertising budgets and funding policy | 8A2A |
| 8B1 — Corporate headquarters facility foundation (implemented) | Data-driven headquarters construction, ownership and baseline operating model | 8A2B |
| 8B2 — Staffing and hiring (implemented) | Staff roles, hiring and payroll using the headquarters foundation | 8B1 |
| 8B3 — Headquarters/staff management effects (implemented) | Payroll-funded bounded operations, marketing, R&D and finance effects | 8B2 |
| 8UI-A1 — Visual design system foundation (implemented) | Reusable top-level theme with a corporate palette, typography and spacing hierarchy, panels, buttons, inputs, tabs and semantic state styles | 8B3 |
| 8UI-A2 — Game shell, HUD and navigation (implemented) | Application bar, gameplay navigation, facility context bar, financial HUD, profit trend, time controls and subtle status presentation | 8UI-A1 |
| 8UI-B1 — Facility management foundation + production/retail (implemented) | Persistent facility header, Overview/Operations information architecture, structured factory controls and retail line management | 8UI-A2 |
| 8UI-B2 — Sourcing, logistics and warehouse management (implemented) | Structured supplier policies and ranked offers, shipments, transfer quotes, warehouse overview and replenishment management | 8UI-B1 |
| 8UI-B3 — R&D and headquarters/staffing management (implemented) | Structured R&D Overview and project workflow plus headquarters finance, staffing, payroll and management-effect presentation | 8UI-B2 |
| 8UI-B4A — Financial reports, history and company comparison (implemented) | Structured financial statements with report hierarchy, monthly history and one-row-per-company comparison | 8UI-B3 |
| 8UI-B4B — Markets and advertising management (implemented) | Structured product-market information, advertising workflow, Local/market benchmarks, corporate offers, realized shares and category demand without changing market or advertising systems | 8UI-B4A |
| 8UI-B — Management interface redesign (complete through B1/B2/B3/B4A/B4B) | Facility operations, sourcing/logistics, R&D/headquarters, financial reports and Markets management | 8UI-A2 |
| 8UI-C — City/build interaction polish (implemented) | Polished construction and placement feedback; city select/deselect/context flow; tooltips and status presentation; pause/application menu; Save / Load / Settings organization; three-slot save browser; overwrite/load/new-session confirmations; and removal of the persistent raw Slot selector | 8UI-B |
| 8C — Strategic competitor AI (implemented) | Deterministic monthly market entry, investment, staffing, sourcing, warehouses and business-aligned research | 8UI-C |
| 8D — Difficulty and balancing (implemented) | Fixed session difficulty, no-cheat StrategicAI profiles and deterministic balance matrix | 8C |
| 9 — Corporate finance (implemented) | Public/private ownership, share registry, stock market, valuation, issuance, dividends and corporate control | 6 and 8 |
| 10 — City growth and property (implemented) | Growth/migration, land acquisition, apartment/office development, rent, redevelopment and employment links | 5–8 |
| 11 — Regional scale and trade (implemented) | Three independent cities, public ports, city markets, inter-city freight, imports/exports and regional AI | 4–10 |
| 11R — Large-scale procedural city generation (implemented) | 128 × 96 maps, terrain archetypes, rivers/bridges, urban centers, spatial districts, hierarchical roads, batched rendering and neighborhood camera | 11 |
| 11R2 — Metropolitan city profiles and street-network correction — implemented | 36 real-city profiles, population-scaled maps, spaced one-cell street blocks and bounded AI site search | 11R |
| 12 — Modes and complete-game production (next) | Tutorial campaign, full sandbox setup, catalog breadth, finished art/audio/accessibility/tutorial presentation and final balancing | 1–11R2 |

Milestone 11 adds the [regional trade model](REGIONAL_TRADE.md) to the
[real-estate model](REAL_ESTATE.md). Milestone 11R adds the
[large-city generator](CITY_GENERATION.md). Current versions are economy schema 21,
catalog 12, save format 2. Milestone 12, Modes and complete-game production,
is next.

Milestone 5 replaces the fixed starting board in normal games without changing the
daily economic scheduler or logistics contracts. Save schema 5 stores generated
state, protecting ongoing games from later algorithm changes. The old board is an
explicit regression fixture; its existing checks remain alongside generated-city tests.

Milestone 6 makes market size and financial outcomes inspectable before
introducing property ownership or international trade. Keep the current population
model as its aggregate input and preserve existing price/quality responses. Land
values were estimates at that checkpoint; Milestone 10 now uses them as acquisition
prices while owned land remains carried at cost.

Supplier reliability scoring, fleet/route capacity and traffic remain possible
extensions. Every milestone preserves deterministic headless execution, exact save
continuation, shared tutorial/sandbox systems and programmatic rendered validation.
No branch or commit is created automatically.

8UI-A2 establishes the desktop strategy-game shell without simulation changes:
the application bar separates company identity and primary Company/Build navigation
from application control; a facility context bar fronts the city workspace;
and a unified bottom HUD presents cash, TTM profit, monthly trend, date, grouped time
controls and status feedback.

8UI-B1 establishes the reusable facility-management foundation without simulation
changes. A persistent facility header now carries catalog identity, owner, facility ID,
operating state and quick actions. Production and retail facilities use Overview and
Operations pages with structured factory metrics, production controls and retail line
management.

8UI-B2 applies that foundation to sourcing, logistics and warehouses without simulation
changes. Sourcing now exposes the selected product, current policy, queued supplier
choice, ranked offer rows and today's purchases. Logistics separates active shipments
from retained deliveries and provides a live quote for manual transfers. Warehouses now
use structured storage, inventory, operations and activity metrics plus a dedicated
Replenishment workflow with target summaries and a target quantity independent from
manual transfers.

8UI-B3 applies the same structured management language to R&D centers and Corporate
Headquarters without changing simulation behavior. R&D uses Overview and Research
pages with capacity, active-project and company-knowledge summaries plus structured
technology, product-quality and process-efficiency project detail. Headquarters uses
Overview and Staffing pages with facility finances, all four configured management
effects, payroll/activation status and role-level hire/dismiss management. 8UI-B4A
structures financial statements, history and company comparison; 8UI-B4B structures
Markets, advertising, observable offers, realized shares and segment demand. The
entire 8UI-B management-interface block is complete. 8UI-C completes the dedicated
UI block with the structured construction workflow, specific placement/parcel
feedback, city select/deselect context, concise tooltips and semantic status, a
simulation-gating application menu, Save / Load / Settings organization, a validated
three-slot browser, overwrite/load/new-session confirmations and removal of the
persistent raw Slot selector. The complete 8UI-A / 8UI-B / 8UI-C block, 8C Strategic
competitor AI and 8D Difficulty and balancing are implemented. Milestone 8 is complete;
The Milestone 9 checkpoint led to Milestone 10 city growth and property, now implemented.


Milestone 6 deliberately excludes borrowing, taxes and transaction-journal complexity.
Its categorized accounts and exact cash/equity reconciliations provide the foundation
for later debt, dividends and ownership. Headquarters construction, aggregate
staffing, payroll and bounded management effects are implemented; mergers, real
estate, active ports/import/export and multi-city play remain future systems.
Quality provenance is implemented in 7B1; Local competition and static company-product
brand in 7B2; repeatable product-quality and conversion-cost process R&D are
implemented in 7B3A/7B3B. Milestone 8A1 adds player advertising without changing
brand provenance: brand remains company-product market-presence state, not
manufacturer provenance carried through inventory. Milestone 8A2A adds deterministic
decay for public products after unfunded advertising inactivity. Milestone 8A2B adds
the bounded weekly AI advertising policy without strategic ROI or expansion logic.
Milestone 8B1 adds the one-per-company productless headquarters building. Milestone
8B2 adds aggregate company staff, HQ capacity, authorized hiring/dismissal and
all-or-nothing daily payroll. Milestone 8B3 adds the four payroll-funded bounded
effects. Milestone 8C adds a stateless monthly strategic planner that uses ordinary
commands for assortment, capital, staffing, sourcing, warehouses and R&D while the
weekly price/advertising policies remain tactical. Milestone 8D adds fixed no-cheat
difficulty profiles around that policy and validates them through a deterministic
five-case balance matrix. Final production polish remains in Milestone 12.
