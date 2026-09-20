class_name FinancialReports
extends RefCounted

static func balance(sim: Economy, company: String) -> Dictionary:
	var owner: SimCompany = sim.companies[company]
	var cost: int = 0
	var depreciation: int = 0
	for f: SimFacility in sim.facilities:
		if f.company_id == company:
			cost += f.asset_cost
			depreciation += f.accumulated_depreciation
	var transit: int = sim.logistics.assets(company)
	var inventory: int = sim.inventory_assets(company) - transit
	return {"cash": owner.cash, "inventory": inventory, "in_transit": transit, "fixed_cost": cost,
		"accumulated_depreciation": depreciation, "net_fixed_assets": cost - depreciation,
		"assets": owner.cash + inventory + transit + cost - depreciation, "liabilities": 0,
		"contributed_capital": owner.capital, "retained_earnings": owner.profit(), "equity": owner.capital + owner.profit()}

static func period(owner: SimCompany, clock: SimClock, choice: String = "current_month") -> Dictionary:
	var records: Array[Dictionary] = []
	var month: String = clock.date_string().substr(0, 7)
	if choice == "ttm":
		var cutoff: String = "%04d-%02d-%02d" % [clock.year - 1, clock.month, mini(clock.day, 28) if clock.month == 2 and clock.day == 29 else clock.day]
		for row: Dictionary in owner.daily_history:
			if str(row.date) > cutoff: records.append(row)
	else:
		var previous: String = "%04d-%02d" % [clock.year - 1 if clock.month == 1 else clock.year, 12 if clock.month == 1 else clock.month - 1]
		for row: Dictionary in owner.monthly_history:
			if (choice == "current_month" and row.month == month) or (choice == "previous_month" and row.month == previous) or (choice == "year" and str(row.month).begins_with(str(clock.year))): records.append(row)
	var result: Dictionary = {}
	for key: String in owner.accounts(): result[key] = 0
	for row: Dictionary in records:
		for key: String in owner.accounts(): result[key] += int(row.get(key, 0))
	result["opening_cash"] = int(records[0].get("opening_cash", owner.opening_cash)) if not records.is_empty() else owner.cash
	result["closing_cash"] = int(records.back().get("closing_cash", owner.cash)) if not records.is_empty() else owner.cash
	result["gross_profit"] = int(result.revenue) - int(result.cogs)
	result["other_expenses"] = int(result.expenses) - int(result.freight) - int(result.depreciation) - int(result.research_expense) - int(result.advertising_expense)
	result["operating_cash"] = int(result.revenue) - int(result.purchases) - int(result.production_cash) - int(result.cash_expenses)
	result["investing_cash"] = -int(result.capex)
	result["financing_cash"] = int(result.capital)
	result["net_cash"] = int(result.operating_cash) + int(result.investing_cash) + int(result.financing_cash)
	return result
