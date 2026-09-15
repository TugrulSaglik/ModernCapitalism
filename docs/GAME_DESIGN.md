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
Daily headless economy, a small electronic-device chain, one abstract city,
cash-constrained production and trade, consumer sales, basic accrual accounts,
price-adjusting AI and two starting eras. Milestone 2 adds continuous time,
player management commands, ranked/manual sourcing, deterministic save/load,
an orthographic city host and facility/company panels. Player construction,
logistics, active research, stock exchange and credit are not implemented.
