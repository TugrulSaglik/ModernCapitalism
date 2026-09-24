# Regional scale and trade (Milestone 11)

Normal procedural games have three independently generated 48 × 36 cities. The
catalog defines Metro City (`metro`, offset 0, coordinate 0,0), Harbor City
(`harbor`, offset 1009, coordinate 100,40) and Highland City (`highland`, offset
2017, coordinate 45,130). Each uses the session seed plus its offset and keeps
its generated map, population, districts, property records and public port in
the economy save. Metro is the primary compatibility alias. The legacy fixed
board remains Metro only, without an operating port or external trade.

## Public ports and freight

Each procedural city reserves the first eligible waterfront, road accessible
cell in stable row/column order after scenario facilities are placed. The
`port_<city>` marker is public infrastructure. It blocks ordinary land purchase
and construction and is visible on the map and minimap. Ports have no owner,
inventory, fee, construction command, fleet or schedule.

Local shipments retain their existing road distance and accounting. For a
regional shipment, the distance is source facility to its port along the road
graph, plus Manhattan distance between city coordinates, plus destination port
to facility along its city's road graph. A missing port or road route rejects
shipping. Freight remains base 100 cents plus 2 cents per unit per distance;
lead days are at least one and otherwise ceiling of total distance divided by
20. The quote exposes each leg and mode. The buyer pays goods and freight at
departure, owns in transit goods, and receives them on the arrival tick.

The supplier market ranks same city producers, reachable regional producers,
owned warehouses and the synthetic external import offer with its existing
landed cost, lead and quality formula. A warehouse serves downstream facilities
in its own city, while its inbound supplier may be regional or external.

## External imports and exports

Every public product can be imported through an operating port at
`ceil(reference price × 125 / 100)` and quality 50. The synthetic supplier ID is
`import:<city>`. Supply is limited to 100 units per city/product/day, shared by
companies. Imports require a compatible destination, free capacity and cash.
The buyer pays goods and freight at departure and owns the in transit goods.
Goods value becomes inventory carrying value on delivery. Import purchase value
is included in ordinary `purchases` and separately tracked in
`import_purchases`; freight is an operating expense.

Companies can export stocked public goods through their city's port at
`floor(reference price × 110 / 100)`. The daily city/product demand cap is half
the current category potential, at least 10 for consumer goods, and 50 for
components. Capacity is shared across companies. The seller receives revenue,
records carrying cost as COGS and pays road/external freight immediately. An
outbound export record is informational and is not a seller transit asset.
`export_revenue` is a subset of total revenue; domestic wholesale equals total
revenue less retail, rent and export revenue. This spread does not support
import/export price arbitrage. Trade history retains up to 90 active trade days.

## City markets, AI and controls

Each city's residents clear their own consumer market against city local retail
facilities and an independent synthetic Local offer. Regional reports sum
potential, purchases, revenue and Local/company units, then recompute shares and
averages from their unit weighted numerators. Market history is bounded to 90
days per city and for the regional total. Company advertising and brand remain
global to the company/product pair.

The top city selector changes the map, minimap, quick facility list, parcel
inspector and build location. It does not change the managed company. Company →
Markets selects the regional total or one city; Company → Properties lists the
company's whole regional portfolio and shows the active city's population.
Company → Trade quotes and submits imports/exports at an explicitly selected
city and facility. Facility Sourcing and Logistics expose regional/import/export
labels. Clicking the public port opens a read only infrastructure inspector.

StrategicAI evaluates opportunities in every city using the existing scoring
formula on city market data. It may enter a city with no prior facility but
still makes at most one major capital investment per company per month across
the region. The difficulty retailer maximum is per city: 2 Relaxed, 3 Standard
or 4 Competitive. Warehouses are limited to one per company per city; HQ and R&D
remain company wide. Weekly exports use only material excess stock and avoid
goods needed by immediate owned downstream facilities. Automatic sourcing lets
new city operations bootstrap with imports.

## Persistence and scope

Economy schema 19 and catalog 11 store all city maps, ports, estates, markets,
trade usage/history, shipment route metadata, global facility ID counter and
session active city. Save envelope format remains 2. Restore validates city IDs,
port sites, facility placement, accounts, routes and trade limits. Schema 18
saves are rejected under the project's no migration policy. This milestone has
no countries, currencies, tariffs, company owned ports or world map renderer.
