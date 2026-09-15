# Economic model

## Units and firms
One tick is one calendar day. Quantities are whole units, currency integer cents,
quality an integer 1–100. Every company starts with contributed equity and cash;
there is no credit, tax, depreciation or dividend yet. Every facility
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
Wholesale transfers move inventory and cash between firms, recognizing seller
revenue and COGS and buyer inventory assets. Same-company transfers carry book
cost and create no revenue. Inventory uses pooled carrying cost with proportional
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
`cash + inventory carrying value = contributed capital + cumulative profit`.
Production cash is capitalized in inventory. Opening inventories are zero.
Reports expose daily and cumulative company accounts, inventory assets, cash,
consumer units/revenue, market share and weighted realized consumer prices.
Do not sum intercompany revenue to measure final consumer spending.

## Tick order
1. Clear daily accounts, facility throughput and market reports.
2. AI submits bounded weekly price decisions; apply queued commands in order.
3. Charge affordable overhead and mark active facilities.
4. Source manufacturing inputs and produce in stable facility order.
5. Replenish retailers from same-city stock.
6. Draw product demand shocks and allocate consumer sales.
7. Publish market results and advance the Gregorian clock one day.

Reports describe the day just completed; displayed clock is the next day to run.
Quality is fixed per facility output/offer initially; provenance and quality-mixed
lots are deferred. Negative inventory, free purchases and overdrafts are rejected.
