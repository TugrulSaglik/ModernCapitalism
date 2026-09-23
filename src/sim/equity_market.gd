class_name EquityMarket
extends RefCounted

const INITIAL_SHARES: int = 1000000
const HISTORY_LIMIT: int = 367
const DIVIDEND_BUFFER: int = 100000

# Securities and corporate cost bases are authoritative here. Founder and public
# float are aggregate outside-investor pools, not company treasury stock.
var securities: Dictionary = {}

func initialize(companies: Dictionary, date: String) -> void:
	securities.clear()
	var ids: Array = companies.keys()
	ids.sort()
	for id: String in ids:
		var listed: bool = id != "player"
		securities[id] = {"company": id, "public": listed, "outstanding": INITIAL_SHARES,
			"founder": 400000 if listed else INITIAL_SHARES, "float": 600000 if listed else 0,
			"holdings": {}, "quote": 1, "history": []}
	update_quotes(companies, date)

func position(holder: String, target: String) -> Dictionary:
	if not securities.has(target): return {"shares": 0, "cost": 0}
	return securities[target].holdings.get(holder, {"shares": 0, "cost": 0})

func investment_cost(holder: String) -> int:
	var result: int = 0
	for security: Dictionary in securities.values():
		result += int(security.holdings.get(holder, {"cost": 0}).cost)
	return result

func ownership_percent(holder: String, target: String) -> float:
	if not securities.has(target): return 0.0
	return 100.0 * int(position(holder, target).shares) / int(securities[target].outstanding)

func controller(target: String) -> String:
	if not securities.has(target): return ""
	var security: Dictionary = securities[target]
	for holder: String in security.holdings:
		if int(security.holdings[holder].shares) * 2 > int(security.outstanding): return holder
	return ""

func controls(holder: String, target: String) -> bool:
	return controller(target) == holder

func controlled_group(root: String) -> Array[String]:
	var result: Array[String] = []
	var visited: Dictionary = {}
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var id: String = pending.pop_front()
		if visited.has(id): continue
		visited[id] = true
		result.append(id)
		for target: String in securities:
			if not visited.has(target) and controls(id, target): pending.append(target)
	result.sort()
	return result

func fundamental_cap(company: SimCompany) -> int:
	return maxi(10000000, maxi(company.capital + company.profit() - company.dividends_paid, maxi(0, company.ttm_profit_cached) * 10))

func price(company: SimCompany, outstanding: int) -> int:
	@warning_ignore("integer_division")
	return maxi(1, fundamental_cap(company) / outstanding)

func update_quotes(companies: Dictionary, date: String) -> void:
	for id: String in securities:
		var security: Dictionary = securities[id]
		security.quote = price(companies[id], int(security.outstanding))
		if security.public:
			var history: Array = security.history
			if not history.is_empty() and history.back().date == date:
				history.back().price = security.quote
			else:
				history.append({"date": date, "price": security.quote})
			while history.size() > HISTORY_LIMIT: history.pop_front()

func command_error(command: Dictionary, companies: Dictionary) -> String:
	var action: String = str(command.get("type", ""))
	var holder: String = str(command.get("company", ""))
	if not companies.has(holder): return "Unknown company."
	var quantity: Variant = command.get("quantity", null)
	if action == "declare_dividend": quantity = command.get("per_share", null)
	if not quantity is int or quantity <= 0: return "Enter a positive integer share quantity or cents per share."
	if action in ["buy_shares", "sell_shares"]:
		var target: String = str(command.get("target", ""))
		if not securities.has(target): return "Unknown security."
		if holder == target: return "A company cannot trade its own shares."
		var security: Dictionary = securities[target]
		if not security.public: return "Security is private."
		if action == "buy_shares":
			if quantity > int(security.float): return "Not enough public float."
			if (int(position(holder, target).shares) + int(quantity)) * 4 > int(security.outstanding) * 3: return "A corporate holder may own at most 75% of a security."
			if quantity > 100000000000000 / int(security.quote) or companies[holder].cash < quantity * int(security.quote): return "Insufficient cash."
		else:
			if quantity > int(position(holder, target).shares): return "Not enough shares held."
	elif action == "issue_shares":
		var security: Dictionary = securities[holder]
		@warning_ignore("integer_division")
		if quantity > int(security.outstanding) / 4: return "One issue may add at most 25% of outstanding shares."
		if quantity > 100000000000000 / int(security.quote) or int(security.outstanding) + quantity > 1000000000000: return "Issue exceeds finance limits."
	elif action == "declare_dividend":
		var security: Dictionary = securities[holder]
		if quantity > 100000000000000 / int(security.outstanding) or companies[holder].cash - quantity * int(security.outstanding) < DIVIDEND_BUFFER:
			return "Insufficient cash after operating buffer."
	else:
		return "Unknown equity command."
	return ""

func apply(command: Dictionary, companies: Dictionary) -> void:
	var holder: String = str(command.company)
	var action: String = str(command.type)
	if action in ["buy_shares", "sell_shares"]:
		var target: String = str(command.target)
		var security: Dictionary = securities[target]
		var quantity: int = int(command.quantity)
		var proceeds: int = quantity * int(security.quote)
		var position_value: Dictionary = position(holder, target).duplicate()
		var company: SimCompany = companies[holder]
		if action == "buy_shares":
			company.cash -= proceeds
			company.equity_purchase_cash += proceeds
			security.float -= quantity
			position_value.shares += quantity
			position_value.cost += proceeds
		else:
			@warning_ignore("integer_division")
			var removed_cost: int = int(position_value.cost) if quantity == int(position_value.shares) else int(position_value.cost) * quantity / int(position_value.shares)
			company.cash += proceeds
			company.equity_sale_cash += proceeds
			company.realized_investment_gain += proceeds - removed_cost
			security.float += quantity
			position_value.shares -= quantity
			position_value.cost -= removed_cost
		if position_value.shares == 0: security.holdings.erase(holder)
		else: security.holdings[holder] = position_value
	elif action == "issue_shares":
		var security: Dictionary = securities[holder]
		var proceeds: int = int(command.quantity) * int(security.quote)
		companies[holder].cash += proceeds
		companies[holder].capital += proceeds
		companies[holder].equity_issue_cash += proceeds
		security.outstanding += int(command.quantity)
		security.float += int(command.quantity)
		security.public = true
	elif action == "declare_dividend":
		var security: Dictionary = securities[holder]
		var per_share: int = int(command.per_share)
		var total: int = int(security.outstanding) * per_share
		companies[holder].cash -= total
		companies[holder].dividends_paid += total
		for recipient: String in security.holdings:
			var payment: int = int(security.holdings[recipient].shares) * per_share
			companies[recipient].cash += payment
			companies[recipient].investment_income += payment
			companies[recipient].dividend_receipts += payment

func invariant_errors(companies: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if securities.size() != companies.size(): errors.append("Security count")
	for id: String in securities:
		if not companies.has(id):
			errors.append("Unknown security: " + id)
			continue
		var security: Dictionary = securities[id]
		if security.company != id or not security.public is bool or not security.outstanding is int or not security.founder is int or not security.float is int or int(security.outstanding) <= 0 or int(security.outstanding) > 1000000000000 or int(security.founder) < 0 or int(security.float) < 0 or (not security.public and (int(security.float) != 0 or not security.holdings.is_empty() or int(security.founder) != int(security.outstanding))): errors.append("Security structure: " + id)
		var total: int = int(security.founder) + int(security.float)
		for holder: String in security.holdings:
			var position_value: Dictionary = security.holdings[holder]
			if not companies.has(holder) or holder == id or not position_value.shares is int or not position_value.cost is int or int(position_value.shares) <= 0 or int(position_value.shares) > int(security.outstanding) or int(position_value.cost) < 0: errors.append("Holding: " + id + "/" + holder)
			total += int(position_value.shares)
		if total != int(security.outstanding): errors.append("Registry sum: " + id)
		if not security.quote is int or int(security.quote) <= 0: errors.append("Quote: " + id)
		if security.history.size() > HISTORY_LIMIT or (not security.public and not security.history.is_empty()): errors.append("Price history: " + id)
		var previous: String = ""
		for row: Variant in security.history:
			if not row is Dictionary:
				errors.append("Price observation: " + id)
				continue
			if not row.get("date") is String or not row.get("price") is int or int(row.price) <= 0 or str(row.date) <= previous: errors.append("Price observation: " + id)
			previous = str(row.get("date", ""))
	for id: String in companies:
		if companies[id].equity_purchase_cash < 0 or companies[id].equity_sale_cash < 0 or companies[id].equity_issue_cash < 0 or companies[id].dividends_paid < 0 or companies[id].dividend_receipts < 0 or companies[id].investment_income < 0: errors.append("Finance account: " + id)
	return errors

func snapshot() -> Dictionary:
	return securities.duplicate(true)
