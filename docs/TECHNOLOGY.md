# Technology and eras

Definitions have stable IDs, introduction years and prerequisite technology IDs.
Products reference a technology. At scenario start and during production, the
catalog checks the simulation year and the full prerequisite chain. Supported
starting years are scenario data `[2012, 2022]`; no product-specific era branches
exist in code. Advancing the calendar can make later public technology available.
Catalog validation rejects missing IDs and cyclic prerequisite graphs.

The small example has electronics (available 2000), mobile computing (2007), and
advanced mobile computing (2020, dependent on mobile computing). Conventional
smartphones can be produced in both eras; advanced smartphones only in 2022 or
after the date gate opens in a 2012 game. Dates are illustrative balancing data,
not a claim to accurately date commercial inventions.

Milestone 1 models public availability, not completed firm research. All firms
can use publicly available technologies. Later work separates public discovery
from company knowledge: starting-era scenarios grant baseline knowledge, research
projects unlock newly public technology and improve existing products in either
era. Product introduction dates must not alone grant company research completion.

Future technology data adds research cost/work, prerequisites, unlock IDs and
effect records (quality, technological performance, yield, efficiency). Company
state stores progress and attained levels. Products distinguish perceived quality,
technical quality and brand; current quality is a single bounded scalar. Keep
improvements generic and versioned rather than creating a special script for
each phone generation. Continuous improvement remains useful in 2022 even when
most baseline categories are unlocked.
