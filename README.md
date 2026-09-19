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

## Milestone 7B1

Manufactured goods now carry integer pooled quality through components, warehouses,
shipments and retail. Consumer and supplier offers use actual stocked product
quality. Stores do not change goods quality. Saves use **economy schema 8 / catalog 3
/ format 2**; older schemas are incompatible. [Quality rules](docs/ECONOMY.md#milestone-7b1-product-quality-provenance).
Run `tests/milestone7b1_tests.gd` for focused checks and `tests/quality_smoke.gd`
for two programmatic rendered frames. Continuous R&D and Local/brand are deferred.

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
Milestone 6 screenshots are in `.godot/m6-screenshots/`. R&D screenshots are in `.godot/m7a-screenshots/`. Continuous research,
strategic AI, advertising and corporate finance remain future work.
