# Difficulty and balancing

Milestone 8D validates competitive pressure without changing the laws of the economy.
Difficulty is fixed per session and changes only five StrategicAI policy parameters.
Standard is the Milestone 8C baseline. All firms retain identical construction,
production, wages, research, advertising, demand, logistics, staff effects, starting
cash and accounting rules.

## Profiles

| Difficulty | Reserve | Opportunity | Retailers | Warehouse threshold | Payroll runway |
| --- | --- | ---: | ---: | ---: | ---: |
| Relaxed | max(7,500,000, cash / 3) | 70 | 2 | 4 commercial facilities | 90 days |
| Standard | max(5,000,000, cash / 4) | 40 | 3 | 3 commercial facilities | 60 days |
| Competitive | max(3,500,000, cash / 5) | 25 | 4 | 2 commercial facilities | 45 days |

## Matrix methodology

`tests/milestone8d_balance_matrix.gd` runs two synchronized economies for every case
and compares exact encoded snapshots. It covers 2022 Relaxed, Standard and Competitive
for 730 days, plus 2012 Standard and Competitive for 1,095 days. Each daily run checks
economic invariants and nonnegative cash; final checks cover deterministic equality,
pending and invalid commands, era-valid construction, no duplicate HQ, at most one
warehouse and R&D center per AI, and the retailer investment ceiling. The full
procedural scenario begins rival with three retailers, so Relaxed cannot reduce it;
the assertion correctly requires that such an existing over-cap network does not grow.

## Observed outcomes

All five cases passed with zero invariant failures, invalid commands, negative cash,
era-invalid builds or pending-command accumulation. Every AI remained active, staffed,
solvent and capable of HQ, R&D, warehouse, vertical integration and continuous research.

In 2022, Competitive produced the clearest pressure difference: rival expanded to four
retailers and 11 active lines, versus three retailers and 10 lines on Standard, while
remaining solvent. Relaxed and Standard reached similar final infrastructure in this
high-opportunity scenario, but followed different reserve/threshold decisions and ended
with different cash, profit and market outcomes. Controlled fixtures prove all intended
policy boundaries even where emergent final facility counts converge.

The 2012 three-year Standard and Competitive runs both remained stable and research-
active. Their final networks converged, illustrating that difficulty does not guarantee
monotonic emergent outcomes when era gates, cash flow and market feedback interact.
This is expected; only the policy inputs are required to be monotonic.

No catalog or core economic value was changed. Autonomous balance runs validate AI
health and systemic stability, not the strength of competent human play. Human-versus-AI
tuning remains iterative work for later production balancing.
