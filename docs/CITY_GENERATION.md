# Large-scale procedural cities (Milestone 11R)

Normal regional cities use generator version 2 at **128 × 96** cells. Procedural
settings accept integer widths 96–192 and depths 72–144. Metro, Harbor and
Highland share the same generator; catalog seed offsets give them independent
layouts. The 32 × 24 legacy fixture is unchanged. There is no size selection UI
yet.

The seeded generator first selects a coast, bay/peninsula, estuary or river-city
archetype and a cardinal orientation. Coast position combines broad sinusoids
with a bay and optional projecting cape. Estuaries continue a meandering,
typically 2–4-cell river from the coast toward the opposite edge; river cities
have a meandering edge-to-edge river. Sea and river cells are authoritative
water. A bridge cell stays water and nonbuildable while also belonging to the
road graph. Regional ports reserve connected navigable waterfront near a center
and must have road frontage and water access to an external edge.

Three to six centers are placed on land, with the first acting as the primary
core. Seven stable district seeds form warped nearest-center regions. Districts
carry character, purchasing power and recomputed population, capacity and mean
land value. Arterials use deterministic orthogonal A* routes between centers,
the port and regional entrances. River crossings are weighted and become
explicit bridge cells. Local branches start on existing streets, stop at water,
and cluster around centers; bridge construction is limited to arterials.

A continuous development field combines center distance, road frontage,
waterfront, district character and broad seed variation. It determines ambient
development chance and the existing catalog building mix. Downtown favors
blocks, apartments and offices; mid-density areas mix housing and commerce;
suburbs favor houses; industrial areas retain more vacant frontage. Facilities
are placed first near company-relevant centers with spacing. Ambient residential
occupancy starts at 80–95% of catalog capacity. Population is calculated from
actual generated property records, and consumer demand uses the existing model.
Parcel land value varies by urbanity, frontage, waterfront and district purchasing
power; owned land remains carried at acquisition cost.

`CityMap` persists dimensions, water, bridges, roads/classes, centers in generator
metadata, districts, parcels, ambient property, population, plots and the port.
Derived water, road and occupancy indexes accelerate placement and route checks;
they are rebuilt from saved data on restore. Routes use the existing cached BFS
and treat bridges as roads. Restore validates the saved structure without running
the generator. Economy schema is **20**, catalog version **11**, and save format
**2**; there is no migration from schema 19.

`CityView` starts at a company facility, otherwise the primary center, with
orthographic size 50. Middle drag pans across the enlarged map, wheel zoom
reaches detailed and overview scales, and the minimap always shows the whole
city with a viewport outline. Water, roads, bridges, frontage and ambient
facades use MultiMesh batches. Individual ambient physics bodies were replaced
by cell-based property picking; economic facilities keep their own selection
bodies. Ambient meshes rebuild only when the saved ambient collection changes.
