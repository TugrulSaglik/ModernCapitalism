# Economic model

## Milestone 8C strategic competitor AI

AI price and advertising decisions retain their existing seven-tick tactical cadence.
Capital and portfolio strategy runs once on calendar day 1 before the day's command
boundary. The cadence is derived entirely from `SimClock`; no last-run marker, plan
queue, personality or reservation is authoritative or saved. Companies are visited
in ascending ID order and only `company.ai == true` participates.

For public consumer product `p` and AI company `c`, the integer opportunity score is:

`4 × p.daily_demand + 2 × max(0, category potential − realized units)`
`+ 3 × product Local units − floor(100 × company units / product realized units)`.

The share term is zero when no units were realized. Resale candidates must be public,
consumer-facing and supported by at least one retail archetype; retail does not require
manufacturing knowledge. A store with a spare slot may add its best supported product
at score 40 or above, at most one line per store per month. This happens before new
retail construction. Retail archetypes maximize capacity per construction cost, then
prefer lower absolute cost and stable ID. Retail networks are conservatively bounded
to three locations by this policy.

Every capital command must leave
`reserve = max(5,000,000 cents, floor(current cash / 4))`, and each AI may construct
at most one facility per monthly pass. Candidate priority is: structurally missing
recipe-input producer, headquarters, first R&D center, vertical integration for a
sold product, retail expansion, then first warehouse. All construction uses the
ordinary validation path. Placement scans valid cells, minimizes Manhattan distance
to an owned facility, and breaks ties by y then x. Planned footprints are reserved
only within the current pass so different AIs do not intentionally collide. Existing
factories do not churn products and the planner does not demolish facilities.

An operating HQ targets two operations managers for any production/retail activity,
one marketing manager for one retailer or two for multiple retailers, two R&D
managers when a lab exists, and one finance manager for commercial operations.
Targets are clipped to HQ capacity. Hiring requires post-investment cash to cover
the reserve plus 60 days of the resulting catalog payroll. Roles whose applicable
activity disappears are dismissed; small cash fluctuations do not trigger layoffs.
Normal all-or-nothing daily payroll and all management-effect formulas are unchanged.

One R&D center is built only when commercial operations and a useful project exist.
Technology research scores manufacturing unlocks used by current retail, production,
dependencies or high-opportunity products, then breaks ties by public year and ID.
When no relevant technology is eligible, continuous projects consider only actually
manufactured products, ordered by opportunity, lower attained level, product ID and
product quality before process efficiency. Idle operating labs are evaluated daily
and receive ordinary `assign_research` commands; research work, cost and completion
formulas are unchanged.

One warehouse becomes eligible at three owned production/retail facilities. It targets
at most six products sold downstream or consumed as recipe inputs, ordered by daily
requirement, opportunity and product ID. Integer proportional allocation never exceeds
physical capacity. Downstream facilities pin a road-connected owned warehouse only
when that product has a positive target; all other supplier policies are reset to the
existing Automatic mode. SupplierMarket ranking and replenishment mechanics are not
duplicated or changed.

Strategic actions grant no cash, inventory, knowledge, demand, research speed or
operating bonus. Schema 15, catalog 9 and save format 2 are unchanged; the decision
trace and same-pass footprint reservations are transient. Save/load continuation is
therefore derived from the same clock, market, city and company state.

## Milestone 8B3 funded staff management effects

Management effects are active only when a company has at least one staff member,
the most recently processed complete daily payroll was funded, and its live
headquarters is configured as operating. Payroll runs before ordinary facility
activation, so this gate deliberately reads persistent `operating`, not transient
facility `active`. `staff_payroll_funded` resets false at begin-day, remains false
for no staff or unaffordable payroll, becomes true only after the full payroll is
paid, and is persisted for exact completed-day validation. A suspended HQ continues
to owe and pay payroll but disables all effects; resumption can reactivate them only
after the next successfully funded payroll.

Catalog role definitions provide an effect kind, positive integer percentage per
staff member and cap. The provisional settings are Operations +10% each, capped
at +30% production/retail capacity; Marketing +10%, capped at +30% advertising
progress; R&D +10%, capped at +30% research rate; and Finance -5%, capped at -15%
ordinary facility overhead. For active effects, `bonus = min(count × per_staff,
cap)` in integer percentage points.

Operations uses `floor(base_capacity × (100 + bonus) / 100)` for daily production
and retail checkout limits, production finished-stock/input targets, retail
replenishment targets and consumer-offer availability. Base `SimFacility.capacity`
is never mutated. Warehouse physical storage, HQ staffing capacity, footprint,
inventory, shipments and recipe quantities remain unchanged.

Funded advertising still pays and expenses exactly its configured budget, while
retained progress receives `floor(budget × (100 + bonus) / 100)`. Thresholds,
budgets, brand cap/decay, Local and the AI budget policy are unchanged. Each funded
R&D center still pays the same project daily cost and adds `floor(base_rate ×
(100 + bonus) / 100)` work to technology, quality or process-efficiency projects.
Required work, eligibility, ordering and retained-progress rules are unchanged.

Finance changes only actual ordinary overhead paid by production, retail, warehouse,
R&D and operating HQ facilities: `floor(base_overhead × (100 - reduction) / 100)`,
with positive overhead retaining a one-cent minimum. It does not discount payroll,
advertising, research projects, production conversion, inventory, freight,
construction, depreciation or demolition. Reduced overhead naturally lowers cash
and operating expense; no benefit income/category is invented. Schema 15 / catalog
9 / save format 2 persist the payroll-funded flag and validate completed-day counters
against the applicable effective capacity. Schema 14 has no migration.

## Milestone 8B2 staffing, hiring and payroll (implemented historical checkpoint)

`SimCompany.staff_counts` stores one nonnegative integer count for each catalog role:
operations manager (5,000 cents/day), marketing manager (5,000), R&D manager (6,000)
and finance manager (5,500). There are no individual employees. A live Corporate
Headquarters provides its dedicated catalog staffing capacity of eight; staff state
remains company-owned rather than facility-owned.

Hiring and dismissal use authorized commands at the ordinary between-day boundary.
Both require the owned live headquarters, a known role and positive integer quantity.
Hiring additionally requires the HQ's persistent `operating` setting and available
total capacity; it deliberately does not depend on transient daily `active` state.
Dismissal is allowed while suspended and cannot reduce a role below zero. Hiring and
dismissal move no cash and have no delay, fee, bonus or severance.

After daily commands and before advertising, payroll is the sum of count × catalog
daily salary across roles. If cash covers the entire amount it is paid once and
recorded separately as `payroll_expense`, operating expense and operating cash
expense. Otherwise nothing is paid, cash cannot overdraw, employees remain employed
and no wage liability is created. This all-or-nothing treatment is an explicit
limitation until a debt/payables system exists.

Suspending headquarters prevents hiring and avoids its ordinary 2,500-cent building
overhead, but does not dismiss staff or stop payroll; depreciation also continues.
A headquarters with any staff cannot be demolished until every role count is zero.
At the 8B2 checkpoint schema 14 / catalog 8 / save format 2 persisted and validated
exact counts, capacity and the required live HQ. Its former no-effects rule is
superseded by the bounded 8B3 behavior above.

## Milestone 8B1 corporate headquarters foundation (historical checkpoint)

`corporate_headquarters` is a catalog-defined Corporate facility available in both
starting eras. It has a 4 × 3 footprint, costs 5,000,000 cents to construct and has
2,500 cents of daily overhead. Each company may own at most one live headquarters
globally; the relationship is derived from facilities, and demolition permits a
replacement. AI companies do not construct headquarters in this milestone.

Headquarters shares the explicit productless facility contract with R&D but has its
own `headquarters` behavior. It has no product, assortment, price, inventory,
supplier, replenishment target, shipment, production, consumer sale or research
assignment. Construction is ordinary investing cash/capex/fixed asset activity.
While operating, affordable overhead is ordinary other operating/cash expense.
Suspension removes only overhead: ownership and footprint remain, and fixed-asset
depreciation continues over 3,650 days. Demolition pays no refund and writes off the
remaining book value through the existing disposal-loss path; inventory loss is zero.

At the 8B1 checkpoint economy schema 13 and save format 2 were unchanged. Catalog 7 identified
the added type. Restore requires empty product/logistics/research state and rejects
more than one headquarters per company. Headquarters has no advertising, brand,
research, quality, efficiency, capacity, supplier, pricing, AI or demand effect.
Staffing and management functions begin in Milestone 8B2.

## Milestone 8A2B advertising, brand growth, decay and AI policy

Each company has an integer-cent daily advertising budget and retained advertising
progress for every consumer product; both default to zero. At the start of each
simulation day, after queued commands, positive budgets are paid in full or skipped
in full when cash is insufficient. Paid advertising is an operating and cash expense,
never an asset.

For current company-product brand `b`, the next point costs
`reference_price * (20 + b) / 10` cents. This is the integer equivalent of
`reference_price * (2 + b / 10)` while retaining tenths. Each crossed threshold is
subtracted, one brand point is awarded, and the threshold is recomputed; excess
progress remains and multiple points may be earned in a day. Brand is capped at 100.

Each company also stores consecutive advertising inactivity days for each consumer
product. Only public products advance this counter. A day with actual fully funded
advertising resets it to zero and cannot decay brand; a zero budget or unaffordable
positive budget increments it. Days 1–30 are a grace period. Brand then loses one
point on inactive days 60, 90, 120 and every following 30-day boundary, bounded at
zero. Retained advertising progress is never reduced by inactivity. Products locked
by public technology/era gates remain at zero inactive days until they become public.
Decay has no cash, expense, inventory, asset or liability entry.

On the existing seven-day AI decision cadence, each AI company derives advertising
budgets for public consumer products that are configured in an owned retail facility
and have current stock, incoming stock or a positive sale in that facility's retained
seven-day product history. All other public consumer-product budgets are set to zero.
For each eligible product below its catalog-derived Local brand, the desired daily
budget in integer cents is `ceil(advertising_threshold(product, current_brand) / 30)`.
Products at or above Local receive zero.

Aggregate configured AI daily advertising is capped at
`floor(current_company_cash / 1000)`. Allocation considers the largest Local-brand
deficit first and uses ascending product ID for ties; each product receives the
minimum of its desired budget and the remaining cap. The configured budget stays in
force until the next weekly decision. The normal daily funding path still requires
the full payment: unaffordable advertising spends nothing, advances inactivity and
may decay brand. This policy contains no ROI forecast, profitability scoring,
price coordination, sourcing, expansion or market-entry logic.

Advertising changes only the existing company-product seller/market-presence brand.
It does not alter inventory quality, either continuous R&D capability, production
cost, or the catalog-derived Local price, quality and brand. Inventory still carries
no manufacturer-brand provenance. Local neither advertises nor decays. ConsumerDemand uses the resulting brand through
its existing appeal factor and retains the same separate outside option.

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
2. On calendar day 1, AI submits bounded strategic commands; on the seven-tick cadence it also submits unchanged price and advertising commands.
3. AI submits strategic project assignments for idle labs; apply all queued commands in order.
4. Pay each company's complete affordable payroll, process advertising, deliver due shipments and charge fixed-asset depreciation.
5. Charge affordable overhead and mark active facilities.
6. Source manufacturing inputs and produce in stable facility order.
7. Replenish retailers and warehouses, accounting for goods already in transit.
8. Draw category demand shocks and allocate consumer sales.
9. Charge funded active research projects and advance work; completion grants company
   technology knowledge or one product-quality level for the next production day.
   See [research rules](TECHNOLOGY.md).
10. Record profit history, publish reports and advance the Gregorian clock.

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

At the 7B1 checkpoint manufacturing used process quality and unit-weighted component
quality directly. Milestone 7B3A now adds company/product capability to the process
side before applying the same component formula; see the current formula below.
Product `base_quality` remains unused. Retail/storage retain the legacy saved field
for compatibility but cannot transform goods. Technology unlock research does not
itself change quality.

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

## Milestone 7B3A: repeatable product-quality R&D

Every company owns an integer level 0–5 for every catalog-manufacturable product.
The state belongs to company + product, not to a facility, store or inventory pool.
A structured `product_quality` project targets exactly the next level. Target L
requires `300 × L` work points and costs `2,500 × L` cents on each funded day.
The existing R&D center rate, daily phase, cash stall, expense ledger, stop/resume
and duplicate-assignment rules apply unchanged. Technology projects remain distinct.

Eligibility requires the product to be public, supported by at least one production
facility type, and backed by company knowledge of its manufacturing technology.
The current level must be below five and no other center may hold the same next-level
project. Buying or retailing a finished good does not satisfy the knowledge rule.

For company/product level L, the exact production formula is:

`effective_process_Q = clamp(facility_process_Q + 5 × L, 1, 100)`

For recipes with inputs:

`component_Q = floor(total_consumed_quality_points / total_consumed_input_units)`

`output_Q = clamp(floor((effective_process_Q + component_Q) / 2), 1, 100)`

For zero-input/external-boundary products, `output_Q = effective_process_Q`.
Component quality therefore remains equally weighted for ordinary recipes. Higher
levels monotonically improve new output until the bound is reached.

Completion changes capability only. Existing factory stock, in-transit shipments,
warehouse pools and retailer inventory are never rewritten. Newly produced units
enter the existing quality-point pools, so mixing, shipments, supplier ranking,
retail display, consumer preference and Local-inclusive competition require no
special cases. Corporate brand and static Local values are untouched.

An idle AI center continues to prefer eligible technology unlocks. When none exist,
it selects the first eligible product-quality project in stable product-ID order.
There is no profitability or market strategy. Research spending remains ordinary
research expense with no intangible asset. Economy schema 10 / catalog 5 / save
format 2 persist levels, retained quality progress and typed active assignments;
restore validates bounds, target continuity, knowledge and duplicate assignments.

## Milestone 7B3B: repeatable process-efficiency R&D

Every company also owns an independent process-efficiency level 0–5 for each
catalog-manufacturable product. A structured `process_efficiency` project targets
exactly the next company/product level. Public availability, manufacturing facility
support, company knowledge and duplicate-assignment eligibility are identical to
product-quality projects; retail access alone never qualifies. In both starting
eras, any already-public, known product is immediately eligible.

Target level L requires `300 × L` work and costs `2,500 × L` cents per funded day.
It uses the same facility rate, cash stall, expense accounting, stop/resume progress
and end-of-day completion phase. These defaults, the level cap and the 5% reduction
per level are validated catalog data.

For company/product level L:

`reduction_percent = 5 × L`

`effective_conversion_cost = floor(base_conversion_cost × (100 - reduction_percent) / 100)`

A positive base cost retains a minimum effective cost of one cent; a zero base cost
stays zero. All arithmetic is integer cents. Production affordability, cash spending,
`production_cash` and finished inventory carrying value use the actual effective
cost. Consumed input carrying value is added unchanged. No efficiency income or
expense is invented: lower carrying value becomes lower COGS only when the new goods
are sold, producing the margin benefit through the existing accounts.

Completion never rewrites factory, in-transit, warehouse or retail inventory and
never changes previously paid production cash. Only later production uses the new
cost. Recipe quantities, component and finished physical quality, product-quality
level, corporate brand, Local, capacity, throughput and stock targets are unchanged.
Zero-input/external-boundary products use the same reduced conversion/resource cash
formula and their existing physical-quality formula.

After eligible technology projects, AI builds one stable list of continuous choices:
lowest attained level first, then product ID, then `product_quality` before
`process_efficiency`. This balances the two capabilities without profitability
reasoning and makes process research useful in 2022. Economy schema 11 / catalog 6 /
save format 2 persist levels, partial progress, active kind/product/target and exact
continuation. Restore validates product, public/manufacturable status, knowledge,
bounds, next target, progress range and duplicate assignments.
