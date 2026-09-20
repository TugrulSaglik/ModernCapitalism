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
| 8 — Competitive management | AI investment/sourcing/research, corporate headquarters, hiring, difficulty, advertising/branding and balancing | 2–7 |
| 9 — Corporate finance | Public/private ownership, share registry, stock market, valuation, issuance, dividends and corporate control | 6 and 8 |
| 10 — City growth and property | Growth/migration, land acquisition, apartment/office development, rent, redevelopment and employment links | 5–8 |
| 11 — Regional scale and trade | Multiple cities, operating ports, imports/exports, inter-city shipments and larger AI economies | 4–10 |
| 12 — Modes and complete-game production | Tutorial campaign, full sandbox setup, catalog breadth, polished UI/art, accessibility, audio and balancing | 1–11 |

Milestone 5 replaces the fixed starting board in normal games without changing the
daily economic scheduler or logistics contracts. Save schema 5 stores generated
state, protecting ongoing games from later algorithm changes. The old board is an
explicit regression fixture; its existing checks remain alongside generated-city tests.

Milestone 6 makes market size and financial outcomes inspectable before
introducing property ownership or international trade. Keep the current population
model as its aggregate input and preserve existing price/quality responses. Land
values are currently estimates only; a future ownership milestone must define
non-depreciating land assets and demolition/redevelopment treatment before charging
for acquisition.

Supplier reliability scoring, fleet/route capacity and traffic remain possible
extensions. Every milestone preserves deterministic headless execution, exact save
continuation, shared tutorial/sandbox systems and programmatic rendered validation.
No branch or commit is created automatically.


Milestone 6 deliberately excludes borrowing, taxes and transaction-journal complexity.
Its categorized accounts and exact cash/equity reconciliations provide the foundation
for later debt, dividends and ownership. Headquarters, advertising/branding, mergers,
real estate, active ports/import/export and multi-city play remain future systems.
Quality provenance is implemented in 7B1; Local competition and static company-product
brand in 7B2; repeatable product-quality and conversion-cost process R&D are
implemented in 7B3A/7B3B. Milestone 8 is next; no additional Milestone 7 feature is implied.
