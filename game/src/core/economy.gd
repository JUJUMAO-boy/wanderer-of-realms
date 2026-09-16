class_name Economy
extends RefCounted

## 经济（接口 I-12 ~ I-14）。两块职责：贸易结算（《世界模拟量化规则》9.3 / 9.4）
## 与玩家买卖（《数值框架》9.2 / 9.3）。
##
## **城市侧只读不写**：它算出本月每条路线给两端城市带来多少财富与文化、哪几条
## 走私被查抄，把结果返回给 WorldSim，由 WorldSim 统一落账。理由是设计文档 2.3 节
## 的边界约束——城市的六维只有 WorldSim 这一个写入口。让 Economy 顺手把数字改掉，
## 短期看不出问题，等到需要回答「这次城市变化是谁造成的」时会发现链路上断了一节。
##
## **玩家侧直接落账**：买卖改的是玩家自己的钱与背包，不等月末、也不提交 StateChange
## （没有"城市六维因此变了多少"这回事——物价只读城市状态，不改它）。这与委托交付
## 的处理一致（QuestSystem.complete 里玩家的钱、声誉、善恶当场结算）。玩家的钱与
## 背包不经过 StateChange，所以这里不算破上面那条边界。
##
## 收益同样走定点整数。正规商路每月财富 +0.5、走私 +0.8，折算成千分位后
## 交给 CityEvolution.apply_milli 落账，与自然演化的余数共用同一个累加器——
## 两者都是「这个月财富该涨多少」的碎片，分开攒反而会出现两份互相独立的余数。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"

const SCALE: int = 1000

## 交易渠道（《城市特色建筑与人口设定》：索恩港的黑市街、十字路、赤沙）。
## 商铺问你的名声，黑市不问——它是名声坏了之后唯一的出路。
const CHANNEL_SHOP: String = "shop"
const CHANNEL_BLACK_MARKET: String = "black_market"
const ALL_CHANNELS: Array = [CHANNEL_SHOP, CHANNEL_BLACK_MARKET]
const CHANNEL_LABELS: Dictionary = {
	CHANNEL_SHOP: "商铺",
	CHANNEL_BLACK_MARKET: "黑市",
}

const SIDE_BUY: String = "buy"
const SIDE_SELL: String = "sell"

const RARITY_DRAGONFORGED: String = "dragonforged"

## 货架的类别次序（《数值框架》8 节：武器、防具、消耗品）。按类别名排序会得到
## armor → consumable → weapon，界面读起来是先看防具再看武器，与设定集的次序相反。
const CATEGORY_ORDER: Array = ["weapon", "armor", "consumable"]

var _regular_wealth: int = 500
var _regular_culture: int = 200
var _smuggling_wealth: int = 800
var _smuggling_culture: int = 50
var _legendary_wealth: int = 1200
var _legendary_culture: int = 300
var _confiscation_factor: int = 200
var _confiscation_reputation_loss: int = 5
var _confiscation_karma_loss: int = 2

# --- 物价六因子（balance.economy）---
var _dim_max: int = 100
## 类别 → 决定供需的那一维。文档只写"短缺贵、过剩贱"，没写"谁的需求"，
## 本作也没有逐城的商品存量表，所以按类别映射到城市六维（D-43）。
var _supply_by_category: Dictionary = {}
var _supply_fallback: String = "wealth"
var _shortage_at: int = 40
var _surplus_at: int = 60
var _shortage_factor_zero: float = 3.0
var _shortage_factor_edge: float = 1.5
var _surplus_factor_edge: float = 0.8
var _surplus_factor_max: float = 0.5
var _security_scale: int = 200
var _respect_threshold: int = 60
var _respect_factor: float = 0.85
var _wary_threshold: int = -20
var _wary_factor: float = 1.15
var _refuse_at: int = -60
var _sell_ratio: float = 0.5
var _black_buy_factor: float = 1.4
var _black_sell_factor: float = 1.4
var _black_rarity_bonus: int = 15
var _rarity_gates: Dictionary = {}
var _dragonforged_city: String = ""

## 实例层规则（词缀、强化、耐久）。买卖的价目要算得出"这件货带的词缀值多少铜"，
## 所以 Economy 要能读到它——与它读 ContentLoader.get_item 是同一条依赖。
var _items: ItemInstance = null


## cfg 取 balance 整段（贸易与交易两块都从这里读）。直接给 trade 段也能跑：
## 那时 economy 相关字段全部退回默认值。
func _init(cfg: Dictionary = {}) -> void:
	_items = ItemInstance.create_from_config()
	var trade: Dictionary = cfg.get("trade", {})
	var econ: Dictionary = cfg.get("economy", {})
	var dim: Dictionary = cfg.get("cityDimension", {})

	_regular_wealth = _permille(trade, "regularWealthYield", 0.5)
	_regular_culture = _permille(trade, "regularCultureYield", 0.2)
	_smuggling_wealth = _permille(trade, "smugglingWealthYield", 0.8)
	_smuggling_culture = _permille(trade, "smugglingCultureYield", 0.05)
	_legendary_wealth = _permille(trade, "legendaryWealthYield", 1.2)
	_legendary_culture = _permille(trade, "legendaryCultureYield", 0.3)
	_confiscation_factor = _permille(trade, "smugglingConfiscationSecurityFactor", 0.2)
	_confiscation_reputation_loss = int(trade.get("smugglingConfiscationReputationLoss", 5))
	_confiscation_karma_loss = int(trade.get("smugglingConfiscationKarmaLoss", 2))

	_dim_max = int(dim.get("max", 100))
	_supply_by_category = _dict_of(econ.get("supplyDimensionByCategory", {}))
	_supply_fallback = str(econ.get("supplyDimensionFallback", "wealth"))
	_shortage_at = int(econ.get("shortageAt", 40))
	_surplus_at = int(econ.get("surplusAt", 60))
	_shortage_factor_zero = float(econ.get("shortageFactorAtZero", 3.0))
	_shortage_factor_edge = float(econ.get("shortageFactorAtEdge", 1.5))
	_surplus_factor_edge = float(econ.get("surplusFactorAtEdge", 0.8))
	_surplus_factor_max = float(econ.get("surplusFactorAtMax", 0.5))
	_security_scale = maxi(1, int(econ.get("securityFactorScale", 200)))
	_respect_threshold = int(econ.get("reputationRespectThreshold", 60))
	_respect_factor = float(econ.get("reputationRespectPriceFactor", 0.85))
	_wary_threshold = int(econ.get("reputationWaryThreshold", -20))
	_wary_factor = float(econ.get("reputationWaryPriceFactor", 1.15))
	_refuse_at = int(econ.get("reputationRefuseAt", -60))
	_sell_ratio = float(econ.get("sellPriceRatio", 0.5))
	_black_buy_factor = float(econ.get("blackMarketBuyFactor", 1.4))
	_black_sell_factor = float(econ.get("blackMarketSellFactor", 1.4))
	_black_rarity_bonus = int(econ.get("blackMarketRarityBonus", 15))
	_rarity_gates = _dict_of(econ.get("rarityMinDevelopment", {}))
	_dragonforged_city = str(econ.get("dragonforgedCityId", ""))


# --- I-14 贸易结算 ---

## 结算一个月全部路线的收益与查抄。不修改任何状态，改动全部在返回值里。
##
## halted 是"封港中的城市"（城市事件：航道口被堵住，船只不敢进出）。这些城相关
## 的航线整条跳过——不产出、不查抄、也不消耗随机数，因为货根本没上船。跳过而不
## 是把收益算成 0：算成 0 会与"被查抄"混在一起，玩家分不清是自己被抄了还是港口
## 封着。中断的路线另记在 halted 里，由调用方给出归因文案。
##
## 返回 {regular, smuggling, legendary, confiscations, halted}
func settle_routes(
	world: WorldState, month: int, rng: DeterministicRNG, halted: Dictionary = {}
) -> Dictionary:
	var regular: Array = []
	var smuggling: Array = []
	var legendary: Array = []
	var confiscations: Array = []
	var halted_routes: Array = []

	for route in world.get_routes_sorted():
		if halted.has(str(route.city_a)) or halted.has(str(route.city_b)):
			halted_routes.append({
				"routeId": str(route.route_id),
				"cityId": str(route.city_a) if halted.has(str(route.city_a)) else str(route.city_b),
				"kind": str(route.kind),
			})
			continue
		for city_id in [route.city_a, route.city_b]:
			var city: City = world.get_city(city_id)
			if city == null:
				continue
			var wealth: int = 0
			var culture: int = 0
			var group: Array = regular
			if route.is_legendary():
				# 传奇航线不查抄、也不因治安中断——它买到的是"不受这套规则约束"
				# （《城市事件剧本》EV-02）。这里刻意不消耗随机数：多一条传奇航线
				# 不该改变其它航线的查抄序列。
				group = legendary
				wealth = _legendary_wealth
				culture = _legendary_culture
			elif route.is_smuggling():
				group = smuggling
				# 查抄概率 = 该城治安/100 × 0.2（9.4 节）。治安越差的城反而越安全，
				# 这是「治安高走正规、治安低走走私」这条分岔的机制来源。
				# 阈值 = 治安 × 20，分母 10000，治安 20 → 4%/月。
				if rng.next_int(SCALE * 100) < city.security * _confiscation_factor:
					confiscations.append({
						"routeId": str(route.route_id),
						"cityId": city_id,
						"month": month,
						"reputationLoss": _confiscation_reputation_loss,
						"karmaLoss": _confiscation_karma_loss,
						# 是不是玩家的航线。这里只如实报告，扣不扣由 WorldSim 决定——
						# "谁承担代价"属于世界账，不该由只读的结算器拍板。
						"playerOwned": route.is_player_owned(),
					})
					wealth = 0
					culture = 0
				else:
					wealth = _smuggling_wealth
					culture = _smuggling_culture
			else:
				wealth = _regular_wealth
				culture = _regular_culture
			group.append({
				"routeId": str(route.route_id),
				"cityId": city_id,
				"kind": str(route.kind),
				"wealthMilli": wealth,
				"cultureMilli": culture,
				"playerOwned": route.is_player_owned(),
			})

	return {
		"regular": regular, "smuggling": smuggling, "legendary": legendary,
		"confiscations": confiscations, "halted": halted_routes,
	}


# --- I-12 查询价格 ---

## 实例层规则。商铺界面的卖出列表与铁匠铺都要写"精良长剑 +2 · 锋锐 +3 攻击"、
## 要算"下一级攻击是多少"，走这里拿，而不是各自再建一份——两处各读一份配置，
## 涨价规则一变就会分叉。
func item_rules() -> ItemInstance:
	return _items


## 某城某件商品的当前买价与收价。channel 取 shop / black_market。
##
## 五个因子相乘（基准价在 items.json 的 price 上）：
##   实际价 = 基准价 × 供需 × (1 − 治安/200) × 地区溢价 × 声誉 × 渠道
##
## 基准价里另外算进了实例层的那一部分：**给 instance_id 时按那一件实际的词缀与
## 强化算**（这是卖出，界面点的是具体哪一件），不给时按该稀有度应有的词缀算一个
## 期望溢价（这是买入，商铺卖的是新货、货架报价必须每次刷新都一样）。
## 两边口径相同，所以同一件货买进来再卖出去永远亏——收价仍是一半（D-56）。
##
## 返回里带上逐因子明细，界面要能回答"贵在哪"——只给一个数，玩家没法判断该不该
## 换个城买。`refused` 是敌视时商铺拒售的标记：价格照算，生意不做。
func get_price(
	world: WorldState, city_id: String, template_id: String,
	channel: String = CHANNEL_SHOP, instance_id: String = ""
) -> Dictionary:
	if not ALL_CHANNELS.has(channel):
		return _fail(ERROR_INVALID_ARGUMENT, "没有这个交易渠道：%s" % channel)
	var city: City = null if world == null else world.get_city(city_id)
	if city == null:
		return _fail(ERROR_NOT_FOUND, "没有这座城市：%s" % city_id)
	var template: Dictionary = ContentLoader.get_item(template_id)
	if template.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这件商品：%s" % template_id)
	if channel == CHANNEL_BLACK_MARKET and not city.has_black_market:
		return _fail(ERROR_PRECONDITION_FAILED, "%s 没有黑市" % city.display_name)

	var instance: Dictionary = _instance_of(world, instance_id, template_id)
	var affix_bonus: int = _items.affix_price_bonus(instance) if not instance.is_empty() \
		else _items.typical_affix_price_bonus(template_id)
	var enhancement_bonus: int = 0 if instance.is_empty() \
		else _items.enhancement_price_bonus(instance)
	var base: int = maxi(0, int(template.get("price", 0))) + affix_bonus + enhancement_bonus
	var category: String = str(template.get("category", ""))
	var dimension: String = str(_supply_by_category.get(category, _supply_fallback))
	var supply_value: int = city.get_dimension(dimension)
	var supply: float = _supply_factor(supply_value)
	var security: float = maxf(0.0, 1.0 - float(city.security) / float(_security_scale))
	var premium: float = maxf(0.0, city.price_premium)

	var reputation: int = 0
	if world != null and world.avatar != null:
		reputation = world.avatar.get_reputation(city_id)
	var refused: bool = channel == CHANNEL_SHOP and reputation <= _refuse_at
	# 黑市不问名声：敌视的城在商铺买不到东西，在黑市照样能销赃（D-43）
	var reputation_factor: float = 1.0
	if channel == CHANNEL_SHOP:
		if reputation >= _respect_threshold:
			reputation_factor = _respect_factor
		elif reputation <= _wary_threshold:
			# 敌视也落在这一档：生意都不做了，价格只作展示，别让它在界面上跳成 1.0
			reputation_factor = _wary_factor
	var buy_factor: float = _black_buy_factor if channel == CHANNEL_BLACK_MARKET else 1.0
	var sell_factor: float = _black_sell_factor if channel == CHANNEL_BLACK_MARKET else 1.0

	var unit_price: int = maxi(1, int(round(
		float(base) * supply * security * premium * reputation_factor * buy_factor
	)))
	# 收价不吃声誉：敬重是"买得便宜"，不是"卖得贵"（D-44）。同一座城里买贵卖贱，
	# 所以原地倒手永远亏——要赚差价只能把货搬到物价高的城去。
	var sell_price: int = maxi(1, int(round(
		float(base) * supply * security * premium * _sell_ratio * sell_factor
	)))

	return {
		"ok": true,
		"errorCode": ERROR_NONE,
		"error": "",
		"cityId": city.city_id,
		"cityName": city.display_name,
		"templateId": str(template.get("templateId", template_id)),
		"displayName": str(template.get("displayName", template_id)),
		"category": category,
		"rarity": str(template.get("rarity", "")),
		"channel": channel,
		"channelLabel": channel_label(channel),
		"basePrice": base,
		"templatePrice": maxi(0, int(template.get("price", 0))),
		"affixBonus": affix_bonus,
		"enhancementBonus": enhancement_bonus,
		"unitPrice": unit_price,
		"sellPrice": sell_price,
		"supplyFactor": supply,
		"supplyDimension": dimension,
		"supplyDimensionLabel": str(City.DIMENSION_LABELS.get(dimension, dimension)),
		"supplyValue": supply_value,
		"securityFactor": security,
		"securityValue": city.security,
		"premiumFactor": premium,
		"reputation": reputation,
		"reputationFactor": reputation_factor,
		"channelBuyFactor": buy_factor,
		"channelSellFactor": sell_factor,
		"refused": refused,
	}


# --- 货架 ---

## 某城某个渠道今天摆得出来的货（随城市状态变化，D-45）。顺序固定：先按类别、
## 再按价格、最后按模板 id——顺序不稳的话界面每次打开都在跳，测试也无从断言。
##
## 输入不合法时返回空货架（界面拿到的是"没得卖"，而不是需要另判的错）。
func list_stock(
	world: WorldState, city_id: String, channel: String = CHANNEL_SHOP
) -> Array:
	if not ALL_CHANNELS.has(channel):
		return []
	var city: City = null if world == null else world.get_city(city_id)
	if city == null:
		return []
	if channel == CHANNEL_BLACK_MARKET and not city.has_black_market:
		return []

	var rows: Array = []
	for template in ContentLoader.get_items():
		if not (template is Dictionary):
			continue
		var entry: Dictionary = template
		if not is_available(city, entry, channel):
			continue
		var quote: Dictionary = get_price(world, city_id, str(entry.get("templateId", "")), channel)
		if quote.get("ok", false):
			rows.append(quote)
	rows.sort_custom(_sort_quotes)
	return rows


## 这件货在不在货架上：稀有度门槛按城市发展度判（黑市把门槛放宽 blackMarketRarityBonus），
## 龙魂/神造另加一条产地约束——它只能由传奇生物材料打造，只有铁锤堡造得出来。
func is_available(city: City, template: Dictionary, channel: String = CHANNEL_SHOP) -> bool:
	if city == null:
		return false
	# M14 只售基础材料：中间/高级材料（铁锭、皮革、碳、附魔粉尘等）不进货架，
	# 只能靠采集/制造/掉落——不然"不采就没高级货"这句就落空了。
	if str(template.get("category", "")) == "material" \
		and not bool(template.get("baseMaterial", false)):
		return false
	var rarity: String = str(template.get("rarity", ""))
	if rarity == RARITY_DRAGONFORGED and city.city_id != _dragonforged_city:
		return false
	var development: int = city.development
	if channel == CHANNEL_BLACK_MARKET:
		development += _black_rarity_bonus
	return development >= int(_rarity_gates.get(rarity, 0))


static func _sort_quotes(a: Dictionary, b: Dictionary) -> bool:
	var rank_a: int = _category_rank(str(a.get("category", "")))
	var rank_b: int = _category_rank(str(b.get("category", "")))
	if rank_a != rank_b:
		return rank_a < rank_b
	var price_a: int = int(a.get("unitPrice", 0))
	var price_b: int = int(b.get("unitPrice", 0))
	if price_a != price_b:
		return price_a < price_b
	return str(a.get("templateId", "")) < str(b.get("templateId", ""))


## 表里没有的类别排在最后。写死一个 99 会让"以后加了新类别"这件事悄悄沉底，
## 而沉底在界面上看不出任何异常。
static func _category_rank(category: String) -> int:
	var index: int = CATEGORY_ORDER.find(category)
	return index if index >= 0 else CATEGORY_ORDER.size()


# --- I-13 执行买卖 ---

## 执行一次买卖。买：扣钱、货进背包；卖：货出背包、钱到手。当场结清，不进变更队列。
##
## 一次一件：`instance_id` 只在卖的时候有用（背包里同名货可能有多件，界面点的是
## 具体那一件）。不给 instance_id 时卖背包里最靠前的那一件——顺序由 inventory
## 决定，因此同一份存档重放同一次点击卖的是同一件。
func execute_trade(
	world: WorldState, city_id: String, template_id: String, side: String,
	channel: String = CHANNEL_SHOP, instance_id: String = ""
) -> Dictionary:
	if side != SIDE_BUY and side != SIDE_SELL:
		return _fail(ERROR_INVALID_ARGUMENT, "没有这种买卖方向：%s" % side)
	var quote: Dictionary = get_price(world, city_id, template_id, channel)
	if not quote.get("ok", false):
		return quote
	if bool(quote.get("refused", false)):
		return _fail(ERROR_PRECONDITION_FAILED, "%s 的%s不做你的生意——先把名声攒回来" % [
			str(quote.get("cityName", "")), str(quote.get("channelLabel", ""))
		])
	var avatar: PlayerAvatar = null if world == null else world.avatar
	if avatar == null:
		return _fail(ERROR_PRECONDITION_FAILED, "还没有化身，做不了买卖")
	var city: City = world.get_city(city_id)
	var template: Dictionary = ContentLoader.get_item(template_id)

	var result: Dictionary = {
		"ok": true,
		"errorCode": ERROR_NONE,
		"error": "",
		"side": side,
		"cityId": city_id,
		"channel": channel,
		"channelLabel": channel_label(channel),
		"templateId": template_id,
		"displayName": str(quote.get("displayName", template_id)),
		"unitPrice": int(quote.get("unitPrice", 0)),
		"sellPrice": int(quote.get("sellPrice", 0)),
	}

	if side == SIDE_BUY:
		if not is_available(city, template, channel):
			return _fail(ERROR_NOT_FOUND, "%s 没有这件货" % str(quote.get("cityName", "")))
		var price: int = int(quote.get("unitPrice", 0))
		if avatar.money < price:
			return _fail(ERROR_PRECONDITION_FAILED, "钱不够：%s 要 %d 铜，你只有 %d 铜" % [
				str(quote.get("displayName", "")), price, avatar.money
			])
		avatar.money -= price
		var new_id: String = _make_instance_id(avatar)
		# 成交的货就是货架上报价的那一件：同一个种子摇同一批词缀，所以价目表上
		# 写着的溢价与到手的货对得上（D-56）。
		CharacterCreation.add_item(
			avatar, template_id, new_id, shop_seed(city_id, channel, template_id)
		)
		result["money"] = price
		result["moneyAfter"] = avatar.money
		result["instanceId"] = new_id
		return result

	# 穿在身上的东西不能卖：装备槽里的实例已经不在背包里（Equipment.equip 会把它
	# 从 inventory 摘掉），所以这一步本来是结构性成立的；这里显式挡一次，是为了
	# 给出"先脱下"这句话，而不是让玩家看到"背包里没有这件货"（D-53）。
	if not instance_id.is_empty() and avatar.equipment.values().has(instance_id):
		return _fail(ERROR_PRECONDITION_FAILED, "身上的东西不能卖：先把「%s」脱下" % str(
			quote.get("displayName", "")
		))
	var taken: Dictionary = _take_from_inventory(avatar, template_id, instance_id)
	if taken.is_empty():
		return _fail(ERROR_NOT_FOUND, "背包里没有这件货：%s" % str(quote.get("displayName", "")))
	var gained: int = int(quote.get("sellPrice", 0))
	avatar.money += gained
	result["money"] = gained
	result["moneyAfter"] = avatar.money
	result["instanceId"] = str(taken.get("instanceId", ""))
	return result


## 从背包里取出一件指定模板的货。给 instance_id 时必须是那一件、且模板对得上
## （界面点的是行，行与该行的货对不上说明板面已经过期）。
func _take_from_inventory(
	avatar: PlayerAvatar, template_id: String, instance_id: String
) -> Dictionary:
	var target: String = instance_id
	if not target.is_empty():
		if not avatar.item_instances.has(target) or not avatar.inventory.has(target):
			return {}
		var instance: Dictionary = avatar.item_instances[target]
		if not template_id.is_empty() and str(instance.get("templateId", "")) != template_id:
			return {}
	else:
		for held in avatar.inventory:
			var instance: Dictionary = avatar.item_instances.get(held, {})
			if str(instance.get("templateId", "")) == template_id:
				target = str(held)
				break
	if target.is_empty():
		return {}
	avatar.inventory.erase(target)
	avatar.item_instances.erase(target)
	return {"instanceId": target}


## 从背包或身上的行装里找那一件实例。给 instance_id 时必须是这一件、且模板对得上
## （界面点的是行，行与该行的货对不上说明板面已经过期），对不上就当没给——
## 于是它退回"按模板报价"，而不是报一个错。
func _instance_of(world: WorldState, instance_id: String, template_id: String) -> Dictionary:
	if instance_id.is_empty() or world == null or world.avatar == null:
		return {}
	var value: Variant = world.avatar.item_instances.get(instance_id, null)
	if not (value is Dictionary):
		return {}
	var instance: Dictionary = value
	if str(instance.get("templateId", "")) != template_id:
		return {}
	return instance


## 货架上那一件货的种子。**与 instance_id 无关**：商铺的报价与到手的货必须是
## 同一件，而成交时实例 id 才刚生成。同一座城、同一渠道、同一件货因此永远摇出
## 同一批词缀——"这家店常年摆着这么一批货"，也是货架报价能稳定下来的前提（D-56）。
func shop_seed(city_id: String, channel: String, template_id: String) -> String:
	return "shop|%s|%s|%s" % [city_id, channel, template_id]


## 买入物品的实例 ID。按背包现有件数往后取号，撞号就继续往后挪——与出身初始物品、
## 战斗战利品的编号方式一致，不必在存档里多养一个计数器。
func _make_instance_id(avatar: PlayerAvatar) -> String:
	var seq: int = avatar.inventory.size() + 1
	var candidate: String = "%s-trade-%03d" % [avatar.avatar_id, seq]
	while avatar.item_instances.has(candidate):
		seq += 1
		candidate = "%s-trade-%03d" % [avatar.avatar_id, seq]
	return candidate


# --- 供需区间 ---

## 供需系数。短缺（该维低于 shortageAt）时越缺越贵，过剩（高于 surplusAt）时
## 越足越贱，中间是 1.0 的正常档（D-43：文档只给了两段区间，中间那段是补出来的）。
func _supply_factor(value: int) -> float:
	if value <= _shortage_at:
		var ratio: float = clampf(float(value) / float(maxi(1, _shortage_at)), 0.0, 1.0)
		return lerpf(_shortage_factor_zero, _shortage_factor_edge, ratio)
	if value >= _surplus_at:
		var span: float = float(maxi(1, _dim_max - _surplus_at))
		var ratio: float = clampf(float(value - _surplus_at) / span, 0.0, 1.0)
		return lerpf(_surplus_factor_edge, _surplus_factor_max, ratio)
	return 1.0


static func channel_label(channel: String) -> String:
	return str(CHANNEL_LABELS.get(channel, channel))


static func _fail(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"errorCode": error_code,
		"error": message,
	}


## 配置里显式写 null 时 Dictionary.get 的缺省值不生效，所以判型要显式做一次。
static func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## 暴露给界面与测试的规则快照。界面要摆出"为什么这个价"时读它，
## 不必各自去 ContentLoader 里翻。
func rules() -> Dictionary:
	return {
		"supplyDimensionByCategory": _supply_by_category.duplicate(),
		"supplyDimensionFallback": _supply_fallback,
		"shortageAt": _shortage_at,
		"surplusAt": _surplus_at,
		"reputationRespectThreshold": _respect_threshold,
		"reputationWaryThreshold": _wary_threshold,
		"reputationRefuseAt": _refuse_at,
		"sellPriceRatio": _sell_ratio,
		"rarityMinDevelopment": _rarity_gates.duplicate(),
		"dragonforgedCityId": _dragonforged_city,
	}


static func _permille(cfg: Dictionary, key: String, fallback: float) -> int:
	return int(round(float(cfg.get(key, fallback)) * float(SCALE)))
