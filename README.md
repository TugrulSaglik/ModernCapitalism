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

## Milestone 3

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
restore together using schema 3 / save format 2 (older saves are rejected).

Use **Build**, choose a facility and product, then click a green site touching a
road. Red previews explain invalid sites. Right-click or Escape cancels. Select
an owned facility to manage or demolish it. Demolition requires confirmation,
writes off its inventory and pays no refund. Construction is expensed immediately.
Warehouses currently provide passive storage infrastructure; logistics is deferred.

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

Screenshots are written to `.godot/m3-screenshots/`. Milestone 3 deliberately
defers shipments and transport costs, active company research, full financial
statements, multi-product stores and broader catalog content. See the roadmap.
