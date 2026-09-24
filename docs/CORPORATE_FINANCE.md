# Corporate finance (Milestone 9)

Milestone 11 aggregates land, property buildings, inventory, transit, profit and
cash across every city of each legal company. The equity registry, ownership,
control and fundamental valuation remain company level. Import purchases stay
operating inventory purchases; export receipts are operating product revenue.
Current versions are economy schema 19, catalog 11 and save format 2.

Milestone 10 added land at acquisition cost and property buildings net of
depreciation to the ordinary company balance sheet. The equity-market fundamental
continues to use contributed capital plus cumulative profit less dividends, which
reconciles to total book assets including land and property. No separate property
premium or unrealized land gain is recognized. Rent, maintenance, development and
disposal use the ordinary company account history; property and land cash purchases
are investing outflows. At the Milestone 10 checkpoint, versions were economy
schema 18, catalog 10 and save format 2. See [real estate](REAL_ESTATE.md).

## Registry and initial ownership

`EquityMarket` is the authoritative security registry inside `Economy`. Each
security records company ID, public/private status, integer outstanding shares,
integer founder shares, aggregate public-float shares, corporate holder positions,
the current integer-cent quote and at most 367 dated public price observations.
For every security, founder + public float + corporate holdings equals outstanding
shares exactly. Founder and public shares belong to aggregate investors outside
the modeled companies. Each corporate position records integer shares and total
cost basis. No individual shareholder or player personal account exists.

The deterministic starting policy assigns 1,000,000 founder-owned private shares
to the `player` company. The four existing commercial non-player firms—Circuit
Supply, Orion Devices, Nova Devices and Metro Electronics—each start public with
1,000,000 shares: 400,000 founder and 600,000 public float. There are no static
noncommercial companies in the current scenario. The policy is independent of
start era, seed and difficulty. No scenario catalog data was changed.

## Valuation and market transactions

The fundamental market cap in cents is the maximum of 10,000,000, book equity
(`contributed capital + cumulative profit − dividends paid`), and ten times
positive trailing-12-month profit. The quote is the maximum of one cent and the
integer floor of that cap divided by shares outstanding. Private firms have the
same internal quote for IPO pricing. Quotes are recomputed once at the end of
each simulation day after accounting and use no random noise. Issuance and trades
at a between-day boundary use the then-current quote; the next daily update
reflects changed fundamentals. A public security retains up to 367 daily prices.

`buy_shares` transfers integer shares from public float to the buyer's corporate
portfolio and cash from the buyer to outside investors. It requires a public
target, sufficient float and cash, positive shares, and a different buyer and
target. A single corporation may hold at most 75% of outstanding shares, preventing
pointless public-float draining after repeated issuance. `sell_shares` reverses
that flow and requires a sufficient holding. Neither
secondary trade changes target cash. Weighted-average aggregate cost basis is
used: a partial sale removes `floor(position cost × shares sold / shares held)`;
a final sale removes the exact remaining cost. Sale proceeds less removed cost
are cumulative realized investment gain or loss. Current value and unrealized
gain or loss are display-only; investments stay at cost on the balance sheet.

## Capital actions and dividends

`issue_shares` sells new integer shares to outside public investors at the current
quote. It turns a private company public on its first issue, increases its cash,
contributed capital, outstanding shares and public float, and leaves every old
holding's share count unchanged. A single issue may add no more than 25% of the
pre-issue outstanding shares. Multiple issues remain possible.

`declare_dividend` pays an integer number of cents per outstanding share
immediately. The issuer must retain at least 100,000 cents in cash afterward.
Issuer cash and retained earnings fall by the full payment. Corporate holders
receive their exact share count times the per-share amount as cash and investment
income. Founder and public portions leave the modeled economy. There is no
dividend payable liability and dividends are not operating expenses.

## Accounting and control

`SimCompany` accumulates share purchase cash, share sale cash, issue proceeds,
dividend receipts, dividend payments, investment income and realized investment
gain or loss. The existing daily/monthly company-account history records deltas
for these fields. Product revenue and expenses remain separate. Net profit equals
product revenue less cost of goods and operating expenses, plus dividend income
and realized investment gain or loss. Balance-sheet assets include equity
investments at aggregate cost. Equity equals contributed capital plus cumulative
profit less dividends paid. Cash Flow puts purchases, sale proceeds and dividend
receipts in investing, and issue proceeds and dividends paid in financing.
Financial statements retain exact cash and balance-sheet reconciliation.

A corporation directly controls a target when it owns strictly more than half
of outstanding voting shares. `controller`, `controls`, `ownership_percent` and
cycle-safe `controlled_group` derive this from integer holdings. The player may
select any company reachable through a chain of control from Player Electronics.
`GameSession.active_company` authorizes all player commands, including construction,
management and finance. Selecting a minority holding is rejected. If dilution or
sale removes control of the active company, the session returns to the root player
company. Subsidiaries keep separate cash, facilities, accounts and legal identity;
there is no consolidation or merger.

The permanent `ai` flag stays intact. StrategicAI monthly planning, research,
weekly prices and advertising skip companies in the player's controlled group.
If control is lost, ordinary AI policy resumes. AI does not initiate share trades
or takeovers in this milestone. Difficulty changes no finance rule.

## Persistence and scope

Economy schema 17 saves the registry, positions, quotes, price history and cumulative
finance accounts; the session saves the active company. Restore validates integer
shares, registry sums, corporate holder identities and cost, public/private status,
quote history, active control and statement reconciliation. Schema 16 is rejected.
Catalog stays 9 and save format stays 2. Save Browser metadata is unchanged.

The Finance tab shows securities, selected-security metrics, corporate portfolio,
capital structure, buy/sell, issuance, dividends and recent daily prices. The
Companies tab adds listing status and market capitalization. There is no debt,
tax, stock split, buyback, intraday order book, margin, options, derivatives,
personal stock account or balance-sheet consolidation.
