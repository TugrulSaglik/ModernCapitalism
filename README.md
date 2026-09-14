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

## Milestone 1

Implemented: a deterministic, daily headless electronics economy with five
companies, nine facilities and five products. Components feed phone assembly;
retailers source phones and compete on price/quality. Inventory carrying values,
cash, revenue, COGS, overhead and profit are tracked. Starting years 2012 and 2022
use data-driven public technology gates. Weekly AI pricing participates in the
same command processing as player commands.

Open `project.godot` in Godot 4 (tested with **4.7.2**) and press **F6** for the
debug scene or **F5** for the project. The debug screen offers era selection,
reset, and 1/30/365-day advances. Changing era takes effect when Reset is pressed.
No city renderer is required for any economic calculation.

### Command line (PowerShell, from repository root)

Use your installed Godot console executable. On this machine:

```powershell
$godot = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
# Register classes on a fresh checkout (opening the editor also does this).
& $godot --headless --path . --editor --quit
# Run the debug project.
& $godot --path .
# Automated harness, including one-year runs for both eras.
./tests/run_tests.ps1 -Godot $godot
# Direct Godot-native harness (also works outside Windows).
& $godot --headless --path . --script res://tests/run_tests.gd
# Longer headless scenario; output is a state snapshot followed by a summary.
& $godot --headless --path . --script res://src/headless.gd -- --days=3650 --era=2012 --seed=42
# Load the actual debug scene and exercise its 30-day advance.
& $godot --path . --script res://tests/debug_smoke.gd
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

This foundation deliberately defers actual company research, logistics, save
restore, full financial statements and city gameplay. The next milestone is
player operation commands, management panels, and versioned save/load/replay.
