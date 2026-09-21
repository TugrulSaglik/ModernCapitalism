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
| 8UI-A2 — Game shell, HUD and navigation (next) | Redesign the game shell, top controls, navigation and financial/time HUD using the shared design system | 8UI-A1 |
| 8UI-B — Management interface redesign | Redesign facility management, sourcing/logistics, R&D, HQ/staffing, Markets and financial reports using the new design system | 8UI-A2 |
| 8UI-C — City/build interaction polish | Polish city selection, construction, contextual actions, tooltips, confirmations and status/notification presentation | 8UI-B |
| 8C — Strategic competitor AI | Strategic AI investment, sourcing and research decisions | 8UI-C |
| 8D — Difficulty and balancing | Difficulty settings and competitive/economic balancing | 8C |
| 9 — Corporate finance | Public/private ownership, share registry, stock market, valuation, issuance, dividends and corporate control | 6 and 8 |
| 10 — City growth and property | Growth/migration, land acquisition, apartment/office development, rent, redevelopment and employment links | 5–8 |
| 11 — Regional scale and trade | Multiple cities, operating ports, imports/exports, inter-city shipments and larger AI economies | 4–10 |
| 12 — Modes and complete-game production | Tutorial campaign, full sandbox setup, catalog breadth, finished art/audio/accessibility/tutorial presentation and final balancing | 1–11 |

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
effects while leaving AI hiring and HQ construction deferred. The dedicated UI/UX
block 8UI-A1 through 8UI-C now precedes strategic competitor AI in 8C; final production
polish remains in Milestone 12.
