# Technology and eras

## Current production build (Milestone 12)

Economy schema 22, catalog 13, save format 2 and CityGenerator 3. The title screen
owns new-session setup; GameSession validates a structured setup and stores mode
and tutorial progress. Economy remains authoritative for seed, era, difficulty,
selected city identities, player display name and opening capital. Manual setup
chooses exactly three unique profiles. Preferences use a separate ConfigFile.
Older milestone sections below retain their historical version context.
See [production architecture and validation](MILESTONE12.md).

## Milestone 7A: public availability and company knowledge

Public technology and company knowledge are separate. Catalog `technology_public`
checks introduction year and the complete prerequisite graph; Economy's equivalent
also honors saved Debug public overrides. `product_public` answers only the public
question. `SimCompany.knows` reads permanent company knowledge. `can_manufacture`
requires public availability and the owner's knowledge; `can_configure` applies
that rule to production facilities and public availability to retail/storage.
The old ambiguous `available` API has been removed from code and tests.

At scenario creation, each company knows every catalog technology publicly
available in the selected starting year, deterministically. In 2012 these are
electronics and mobile computing; in 2022 all five current technologies are known.
Advancing the calendar never grants knowledge. Wearables (2015), smart home (2018)
and advanced mobile (2020) become researchable when public and their company-known
prerequisites are satisfied. Dates and costs are illustrative, not historical claims.
Starting locked factory sites remain reserved and idle until their owner researches
the technology; ordinary starting factories, assortments and logistics still work.
The existing legacy city fixture has no added R&D building.

## Research data and authoritative state

Each technology defines positive integer `research_work` points and `research_cost`
cents per funded research day, in addition to year and prerequisite IDs. Current
baseline projects use 300 points; later technologies use 600, all at 2,500 cents/day.
Validation rejects invalid/fractional work/cost, missing/duplicate prerequisites,
cycles, and invalid research rates. No product or bespoke technology scripts were added.

`SimCompany.known_technologies` maps technology ID to acquisition tick (`-1` for
starting knowledge). It is the permanent completion record, not a second derived
completed list. `research_progress` holds only incomplete technology work.
Milestone 7B3A adds complete company/product `product_quality_levels` and sparse
retained `product_quality_progress`. Milestone 7B3B similarly adds
`process_efficiency_levels` and retained `process_efficiency_progress`.
`SimFacility.research_project` is a structured record with explicit `technology`,
`product_quality` or `process_efficiency` kind; continuous records carry product and
exact target level. Technology IDs are not overloaded.

## R&D facilities and projects

Build → Corporate → R&D center constructs a 3 × 2 building for $15,000.
It has $5/day operating overhead and a catalog research rate of 10 points/day.
Research is a distinct facility behavior. It has no configured product, price,
assortment or inventory requirements; transfers into it are rejected. The shared
facility container's inventory stays empty. New R&D buildings use existing fixed
asset capitalization, 3,650-day depreciation and demolition write-off rules.
Scenario R&D, like other scenario buildings, starts with zero fixed book value.

`assign_research` and `stop_research` use the authorized command FIFO. Each facility
has at most one structured project; a company cannot assign the same technology or
exact product/next-level project to two facilities, including suspended facilities.
Different projects can run concurrently. Technology assignment requires an unknown
public technology and company-known prerequisites. Product-quality and
process-efficiency assignments require a public, catalog-manufacturable product,
knowledge of its manufacturing technology, the exact next level, and a current
level below five. Retail access never qualifies.
Stopping,
changing projects, suspending or demolishing a facility never erases company progress
and never refunds money. Another eligible center can resume the retained work.

Product-quality levels are bounded 0–5. Target level L requires `300 × L` work and
costs `2,500 × L` cents per funded day. These defaults and the five-point quality
bonus per attained level are catalog data and validated as small positive integers.
Completion raises exactly one company/product level and makes the next project
available. Process-efficiency levels use the same work/cost scale and 0–5 bound;
each level reduces future conversion cash by the catalog-defined 5%. Neither
continuous kind changes throughput, recipe quantities or yield.

Daily research occurs after production, replenishment and consumer sales, before
financial history closes and the date advances. Facilities run in stable ID order.
An active center pays the full daily project cost and adds its rate, capped by
completion. Insufficient project funds cause no charge and no progress; cash never
goes negative. Overhead already paid earlier in the day remains an expense. Suspended
or overhead-unfunded facilities cannot research, even if sales later increase cash.
Idle operating centers still pay overhead; suspend them to avoid it.

Completion records the executing tick, removes partial work, and clears assignment.
New technology, product-quality or process-efficiency capability operates on the
following day's production phase; dependent/next-level projects can be assigned at
the next boundary.
There is no frame-time work, random research progress or personnel.

## Manufacturing versus buying finished goods

Manufacturing construction, recipe switching, starting activation and daily production
all check the owner's knowledge. Buying a product does not unlock its recipe. A
company need not know how to manufacture a recipe input it purchases.

Retail construction, retail-line configuration and resale deliberately require
public product availability, not manufacturing knowledge: a retailer can sell a
public finished good bought from a knowledgeable manufacturer. Warehouses similarly
store and transfer public goods without acquiring expertise. Supported products,
retail categories/slots, stock, funds and logistics restrictions still apply. This
explicit resale exception prevents R&D from becoming a requirement for every shop.

## Strategic AI research and UI

Nova (`maker_b`) is enabled as an AI company and receives `30_research` through
expanded scenario data. Milestone 8C also lets commercially active AI companies
construct one R&D center through normal capital rules. An operating idle center
first chooses an eligible technology relevant to products the company sells,
manufactures, depends on, or sees as a high market opportunity; ties use public
year and stable ID. Otherwise, continuous projects are limited to products actually
manufactured and sort by opportunity, lower attained level, product ID, then
`product_quality` before `process_efficiency`. Prerequisites and all normal project
rules remain authoritative. Idle labs are evaluated daily through ordinary
`assign_research` commands, while capital planning remains monthly.

Select an R&D center to use its compact R&D inspector. The selector separates
technology, product-quality and process-efficiency projects. Continuous details show
product, current/target/maximum level, retained/required work, daily cost, funded
days remaining and assigned facility; process projects also show reduction and
base/target conversion cost. Assign/resume and stop controls use normal commands;
rival centers are read-only. Factory reads keep quality separate from process level
and base/effective conversion cost.

## Accounting, persistence and Debug

Project payments increment `research_expense`, total operating expenses and cash
expenses. Income Statement exposes R&D separately; monthly/archived records, TTM,
retained earnings and operating Cash Flow use the same ledger. Center overhead stays
in other operating expenses. Research is expensed, never capitalized as an intangible.

Economy schema **11**, catalog version **6**, save format **2** preserve knowledge,
quality/efficiency levels, typed assignments and all partial-work kinds exactly with the
existing numeric encoding. Restore validates product/technology references, levels,
targets, knowledge, progress bounds, duplicate assignments, facility behavior and
categorized accounts before replacing the session.
Older schemas/catalog fingerprints are intentionally incompatible; no migration.

Sandbox Debug unlock remains password-controlled, audited and saved, with access
relocked on load. Its UI now says it makes technologies public **without granting
company knowledge**. The R&D inspector identifies a Debug public override explicitly.
No instant-completion or knowledge-grant action was added. Normal gameplay uses only
the date gates and funded research.

Milestone 7B1 now gives goods integer pooled quality provenance, independently of
technology unlocks. Facility quality means production process baseline, not retail
quality. See [quality formula and persistence](ECONOMY.md#milestone-7b1-product-quality-provenance).
Current saves use economy schema 11 / catalog 6 / format 2. 7B2 is implemented:
Local offers obey public availability (including existing Debug overrides), but
never grant company knowledge. Corporate product brands are static seller state,
independent of research and goods quality. 7B3A product-quality and 7B3B
conversion-cost process-efficiency R&D are implemented. Patents, licensing,
Throughput research remains deferred. Headquarters staffing is implemented through
8B3: only funded R&D managers at an operating HQ multiply each funded center's base
rate by the capped catalog percentage (flooring to integer work). Project work,
daily cash cost, eligibility, ordering and completion semantics do not change.
Strategic AI is implemented in Milestone 8C without research bonuses or knowledge
cheating.
