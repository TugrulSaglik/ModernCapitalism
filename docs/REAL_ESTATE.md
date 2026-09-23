# Real estate and city growth (Milestone 10)

`RealEstate` owns land and economic property records. `CityMap` owns geometry,
roads, water, parcels, districts and visual footprints. Catalog 10 defines five
types: house (12 residents, $25,000 construction), apartments (70, $120,000),
block (150, $300,000), office (100 jobs, $180,000) and commercial (40 jobs,
$90,000). Each has a catalog footprint and height. Facilities also have catalog
job counts. The legacy fixed board keeps its 5,000 residents and has no property
commands.

Every owned buildable cell stores its company and historical acquisition basis.
Road and water cannot be owned. Existing scenario facilities start with their
footprint owned at zero basis. `buy_land` charges current parcel land value for
newly acquired cells and zero for the company's existing cells. Facility and
property construction automatically acquire unowned footprint land; rival land
blocks construction. Facility building cost remains its own depreciating asset.
Demolition leaves land and basis with the company.

Generated ambient buildings start outside company ownership but count toward
housing or jobs. `acquire_property` buys one such building for current footprint
land value plus catalog replacement cost; residents and job occupancy remain.
`develop_property` builds on a vacant road-accessible footprint and starts empty.
`redevelop_property` atomically writes off the old net building value, retains
owned land, acquires any extra unowned cells, and builds a new empty property.
`demolish_property` writes off remaining building value and retains land. Each
new building receives a monotonic `property_000001` style ID. Property buildings
depreciate over 3,650 days; land does not depreciate or revalue in profit.

Monthly migration targets `min(floor(housing × 95 / 100), jobs × 2)`, moves about
one twelfth of the gap, and caps movement at about 2% of current population.
Residents distribute by residential capacity with stable-ID remainder assignment.
Workforce is `floor(population / 2)`, employed is `min(workforce, jobs)` and
unemployed is the balance. Jobs are a fixed outside-sector baseline derived at
initialization, operating economic-facility jobs and office/commercial property
capacity. Suspended facilities provide no jobs. Property job occupancy is allocated
proportionally after baseline and facility employment. City and district population
continue to drive existing consumer demand.

Company-owned property gross monthly rent is `floor((current footprint land value
+ catalog replacement cost) × 12 / 1200) × occupied / capacity`, with integer
rounding. Maintenance is 25% of collected rent. Rent is operating revenue and cash;
maintenance is an operating cash expense. Land acquisition, property acquisition
and development are separate investing accounts. The income statement separates
property rent and maintenance; the balance sheet carries land at cost and property
buildings net; cash flow shows their purchases separately. Daily/monthly/TTM/year
history uses the ordinary company ledger. The equity quote has no special property
premium; property assets flow into book equity through ordinary reconciliation.

Monthly StrategicAI considers apartment/block development when housing occupancy
is high and jobs can support growth. It considers office/commercial development
when employment becomes restrictive. Property investment competes for the same
single monthly capital action as facility building and must retain the existing
difficulty reserve after land plus building cost. Core supply-chain priorities
remain ahead of property investment. Controlled subsidiaries do not run AI.

Clicking an existing building selects its property inspector; vacant parcels expose
land and development actions. Acquiring, demolishing and redeveloping require a
confirmation. Company → Properties shows the portfolio, vacant owned land and a
compact city summary. Facility construction displays building, land and total cost.

Economy schema 18 persists land basis, property records, accumulated depreciation,
population/occupancy, fixed baseline jobs, the next property ID and expanded city
employment. Restore rejects malformed ownership, footprints, capacities, aggregate
state and accounting. Catalog version is 10; save envelope format remains 2. Old
schema 17 saves have no migration and are rejected.
