# Technology and eras

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
`SimFacility.research_project` is an optional assigned technology ID. Future 7B3
project kinds and attained improvement levels can extend this company/facility
ownership model without moving state into the UI or replacing technology knowledge.

## R&D facilities and projects

Build → Corporate → R&D center constructs a 3 × 2 building for $15,000.
It has $5/day operating overhead and a catalog research rate of 10 points/day.
Research is a distinct facility behavior. It has no configured product, price,
assortment or inventory requirements; transfers into it are rejected. The shared
facility container's inventory stays empty. New R&D buildings use existing fixed
asset capitalization, 3,650-day depreciation and demolition write-off rules.
Scenario R&D, like other scenario buildings, starts with zero fixed book value.

`assign_research` and `stop_research` use the authorized command FIFO. Each facility
has at most one project; a company cannot assign the same technology to two facilities,
including suspended facilities. Different projects can run concurrently. Assignment
requires an unknown public technology and company-known prerequisites. Stopping,
changing projects, suspending or demolishing a facility never erases company progress
and never refunds money. Another eligible center can resume the retained work.

Daily research occurs after production, replenishment and consumer sales, before
financial history closes and the date advances. Facilities run in stable ID order.
An active center pays the full daily project cost and adds its rate, capped by
completion. Insufficient project funds cause no charge and no progress; cash never
goes negative. Overhead already paid earlier in the day remains an expense. Suspended
or overhead-unfunded facilities cannot research, even if sales later increase cash.
Idle operating centers still pay overhead; suspend them to avoid it.

Completion records the executing tick, removes partial work, and clears assignment.
New manufacturing capability operates on the following day's production phase;
dependent projects can be assigned at the next boundary. There is no frame-time work,
random research progress, personnel, quality effect or efficiency improvement.

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

## Minimal AI and UI

Nova (`maker_b`) is enabled as an AI company and receives `30_research` through
expanded scenario data. An operating idle AI center chooses an eligible technology
by public year, then stable ID. Prerequisites are always checked. AI neither builds
centers nor selects investments or optimizes portfolios. Other companies need a
center to participate. Current 2022 knowledge means centers have no remaining
technology projects; continuous improvement is deferred to 7B3.

Select an R&D center to use its compact R&D inspector. The technology selector
shows known, researchable or locked state, prerequisite knowledge, required work,
retained points, percentage, daily cost, funded operating days remaining and assigned
facility. Assign/resume and stop controls use normal commands; rival centers are
read-only. Completion and public-year changes refresh capability choices.

## Accounting, persistence and Debug

Project payments increment `research_expense`, total operating expenses and cash
expenses. Income Statement exposes R&D separately; monthly/archived records, TTM,
retained earnings and operating Cash Flow use the same ledger. Center overhead stays
in other operating expenses. Research is expensed, never capitalized as an intangible.

Economy schema **8**, catalog version **3**, save format **2** preserve knowledge,
partial work and facility assignment exactly with the existing numeric encoding.
Restore validates catalog references, prerequisites, progress bounds, duplicate
assignments, facility behavior and categorized accounts before replacing the session.
Older schemas/catalog fingerprints are intentionally incompatible; no migration.

Sandbox Debug unlock remains password-controlled, audited and saved, with access
relocked on load. Its UI now says it makes technologies public **without granting
company knowledge**. The R&D inspector identifies a Debug public override explicitly.
No instant-completion or knowledge-grant action was added. Normal gameplay uses only
the date gates and funded research.

Milestone 7B1 now gives goods integer pooled quality provenance, independently of
technology unlocks. Facility quality means production process baseline, not retail
quality. See [quality formula and persistence](ECONOMY.md#milestone-7b1-product-quality-provenance).
Current saves use economy schema 8 / catalog 3 / format 2. 7B2 adds a Local-market
baseline competitor and brand foundation; 7B3 adds continuous product/process R&D.
Neither follow-up is implemented here. Patents, licensing, staff, HQ and strategic
AI remain deferred.
