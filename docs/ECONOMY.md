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

The current segment/category demand and transparent choice formula are specified
in [Milestone 6](MILESTONE6.md#consumer-segments-and-category-demand). District income
changes segment weights. Category pools are shared by all product variants, with
segment-specific price/quality exponents, a no-purchase outside option, inventory
limits and shared checkout capacity. Per-product `daily_demand` remains legacy
catalog metadata; categories now determine demand. Household cash/employment and
cross-category budget substitution remain deferred.

## Financial statements (Milestone 6)

[The accounting specification](MILESTONE6.md#financial-accounts-and-statements)
defines retail/wholesale revenue, COGS, freight, depreciation, other expenses,
operating/investing/financing cash and retained earnings. Monthly records retain
opening/closing cash and balance snapshots, with older months archived. Current
month, previous month, TTM and current-year reports use the same history as the HUD.
Production conversion is capitalized inventory and an operating cash outflow;
construction is capitalized fixed assets and investing cash. Debug capital is
financing. Milestone 7A adds explicit `research_expense` within operating expenses
and cash expenses; R&D overhead remains other expense. Research is never capitalized
as an intangible. There is no interest, debt, tax or dividend system.

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
3. Assign eligible projects to idle operating AI R&D centers, then deliver due shipments and charge fixed-asset depreciation.
4. Charge affordable overhead and mark active facilities.
5. Source manufacturing inputs and produce in stable facility order.
6. Replenish retailers and warehouses, accounting for goods already in transit.
7. Draw category demand shocks and allocate consumer sales.
8. Charge funded active research projects and advance work; completion grants company
   knowledge for the next production day. See [research rules](TECHNOLOGY.md).
9. Record profit history, publish reports and advance the Gregorian clock.

Reports describe the day just completed; displayed clock is the next day to run.
Product quality follows pooled inventory and shipments as specified below. Negative inventory, free purchases and overdrafts are rejected.

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

## Historical population demand and current land foundation (Milestone 5)

The per-product demand formula below is superseded by Milestone 6 category pools.
Population, land, construction and external-sector conventions remain applicable.

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


## Milestone 7B1: product quality provenance

Inventory holds integer quantity, carrying cost and total `quality_points` per
product. Adding Q-quality units adds `units * Q` points. `add_pooled` accepts exact
points for transfers. Displayed/offer quality is `floor(points / quantity)`;
zero stock returns 0 and UI says **no stock**, with no sellable offer weight.
For example 20 units at Q70 plus 10 at Q40 hold 1,800 points and display Q60.

`remove_pooled` atomically removes `floor(total * removed_units / quantity)`
from each pool independently, returning cost and points. The last removal takes
all remaining cents/points. Integer residues stay in the source pool; a small
outbound batch may round differently from the remaining stock. Recombining restores
exact totals. `remove` still returns carrying cost (or -1 for invalid requests).
Legacy three-argument `add` defaults to Q50 for fixtures; gameplay production and
logistics always supply explicit quality. There are no per-unit objects or lots.

Manufacturing uses `component_Q = floor(consumed_points / consumed_units)` across
all recipe inputs, weighted by units consumed, then
`output_Q = clamp(floor((process_Q + component_Q) / 2), 1, 100)`.
A zero-input external-boundary product uses clamped process_Q directly. Product
base_quality is not an additional modifier. Existing configured facility quality
is the production process baseline; retail/storage retain the legacy saved field
for compatibility but cannot transform goods. Existing scenario data and 2012/2022
knowledge are unchanged. Technology unlock research does not change quality.

Shipments carry exact removed points, including fractional pooled remainders.
Factories, warehouses and retailers use the same pool. Internal transfers retain
book cost; inter-company sales replace buyer book cost with purchase price while
retaining points. Freight never alters quality. Mixing metadata adds no cash,
carrying value or profit. Existing ledger entries and identities are unchanged.

ConsumerMarket reads each product line's current stock quality. Segment/category
potentials, price/quality sensitivities and the outside option are unchanged.
Sourcing uses stocked supplier quality in the existing landed-cost/lead-time ratio,
including owned warehouses; empty suppliers report zero quality and are ineligible.
The facility inspector and Markets report show current stock quality (not a historic
sold-quality average), alongside existing price, stock and completed-day share.

Economy schema **8** persists inventory and shipment quality points; SaveStore
checks integer types, aligned product maps, empty-state zeros and 1-100 bounds.
Catalog remains **3**, save format **2** retains exact numeric encoding. Schema 7
and earlier saves are rejected without migration. Future company/product/process
improvements can modify production's baseline before creating new goods; existing
inventory needs no redesign or retroactive mutation. No improvements are implemented.

## Milestone 7B2: Local market and brand foundation

Each public consumer product (positive product daily_demand metadata) has one
synthetic Local offer in this city. Category pools still determine finite demand;
components with no consumer demand have no Local offer. Local is background
independent commerce, with enough supply for its allocated demand and no company,
facility, inventory, shipments, cash, revenue ledger or COGS. Its spending is a
market statistic only. It never teaches corporate manufacturing knowledge.

Catalog market_defaults supplies Local price multiplier 1.15, quality 50, brand 60
and starting corporate brand 20. Optional category.market then product.market
fields override these defaults. Local price is round(reference_price * multiplier)
in cents; validation requires a positive price, integer quality 1–100 and integer
brands 0–100. Values are static, deterministic and independent of corporate goods.
Local observes the same public technology/date/Debug gates as corporate resale.

SimCompany.product_brands maps each consumer product to its authoritative integer
seller brand, including products not yet public. Player and AI share this state
and defaults; every shop of the same company uses the same product brand. Brand
does not enter inventory, shipments or production quality. Markets exposes the
player's brand read-only. No gameplay mutation, automatic growth/decay, advertising,
loyalty, or corporate/global brand system exists.

For each segment, the exact offer appeal is:

`clamp((reference_price / price)^price_sensitivity
* (stock_quality / 50)^quality_sensitivity
* (0.5 + brand / 100), 0.001, 100)`.

The existing segment price/quality exponents are unchanged. Brand's factor is
bounded 0.5–1.5, so even brand zero can sell. Empty corporate stock has zero
weight. Local uses its catalog quality and brand in this same formula. The
outside/no-purchase option retains weight 1: desired purchases are
`floor(potential * total_appeal / (1 + total_appeal))`. Stable corporate facility/
product order followed by sorted Local product IDs resolves allocation ties.
Corporate inventory and shared checkout limits still apply; Local consumes no
checkout capacity. Integer rounding can give small offers zero sales on a day.

Local is a purchase; the outside option is not. Product realized units are Local
units plus all corporate units. Company share is company units / realized units;
Local share is Local units / realized units. Outside demand is excluded, and
realized shares sum to one when any units sell. Category unrealized potential in
the UI includes no-purchase and any stock/checkout allocation shortfall.

Price, quality and brand averages are realized-sales-weighted across Local and
corporate sales. Quality uses the stocked quality observed at each segment's
sale, not current post-sale stock. Price is actual spending / units, not reference
price. Zero-sales averages use zero internally and display an em dash.

Report-only Overall is
`clamp((clamp(50 * reference_price / price, 0, 100) + quality + brand) / 3, 0, 100)`.
Market-average Overall applies this formula to the three market-average inputs;
it is not the weighted average of individual Overall scores or a second demand
allocator. It is an equally weighted comparison score, not consumer importance.

Markets now shows Local/Average price, quality, brand, Overall and realized units/
share; read-only player brand; corporate seller/retailer, current price/stock
quality, brand, last-day units and retailer share; combined company shares; segment
potential and retained category history. Other Company tabs are unchanged.
Optional Concern/Importance is deferred to later UI refinement.

Cumulative consumer units/spending and existing 90-day category history include
Local; category records also retain separate Local units/spending. Current product
reports retain Local units/share and quality/brand weighted totals. Static Local
definitions are derived, not duplicated in saves. Economy schema 9 / catalog 4 /
SaveStore format 2 persists corporate brands and expanded reports, validates brand
maps, ratings, report averages/shares and category reconciliation, and preserves
exact numeric continuation. Older schemas/catalog hashes are rejected without
migration. Debug behavior is unchanged; inspection is through Markets/snapshots.
No new product, physical Local supply chain or long-term chart is introduced.
