# Game design

## Target game
A large single-player corporate simulation inspired by classic Capitalism-style
games. Players build firms across extraction, agriculture, industry, logistics,
retail, research and finance. An orthographic/isometric city provides spatial
context; information-dense management screens expose operations and accounts.
Economic decisions, rather than city rendering, drive the game.

The core loop is to identify demand, source or manufacture products, choose
capacity, price and quality, sell against competitors, review accounts and
reinvest. Later loops add branding, research, corporate control and capital markets.
Player and AI firms obey the same inventory, cash and technology constraints.

## Major systems
- Companies: cash, accounts, operating facilities, management and ownership.
- Supply: resources, farms, recipes, factories, inventories, warehouses and transport.
- Markets: household segments, needs, substitution, price, quality, brand and market share.
- Development: public technology availability, firm research, process efficiency and product improvements.
- Finance: financial statements, borrowing, stock issuance/trading, dividends and control.
- Presentation: cities, placement, facility panels, company reports and market comparisons.
- Scenarios: era, cities, competitors, difficulty, objectives and starting assets.

## Modes
Sandbox configures a scenario and continues without scripted objectives. Tutorial
scenarios configure the same simulation and attach a guidance/objective layer to
commands and reports. Tutorials must not implement an alternative economy.
Difficulty changes scenario parameters and AI decision budgets; any economic
advantages must be explicit settings, never hidden exceptions in core systems.

## Implemented foundation
Daily headless economy, a small electronic-device chain, one city,
cash-constrained production and trade, consumer sales, basic accrual accounts,
price-adjusting AI and two starting eras. Milestone 2 adds continuous time,
player management commands, ranked/manual sourcing, deterministic save/load,
an orthographic city host and facility/company panels. Milestone 3 adds city
occupancy, roads, construction, demolition and category-specific procedural
buildings. Milestone 4 adds explicit shipments, operational warehouses, freight,
delivery lead times, fixed assets and a persistent financial HUD. Active research,
stock exchange and credit remain deferred.

## Construction loop and starter archetypes
Open Build, choose a facility/product, inspect its cost and size, and click a valid
road-adjacent site. Construction works while paused. The new facility immediately
appears in the management inspector, while its economic activity begins on the
next day. Existing price, stock, supplier and suspension controls apply according
to role. Owned demolition asks for confirmation and discards inventory, with no refund.

| Archetype | Footprint | Cost | Role |
| --- | --- | ---: | --- |
| Small general store | 2 × 2 | $10,000 | Small retail, 10 units/day |
| Electronics store | 3 × 2 | $20,000 | Device retail, 24 units/day |
| Department store | 4 × 3 | $32,000 | Larger retail, 35 units/day |
| Component plant | 4 × 3 | $35,000 | Component production, 40 units/day |
| Assembly factory | 4 × 3 | $45,000 | Device production, 18 units/day |
| Warehouse | 5 × 3 | $25,000 | 100-unit storage, transfers and replenishment |

Definitions specify construction cost, footprint, category, visual style, behavior,
capacity, overhead and supported products. All retail currently sells one selected
phone product; the small catalog has not been expanded into groceries or general
merchandise. Warehouse transfers reserve inbound capacity; a per-product target
can request automatic replenishment. Construction capitalizes its cost and daily
depreciation expenses it over 3,650 days. Demolition writes off remaining book value.
Debug cash controls remain sandbox-only and session-unlocked. No new cheat or
free-building mode was added.
