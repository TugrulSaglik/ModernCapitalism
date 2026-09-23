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
	var land: int = sim.real_estate.land_assets(company)
	var property_cost: int = 0
	var property_depreciation: int = 0
	for b: Dictionary in sim.real_estate.properties.values():
		if b.owner == company:
			property_cost += int(b.building_cost)
			property_depreciation += int(b.depreciation)
	return {"cash": owner.cash, "inventory": inventory, "in_transit": transit, "fixed_cost": cost,
		"land": land, "property_cost": property_cost, "property_depreciation": property_depreciation, "net_property": property_cost - property_depreciation,
		"accumulated_depreciation": depreciation, "net_fixed_assets": cost - depreciation,
		"equity_investments": sim.equity_market.investment_cost(company),
		"assets": owner.cash + inventory + transit + cost - depreciation + land + property_cost - property_depreciation + sim.equity_market.investment_cost(company), "liabilities": 0,
		"contributed_capital": owner.capital, "retained_earnings": owner.profit() - owner.dividends_paid, "equity": owner.capital + owner.profit() - owner.dividends_paid}

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
	result["other_expenses"] = int(result.expenses) - int(result.freight) - int(result.depreciation) - int(result.research_expense) - int(result.advertising_expense) - int(result.payroll_expense) - int(result.property_maintenance)
	result["operating_cash"] = int(result.revenue) - int(result.purchases) - int(result.production_cash) - int(result.cash_expenses)
	result["investing_cash"] = -int(result.capex) - int(result.land_capex) - int(result.property_capex) - int(result.equity_purchase_cash) + int(result.equity_sale_cash) + int(result.dividend_receipts)
	result["financing_cash"] = int(result.capital) - int(result.dividends_paid)
	result["net_cash"] = int(result.operating_cash) + int(result.investing_cash) + int(result.financing_cash)
	return result
