# Product taxonomy and chains

Use stable product IDs plus category, recipe, technology, costs and market data.
Different recipes may later produce compatible goods; a future recipe catalog
will separate recipes from product definitions when multiple routes are needed.

| Category | Example chain | Later economic distinctions |
| --- | --- | --- |
| Electronic materials | silicon → wafers → chips | yields, process nodes, capital intensity |
| Components | chips → processors/memory; glass → displays | technical performance, B2B demand |
| Energy storage | lithium/nickel → cells → battery packs | chemistry, safety, recycling |
| Consumer devices | processors + display + battery → smartphone/laptop | quality, brand, obsolescence |
| Vehicles | steel + motors + batteries → electric vehicles | dealerships, long purchase cycles |
| Food | grain → flour → packaged foods | agriculture, seasonality, spoilage |
| Household goods | chemicals → detergent; timber → furniture | local demand, bulk transport |
| Infrastructure | steel + chips → industrial machinery | B2B investment demand |
| Energy | fuels/renewables → electricity | networks and continuous flows |
| Digital services | compute capacity → subscriptions | service capacity, not physical inventory |

## Implemented example
Processors, displays and battery packs are paid external-resource production
boundaries. Each conventional smartphone consumes one of each; advanced phones
consume two processors, one display and two battery packs. Two manufacturers and
two retailers compete, with an additional advanced-phone manufacturer/retailer
available in the later era. Components have no household demand; phones do.
All facilities/products/scenario firms are data, including capacity and quality.

These are intentionally simplified bills of materials. They exercise multi-input
production, stock constraints, B2B purchases, competing consumer offers and era
gates without pretending to model semiconductor fabrication in detail. Add deeper
inputs only when their pricing, demand and capacity decisions are playable.
