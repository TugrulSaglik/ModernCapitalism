# Metropolitan city generation (Milestone 11R2)

## Current production build (Milestone 12)

Economy schema 22, catalog 13, save format 2 and CityGenerator 3. The title screen
owns new-session setup; GameSession validates a structured setup and stores mode
and tutorial progress. Economy remains authoritative for seed, era, difficulty,
selected city identities, player display name and opening capital. Manual setup
chooses exactly three unique profiles. Preferences use a separate ConfigFile.
Older milestone sections below retain their historical version context.
See [production architecture and validation](MILESTONE12.md).

11R2 — Metropolitan city profiles and street-network correction — implemented.
Milestone 12 adds detailed batched ambient components without changing generator geometry.

## Static real-city profiles

`data/city_profiles.json` contains 36 real coastal/port cities across Asia, Europe,
Africa, Oceania and the Americas. Examples include Istanbul, Tokyo, Shanghai,
Jakarta, Sydney, Barcelona, Vancouver, Lagos and Buenos Aires. The source is
United Nations, **World Urbanization Prospects 2025**, F21 DEGURBA city population,
2025 column: [official workbook](https://population.un.org/wup/assets/Download/Cities/WUP2025-F21-DEGURBA-Cities_Pop.xlsx).
Values are rounded to the nearest 100,000 residents. Source city codes/names and
population-weighted coordinates are retained. These harmonized city reference
areas are not municipal boundaries or exact metropolitan administrative units.
For example, the source's Tokyo area includes Yokohama, so it is not duplicated
as a separate population profile. Nothing downloads during gameplay.

Each profile supplies an ID, name, country, region, 2025 population/source,
latitude/longitude, compactness, terrain bias and aspect bias. Compactness and
terrain parameters are game design choices, not UN statistics. Catalog validation
rejects duplicate IDs/name-country pairs, missing source/year and malformed fields.
Country and region have no geopolitical/economic behavior.

A separate RNG selects three unique profiles from disjoint strata: 15M+ major,
7–15M large, and 1–7M medium. Sorted IDs and the session seed make selection
repeatable. At most one selected city is 25M+. Internal slots remain `metro`,
`harbor`, `highland`; real names appear in the selector and reports. Scenario
facilities remain in the primary slot. Tutorial and sandbox share these systems.

## Scale and population

| Reference population | Base dimensions |
| --- | --- |
| 1–3M | 192 × 144 |
| 3–7M | 224 × 168 |
| 7–15M | 256 × 192 |
| 15–25M | 320 × 240 |
| 25M+ | 384 × 288 |

Compactness makes a modest area adjustment, while seeded aspect variation and
profile aspect bias change shape. Dimensions round to multiples of eight, bounded
by 192–408 × 144–304. An explicit dimension/archetype/profile override is available
for direct CityMap fixtures; normal sessions use seeded profile selection.

**One simulation resident represents approximately 1,000 real residents.**
The development target is reference population / 1,000. Ordinary houses,
apartments, blocks, offices and commercial buildings retain their economic
capacities and costs. Density-ranked frontage candidates are developed until
ordinary 80–95% occupied residential capacity reaches the target and explicit
property jobs reach approximately half that target. No giant balancing building
or exact-occupancy override is used. Facilities add their ordinary jobs; the
existing outside-sector employment baseline only fills any residual shortfall.

Compactness affects the concentration radius and residential type mix. Large
populations expand both the map and the amount of development, with more centers
and denser cores. Secondary cores, suburban houses and open industrial frontage
remain. Centers scale from four to twelve; districts from eight to twenty, with
stable IDs and generic names. Cosmetic tone/height variation never changes capacity.
ConsumerMarket and monthly migration continue using integer simulation units.
City overview population, housing and workforce display millions of residents;
individual property occupancy is explicitly labelled as units (×1,000).

## Generator v3 street plan

1. Seeded coast, bay, estuary or river terrain, biased but not fixed by profile.
   Cardinal shoreline orientation varies. River frequencies scale with dimensions
   so larger maps do not create disconnected high-frequency water fragments.
2. Well-separated urban centers on an eight-cell planning lattice.
3. A coarse graph admits land corridors and strategic river crossings. A sparse
   minimum-spanning center/port/entrance backbone plus two redundant route requests
   becomes the arterial network. Industrial centers participate in the backbone.
4. Secondary axes connect each neighborhood to its arterial anchor.
5. Connected local blocks expand in round-robin order around centers; outer rings
   omit alternate cross streets, producing larger suburban blocks and dead ends.

All corridors are **one cell wide**, including arterials and bridges. Spacing is
eight cells; suburban cross streets can be sixteen cells apart. Orthogonal routes
bend only at planning nodes, never in high-frequency zigzags. Port access is a
short straight spur on a planning corridor. The shared lattice structurally
prevents adjacent parallel strips and every 2×2 solid road patch. Generation and
restore also explicitly reject road squares. There are no asphalt exceptions.

Roads target 5–10% of non-water land. Local expansion has an 8.5% budget and the
final structure check rejects coverage above 12%. Local streets never bridge;
only arterial connections cross river water. Bridge cells remain water and are
nonbuildable. Ports must touch the connected road graph and navigable edge water.

## Performance and persistence

Terrain, road and occupancy dictionaries support constant-time membership.
Footprint candidate sets derive from road frontage rather than scanning the map
for each facility. AI searches spatial buckets with bounded candidate/examination
limits, including property development. District land averages use one parcel
pass. Road BFS and route caching are preserved. No freight formula changed.
Regional distances retain the existing normalized slot distances to avoid changing
Milestone 11 freight balance; profile coordinates persist for later distance work.

Terrain, water, roads, bridges and ambient structures retain MultiMesh batching.
The camera starts at size 50 and can pan throughout the metropolis; broad zoom
remains dimension-dependent. The minimap caches static terrain/roads as a texture
and overlays development, facilities, port and viewport. UI visual snapshots omit
large parcel dictionaries. Full save snapshots retain every authoritative record.

Economy schema **21**, catalog **12**, generator **3**, save envelope **2**.
Profile metadata and identity persist with dimensions, terrain, roads/classes,
bridges, centers, districts, ambient property, demographics and all economic state.
Restore validates profile references/metadata and hydrates saved maps; it never
reselects profiles or generates terrain. The catalog fingerprint includes the
profile file. Save input bounds account for metropolitan parcel volumes. Old
schemas are rejected with no migration. The fixed legacy board remains unchanged.

## Focused acceptance

`tests/milestone11r2_tests.gd` covers catalog/selection, all five size tiers,
12 profile/seed combinations, road squares/spacing/connectivity/coverage, ports,
population targets, employment, construction frontage, exact restore, a 15M demand
input and one 384×288 maximum-tier fixture with placement/timing/snapshot checks.
`tests/milestone11r2_smoke.gd` covers ten regional days, commands, AI site search,
markets, routes, invariants and exact disk save/load. The screenshot harness
captures three population tiers at 1280×800 without Computer Use.

Recorded acceptance on 2026-09-25 (Godot 4.7.2): all 12 profile/seed cases passed.

| Profile / seed | Dimensions | Roads / non-water cells | Road coverage | Simulation residents / target |
| --- | --- | --- | --- | --- |
| Vancouver / 42 | 200×144 | 1,365 / 24,199 | 5.64% | 1,733 / 1,700 |
| Sydney / 43 | 256×160 | 2,125 / 33,336 | 6.37% | 4,208 / 4,200 |
| Istanbul / 44 | 312×240 | 4,067 / 59,037 | 6.89% | 15,000 / 15,000 |
| Tokyo / 45 | 360×288 | 5,979 / 102,240 | 5.85% | 33,430 / 33,400 |
| Barcelona / 46 | 232×160 | 1,906 / 31,071 | 6.13% | 4,029 / 4,000 |
| Los Angeles / 47 | 280×184 | 2,874 / 41,889 | 6.86% | 12,706 / 12,700 |
| Shanghai / 48 | 376×288 | 5,928 / 84,988 | 6.98% | 29,600 / 29,600 |
| Jakarta / 49 | 384×288 | 5,990 / 109,824 | 5.45% | 41,900 / 41,900 |
| Naples / 50 | 192×144 | 1,585 / 23,290 | 6.81% | 2,808 / 2,800 |
| Manila / 51 | 320×232 | 4,549 / 60,487 | 7.52% | 24,735 / 24,700 |
| Mumbai / 52 | 312×232 | 2,729 / 56,583 | 4.82% | 20,207 / 20,200 |
| Auckland / 53 | 208×144 | 1,424 / 29,120 | 4.89% | 1,108 / 1,100 |

The small pre-change seed-42 baseline had 19.42% road coverage. V3's two cases
slightly below 5% retain valid connected neighborhoods and ample frontage; none
exceeded the 12% ceiling. Every population target was within 2%. The maximum-tier
Jakarta fixture took 10.842s total: roads 0.233s, facility placement 3.955s,
properties 0.636s, and an additional 0.337s for its full snapshot.

The regional smoke advanced exactly ten days (seed 108: Istanbul, New York,
Sydney), exercising facility/property construction, imports, local/port/regional
routes, markets and AI site searches. A typed empty-array bug in legacy restore
initialization was corrected; the existing day-10 disk save was then restored
without repeating the simulation. Exact snapshot equality and zero invariant
errors passed. The disk file was 65,745,910 bytes. Evidence is in the ignored
`.godot/11r2-tests.log`, `11r2-smoke.log` and `11r2-smoke-restore.log` files.

Final 1280×800 captures are `.godot/m11r2-screenshots/tokyo.png` (33.42M,
360×288, bay), `istanbul.png` (15.00M, 312×240, estuary/bridge), and `sydney.png`
(4.20M, 248×160, estuary). All use camera size 50. One corrective framing pass
was used for Istanbul, without changing generation. The GPU emitted two shader
cache-write errors under the restricted filesystem; image capture succeeded and
the inspected frames have no rendering defects. Parser/import completed cleanly.

The maps are procedural interpretations, not GIS recreations. Streets share a
citywide orientation and eight-cell grid; neighborhood extent, terrain clipping,
sparse arterials and suburban omissions create variation. Capacities and land
footprints are aggregate game abstractions. No traffic, transit or dynamic roads
are modeled. Long-term balance testing remains outside this corrective milestone.
