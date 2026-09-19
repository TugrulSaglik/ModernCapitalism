# Economic model

## Units and firms
One tick is one calendar day. Quantities are whole units, currency integer cents,
quality an integer 1–100. Every company starts with contributed equity and cash;
there is no credit, tax or dividend yet. Every facility
has one owner and city, a data-defined type, capacity and local inventory.

## Production and sourcing
Products define recipes, conversion cost, reference price and consumer demand.
An empty recipe denotes an abstract external raw-input boundary: producing such
a component pays external conversion/resource costs. Factories buy missing
inputs from available same-city offers, limited by cash and stock, then produce
up to daily capacity. Production is atomic per batch. Inputs and conversion cash
become output carrying value; they are not expensed again at production time.
Producers start at the reference price. Eligible same-city production offers are
ranked by price per quality point with stable facility-ID ties. A facility may use
the automatic ranking or pin one supplier for each sourced product; a pinned
supplier does not silently fall back when unavailable. Facilities operate in stable
ID order, so same-day upstream output may serve downstream facilities. This still
favors earlier buyers when supply is scarce; future wholesale market clearing
should replace sequential allocation explicitly.

Facilities keep a configurable one-to-seven-day finished-stock target. Retailers
replenish to that target, then sell at posted prices.
Wholesale transfers create buyer-owned shipments and settle cash at departure,
recognizing seller revenue and COGS and buyer inventory assets in transit.
Same-company transfers carry book cost and create no revenue. Freight is paid and
expensed by the buyer at departure. Inventory uses pooled carrying cost with proportional
integer removal; the last unit removes the exact remaining cents.

## Consumers and competition
Households are an external sector with finite daily potential units per product.
A seeded daily shock varies potential demand by ±10%. Each offer's appeal is
`(reference_price / price)^1.4 * quality / 50`, bounded to avoid singularities.
Potential buyers choose against an outside option of weight 1: at each sale the
available offers receive proportional shares of deterministic cumulative targets.
Total desired purchases are `floor(potential * total_appeal / (1 + total_appeal))`.
Allocate units by greatest unmet proportional target, stable ID ties, subject to
inventory and retail throughput. Thus higher price lowers an isolated offer's
demand; higher quality increases it. Stockouts can leave demand unserved.
There is no household income ledger or cross-product substitution yet.

## Accounting and statistics
Revenue includes wholesale and retail sales. COGS is the carrying value sold;
operating expenses are affordable daily facility overhead. An unaffordable
overhead payment suspends that facility for the day (no debt is silently accrued).
Profit = revenue − COGS − operating expenses. Balance invariant:
`cash + local/in-transit inventory carrying value + net fixed assets = contributed capital + cumulative profit`.
Production cash is capitalized in inventory. Opening inventories are zero.
Reports expose daily and cumulative company accounts, inventory assets, cash,
consumer units/revenue, market share and weighted realized consumer prices.
Do not sum intercompany revenue to measure final consumer spending.

## Tick order
1. Record prior between-day profit and clear daily accounts.
2. AI submits bounded weekly price decisions; apply queued commands in order.
3. Deliver due shipments and charge fixed-asset depreciation.
4. Charge affordable overhead and mark active facilities.
5. Source manufacturing inputs and produce in stable facility order.
6. Replenish retailers and warehouses, accounting for goods already in transit.
7. Draw product demand shocks and allocate consumer sales.
8. Record profit history, publish reports and advance the Gregorian clock.

Reports describe the day just completed; displayed clock is the next day to run.
Quality is fixed per facility output/offer initially; provenance and quality-mixed
lots are deferred. Negative inventory, free purchases and overdrafts are rejected.

## Construction and demolition (Milestone 3)
Construction costs become fixed assets, depreciated straight line over 3,650
daily ticks. Scenario buildings have no opening fixed-asset book value.

Demolition discards inventory and remaining fixed-asset book value, recognizing
both as expense without a cash payment or refund. No disposal charge or salvage applies.
Land becomes available immediately. Suspending a facility retains its inventory
and plot. Warehouse buildings incur their configured overhead when operating;
they can source toward per-product targets and send owned transfers.

Build/demolish commands flush the FIFO between days, including while paused.
Demolition losses appear in daily totals immediately; construction reduces cash
and increases fixed assets. The next tick resets daily accounts as usual.

## Logistics and profit history (Milestone 4)

Road distance is the shortest path between orthogonal road access cells plus two
facility access legs. Freight is a fixed 100 cents plus 2 cents per unit per road
cell. A shipment takes at least one day, with one day per 20 road cells rounded
up. The buyer pays purchase price and freight when dispatched, owns inventory
in transit and receives it on the due tick. Warehouse capacity includes incoming
units. Automatic replenishment subtracts both local and inbound stock from its
target, preventing duplicate orders. Supplier ranking uses unit landed cost and
a small lead-time penalty per quality point; pinned suppliers remain explicit.

Daily profit deltas feed dated history and monthly totals. The current month is
included even before its first profit change. TTM sums the available days in the
rolling calendar-year interval ending on the displayed date. Freight and
depreciation are operating expenses; purchases remain inventory assets until sale.

## Population and land foundation (Milestone 5)

Catalog daily_demand is the potential market for 5,000 residents at purchasing power
100. Each day and product uses:
`floor(base_demand * occupied_population * purchasing_power * shock / 50,000,000)`,
where shock is the existing seeded integer 90–110. All factors are multiplied
before integer division. Purchasing power is the occupied-population-weighted district
index (90, 110 or 100), rounded down. Zero population creates zero potential demand;
a near-zero population cannot inherit the previous full-sized external market.
The unchanged price/quality appeal, outside option, offer allocation, inventory
limits and stable ties then decide purchases. There is still no household cash
ledger, employment or cross-product substitution.

Houses have capacity 12, apartments 70 and larger blocks 150. Offices and generic
commercial properties have zero residential capacity. Generation assigns integer
occupied population at 80–95% of each residential capacity, rounded down.
City/district totals are sums; no citizens or daily migration are simulated.
Default seed 42 contains 2,573 residents in capacity 2,978 with purchasing power 103.

Non-road land value in cents per cell is:
`5000 + 900 * centrality + (6000 if road-adjacent) + (8000 if waterfront)`.
Centrality is `max(0, 16 - abs(x - floor(width*0.42)) - abs(y - floor(depth/2)))`.
Water and road cells have zero value. Values are deterministic, bounded below
50,000 cents and displayed through placement/Debug inspection. District averages
exclude zero-valued road/water cells. Values are foundation estimates, not a market.

Construction continues to charge only the catalog building cost, capitalized and
depreciated over 3,650 days. Land valuation does not debit cash or create an owned
land asset. This deliberately defers acquisition, retained land after demolition,
resale and rent accounting until property ownership is implemented. Demolition and
the existing accounting invariant are unchanged.
