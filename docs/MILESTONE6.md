# Milestone 6: consumer markets and financial statements

This is the Milestone 6 specification. Milestone 7A supersedes its global
technology capability, inactive R&D and schema-6 descriptions; see
[Technology](TECHNOLOGY.md). Milestone 7B3A now supersedes the deferred continuous
product-quality statements while preserving these market/accounting rules. Historical milestone sections elsewhere describe
their implementation at the time; the rules below supersede their single-product
market and profit-only reporting descriptions.

## Consumer segments and category demand

Consumers remain aggregate counts, never individual agents. Catalog `segments`
define share weights, income slopes, purchasing power, price and quality exponents,
and optional category spending multipliers. For district income index I:

`weight = max(5, base_share + (I - 100) * income_slope)`.

Normalize these weights to district population, floor each count, and distribute
the remaining people in sorted segment-ID order. Sum districts for the city.
This preserves exact population and heterogeneous districts. Counts are derived
from saved district population and catalog definitions, not independently saved.
The legacy board uses its aggregate population and purchasing-power index.

| Segment | Weight at income 100 | Income slope | Purchasing power | Price exponent | Quality exponent |
| --- | ---: | ---: | ---: | ---: | ---: |
| Value / budget | 40 | -1 | 75 | 2.0 | 0.5 |
| Mainstream | 40 | 0 | 100 | 1.4 | 1.0 |
| Affluent / premium | 20 | 1 | 150 | 0.7 | 2.0 |

Each category has daily potential per 5,000 residents, purchase-frequency
multiplier, income sensitivity, and a public technology gate. Each day, draw one
integer 90–110 shock for each category in sorted ID order. For each segment:

`potential = floor(population * category_daily_demand / 5000 * purchase_frequency
* (city_income * segment_purchasing_power / 10000)^income_sensitivity
* segment_category_preference * shock / 100)`.

The same category pool serves all its product variants. Adding another phone
does not create another full phone market. Per-product reports repeat their
category's potential for context; do not add those potentials together. Segment
potentials sum exactly to the category potential. Integer floors mean very small
populations can have zero demand. This is a unit-demand model with an external
household sector, not an income/employment/household-cash simulation.

## Competition and quality

The formula below describes the 7B1 checkpoint. Milestone 7B2 adds synthetic Local
offers and a positive brand factor, Local-inclusive shares and weighted averages;
see [current market rules](ECONOMY.md#milestone-7b2-local-market-and-brand-foundation).

For each available retail offer with stock:

`appeal = clamp((product_reference_price / retail_price)^price_sensitivity
* (inventory_product_quality / 50)^quality_sensitivity, 0.001, 100)`.

An outside option of weight 1 makes total desired purchases
`floor(potential * total_appeal / (1 + total_appeal))`. Allocate units to the
largest unmet proportional target, with stable facility/product-ID ties.
Stock and shared store throughput cap actual sales. Segment and category order
are stable, so limited checkout capacity can favor earlier categories/segments.
There is no random tie-breaking or hidden brand multiplier. Price compares with
each product's own reference price, representing its position within the category.

Milestone 7B1 replaces the facility/offer scalar with actual per-product inventory
quality, including manufacturing inputs and pooled shipment provenance. Empty stock
has no offer weight and displays "no stock". See [quality rules](ECONOMY.md#milestone-7b1-product-quality-provenance).

## Catalog and eras

The JSON catalog contains 26 products: nine components and 17 consumer goods.
Categories are components, energy storage, smartphones, computers, televisions,
wearables, appliances, and household goods. Recipes, conversion costs, reference
prices, quality defaults, technology gates and compatible facilities are data.
Validation rejects duplicate IDs, missing categories, invalid years/inputs,
technology cycles, recipe cycles, and invalid retail category permissions.

Both eras have conventional phones, laptops, desktops, tablets, televisions,
consoles, ordinary appliances and household goods available to build. Earbuds and
smartwatches open in 2015, robot vacuums in 2018, advanced phones in 2020. These are
illustrative public-availability gates, not historical invention dates or completed
company research. The 2022 scenario can operate all these products immediately.

Generated starts retain the original nine sites and add ten explicit scenario
facilities: memory, storage and electronic-component production; laptop, television,
detergent and earbud manufacturing; a department store, small general store and
warehouse. The player's and rival's electronics stores start with several lines;
locked optional lines are omitted in 2012. Locked factory sites stay reserved and
become researchable at their public date; Milestone 7A requires owner research
before those factories become usable. They do not grant mature products early.
The old nine-site coordinate scenario remains an explicit regression fixture.

Not every catalog recipe has a complete initial supply chain. Appliances and other
unserved goods are investment opportunities. AI operates configured businesses and
adjusts prices; it does not build missing plants or automatically add new lines.

## Operations and logistics

Retail `assortment` maps product IDs to prices. Small general stores have three
slots, electronics stores six electronics-only slots, department stores ten broad
consumer-product slots. Existing daily throughput is shared across lines. Each
line targets `max(1, floor(capacity * stock_days / line_count))` on-hand plus inbound
units. Supplier policies, inventory costs and shipments remain per product.

`add_line`, `remove_line`, `set_price` with product ID, `set_supplier` and
`set_production` use the existing validated FIFO command path. The old price
command without a product still addresses the primary product. At least one
retail line remains. Removing a line stops sales/replenishment but retains its
stock and already-paid shipments; re-add it or transfer the stock to use it.

Factories select one compatible recipe at a time. Switching retains every input,
finished unit and incoming shipment, clears input supplier policies, and resets
the output offer to its reference price. Downstream pins to the old output are
cleared to automatic sourcing. Daily capacity already consumed is not reset.
Old finished goods may be transferred; switching never converts them to the new
product. Recipes consume exact integer quantities and capitalize conversion cash
and input book cost. Same-owner shipments retain carrying value without revenue.

Warehouse capacity still counts all products plus inbound reservations. External
purchases settle at dispatch and become buyer-owned inventory in transit; freight
is expensed separately. Road routes, delivery dates, landed-cost supplier ranking,
cash limits and deterministic sequential wholesale allocation remain unchanged.

## Financial accounts and statements

The authoritative ledger is cumulative categorized company accounts plus dated
account deltas, rather than a new transaction-journal subsystem. This extends the
existing accounts. Revenue splits retail and wholesale. COGS is carrying value
actually sold; gross profit is revenue less COGS. Operating expenses split freight,
depreciation and other implemented overhead/disposal losses. Net profit equals
operating profit: there are no tax, interest or debt systems.

Cash counters separately record inventory purchases, production conversion cash,
cash expenses and construction capex. Contribution changes are financing activity.
Direct-method operating cash is receipts minus purchases, conversion spending and
cash expenses; investing cash is negative construction spending; financing cash is
the contribution delta. Noncash depreciation and demolition losses do not become
cash outflows. Initial cash/capital are the opening balance, not a first-month sale
or newly invented financing transaction.

Balance sheets expose cash, local inventory, transit inventory, fixed cost,
accumulated depreciation and net fixed assets. Liabilities are zero. Contributed
capital plus lifetime profit equals equity; lifetime profit is retained earnings
because there are no distributions. Construction capitalizes, daily depreciation
reduces both book value and earnings, and demolition writes off stock and remaining
asset value. Debug cash changes capital, never sales or earnings.

Every daily/between-day history boundary records account deltas once. Daily history
retains 367 dates for exact rolling-calendar TTM. Monthly history retains 13 recent
months for existing consumers, archiving older full monthly records without loss.
Monthly records include opening/closing cash and a balance-sheet snapshot. The
new month begins with zero activity and the previous closing cash. Current/previous
month, current year and TTM statements all read these records. TTM and monthly HUD
bars use the same profit deltas. Monthly History displays older retained profits.

Invariants remain integer-exact:

* Assets = liabilities + contributed capital + retained earnings.
* Opening cash + operating + investing + financing cash = closing cash.
* Revenue − COGS − expenses = net profit.

## Read models, UI and Debug

Facility inspectors use Products, Sourcing and Logistics tabs. Product controls
show configured lines, independent prices, supplier policy, on-hand/inbound units,
seven-day sales, unit book cost (or average sold cost without stock), and lifetime
gross margin before shared overhead. Factory views show recipe, input/output stock,
capacity and production selection. Rival controls remain read-only.

Company opens a dismissible dialog with Income Statement, Balance Sheet, Cash Flow,
Markets, History and Companies tabs. Money values align right and negative totals
use a minus sign/red text. Markets reports category/segment potential, product
sales, weighted realized price, competing stores/quality/stock/prices and company
product shares. Category sales retain a 90-day daily history. Values describe the
last completed day, while the clock shows the next day to execute. The default city
view and bottom financial HUD remain unobstructed when the dialog is closed.

Sandbox Debug remains password-unlocked and relocks after loading. Diagnostics
now include segment counts and the player accounting-equation difference. Normal
product and financial management do not require Debug.

## Persistence and limits

Economy schema 6 / save format 2 persists assortments, production choice, prices,
per-product lifetime/daily/seven-day sales, category reports/90-day history,
categorized accounts, financial checkpoints and archived monthly records. Segment
counts and statements are derived. Saves preserve exact integer/float tags, RNG,
pending commands and city/logistics state. Old schemas/catalog hashes fail clearly.
Hydration validates dynamic product maps, slot limits, financial-history equations,
category totals, and existing inventory/assets/city constraints before replacing
the live session. There is no migration path yet.

Deferred: supplier-specific lots, continuous R&D, product design, advertising/branding,
headquarters, strategic AI expansion, loans/bonds, taxes, dividends, share ownership,
stock markets/control/mergers, land ownership, city growth, ports/import/export and
multiple cities. No individual consumers, external dependencies or final art were
added. Recommended Milestone 7 is active R&D and quality/efficiency improvements
through existing recipes and public gates, with quality provenance introduced
explicitly and tested before quality affects production.
