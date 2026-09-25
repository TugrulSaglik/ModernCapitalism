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
