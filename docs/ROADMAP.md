# Roadmap

| Milestone | Deliverable | Dependencies |
| --- | --- | --- |
| 1 — Foundation (implemented) | Headless daily economy, data, companies, production, trade, retail, accounts, minimal AI, era gates, tests/debug host | Empty Godot project |
| 2 — Reliable player operations and persistence (implemented) | Configure/source commands, validation feedback, company/market panels, versioned save/load and deterministic continuation; ranked sourcing; initial isometric management host | 1 |
| 3 — Playable city and logistics | Placeholder isometric city, placement, warehouses, shipments, transport costs, facility upgrades | 2 |
| 4 — Rich markets and statements | Household segments/budgets, substitution, brand/advertising, quality lots, full journals, balance sheet/cash flow, borrowing | 2; logistics costs from 3 |
| 5 — Research and catalog expansion | Company research, technology progression, efficiency, resources, farming, broader modern chains | 3–4; era definitions from 1 |
| 6 — Competitive management | AI investment/sourcing/research, headquarters, hiring, difficulty settings and long-run balancing | 2–5 |
| 7 — Corporate finance | Public/private ownership, share registry, exchange, valuation, issuance, dividends, acquisitions/control | 4 and 6 |
| 8 — Modes and scale | Guided tutorials, configurable sandbox, multiple cities, regional markets, performance budgets | 3–7 |
| 9 — Complete-game production | Catalog breadth, polished dense UI/city art, accessibility, audio, scenarios, balancing and regression suites | 1–8 |

Milestone 2 makes the existing economy controllable and restorable without
enlarging the catalog. Construction was not pulled forward; the initial city is a
selection/management host, while placement and logistics remain Milestone 3.
Every milestone retains headless runs and adds
invariant tests for its new systems. Tutorial content follows stable gameplay;
scenario definitions and shared simulation support both modes from the start.
Stock trading must wait for trustworthy statements and ownership semantics.
Multiple cities must wait for explicit delivery and locality.
