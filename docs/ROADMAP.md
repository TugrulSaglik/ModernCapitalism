# Roadmap

| Milestone | Deliverable | Dependencies |
| --- | --- | --- |
| 1 — Foundation (implemented) | Deterministic daily economy, catalog, production, trade, retail, accounting, AI pricing and era gates | Empty Godot project |
| 2 — Player operations and persistence (implemented) | Management/sourcing commands, continuous time, versioned saves, session Debug and isometric host | 1 |
| 3 — City, construction and visual foundation (implemented) | Serializable city/roads/footprints, paused construction, archetypes, owned demolition, procedural buildings and screenshot regression workflow | 2 |
| 4 — Warehouses and explicit logistics (implemented) | Storage transfers/capacity, shipments, road distance, freight, lead time, landed-cost sourcing and logistics UI; fixed assets, depreciation and profit HUD | 3 |
| 5 — Rich markets and financial statements | Household budgets/segments, substitution, broader retail, brand/advertising, quality lots, journals, full balance sheet/cash flow and borrowing | 2–4 |
| 6 — Research and catalog expansion | Active company R&D, technology progression, efficiency, resources, agriculture and broader modern product chains | 3–5; era gates from 1 |
| 7 — Competitive management | AI investment/sourcing/research, headquarters, hiring, difficulty and long-run balancing | 2–6 |
| 8 — Corporate finance | Public/private ownership, share registry, stock market, valuation, issuance, dividends and corporate control | 5 and 7 |
| 9 — Modes and scale | Tutorial campaign, configurable sandbox, multiple cities, regional demand/markets and performance budgets | 3–8 |
| 10 — Complete-game production | Catalog breadth, polished dense UI/city art, accessibility, audio, scenarios, balancing and regression suites | 1–9 |

Milestone 4 makes warehouse buildings operational with capacity reservations,
manual and automatic transfers, buyer-owned in-transit inventory, road routing,
freight and deterministic delivery. It capitalizes new construction, depreciates
it daily and adds TTM/monthly profit history. Supplier reliability based on
observed delivery performance remains future work; current quotes use a fixed
deterministic lead time. Vehicles and traffic are not simulated.

Later milestones retain the broad Capitalism-style scope: HQ, R&D, advertising,
stock market/control, advanced AI, broad retail/product catalogs and multiple cities.
Every milestone preserves headless execution and expands invariants and save tests.
Tutorials use the same commands and simulation as sandbox. Stock trading waits for
trustworthy statements and ownership semantics; multiple cities wait for explicit
locality and delivery. No branch or commit is created automatically.
