class_name TradeViewModel
extends RefCounted

## 商铺 / 黑市界面的视图模型（接口 I-12 / I-13 的表现层）。
##
## 与其它视图模型同一个理由："面板该显示什么"是纯函数，能在无头环境里被验收
## 测试钉住；"怎么画"留给 TradePanel。
##
## 两件事在这里被翻译成人话：
##   1. 价格要说得清"贵在哪"。Economy.get_price 给的是五个因子，界面若只写一个
##      数字，玩家没法判断该不该换个城买——而"换个城买"正是这套物价的全部意义。
##   2. 买与卖是同一块版面的两侧。买看货架（Economy.list_stock），卖看背包，
##      两边的行长得一样，右列都写同一件货的价目。
##
## 名字解析走调用方传入的查询表（itemTemplates），不直接读 ContentLoader——
## 与 AvatarViewModel 同一条理由：测试可以塞小样本进去。

## 左右两侧的买卖动作。与 Economy 的 SIDE_* 取同一个字符串：这是跨模块契约，
## 界面拿它做分支，拼错一次就会静默地什么都不做。
const SIDE_BUY: String = Economy.SIDE_BUY
const SIDE_SELL: String = Economy.SIDE_SELL

const CATEGORY_LABELS: Dictionary = {
	"weapon": "武器", "armor": "防具", "consumable": "消耗品",
}

const ROW_KIND_STOCK: String = "stock"
const ROW_KIND_HELD: String = "held"
const ROW_KIND_FORGE: String = "forge"

## 这块版面的两种用途。商铺与黑市都是"买卖"（靠 side 分买入卖出），铁匠铺是
## "改货"——它没有买卖方向，所以不能塞进 side 里；而它又该长在同一个版面上
## （同一个入口、同一套光标与页脚），所以用 pane 分。见 D-57。
const PANE_TRADE: String = "trade"
const PANE_FORGE: String = "forge"
## 铁匠铺的第二档活计：修理（D-64）。与强化共用一块版面——都是"看着一件货决定
## 花钱"，分开的两个 pane 各写各的工钱。工匠修回九成、满修修到满，两档在这里切换。
const PANE_REPAIR: String = "repair"

const ROW_KIND_REPAIR: String = "repair"


## 卖东西时不看可得性：商铺什么都收（收价是公式价的一半），龙魂装备也照样
## 折价收——它只是"能不能上架"受城的限制，不是"能不能出手"。
##
## pane 决定这块版面是买卖还是铁匠铺；是铁匠铺时 side 与 channel 都无关。
static func build(
	world: WorldState,
	economy: Economy,
	lookups: Dictionary,
	city_id: String,
	here_city_id: String,
	channel: String,
	side: String,
	cursor: int,
	pane: String = PANE_TRADE
) -> Dictionary:
	var city: City = null if world == null else world.get_city(city_id)
	if city == null or economy == null:
		return {}
	if not Economy.ALL_CHANNELS.has(channel):
		channel = Economy.CHANNEL_SHOP
	if side != SIDE_SELL:
		side = SIDE_BUY

	var templates: Dictionary = _lookup(lookups, "itemTemplates")
	var avatar: PlayerAvatar = world.avatar
	var money: int = 0 if avatar == null else avatar.money
	var at_city: bool = not here_city_id.is_empty() and here_city_id == city_id
	var has_market: bool = city.has_black_market

	if pane == PANE_FORGE:
		return _build_forge(
			economy, templates, avatar, city, at_city, money, cursor, channel, side
		)
	if pane == PANE_REPAIR:
		return _build_repair(
			economy, templates, avatar, city, at_city, money, cursor, side
		)

	var rows: Array = []
	if side == SIDE_BUY:
		for quote in economy.list_stock(world, city_id, channel):
			rows.append(_stock_row(quote, templates, money, at_city))
	else:
		rows.append_array(_held_rows(world, economy, city_id, channel, templates, avatar, at_city))

	cursor = clampi(cursor, 0, maxi(0, rows.size() - 1))
	var selected: Dictionary = rows[cursor] if not rows.is_empty() else {}
	var quote: Dictionary = economy.get_price(
		world, city_id, _quote_template_id(selected), channel
	)
	if not quote.get("ok", false):
		quote = {}

	var refused: bool = bool(quote.get("refused", false))
	var black: bool = channel == Economy.CHANNEL_BLACK_MARKET
	var blocked: String = ""
	if avatar == null:
		blocked = "还没有化身，先完成开局创建。"
	elif not at_city:
		blocked = "你不在这座城——价格看得到，货要亲自去取。"
	elif refused:
		blocked = "%s不做你的生意。名声坏了之后，黑市是唯一的出路。" % (
			"掌柜" if not black else "贩子"
		)
	elif rows.is_empty():
		blocked = "这里没摆出什么货。" if side == SIDE_BUY else "你身上没什么可卖的。"
	elif not bool(selected.get("enabled", true)):
		blocked = str(selected.get("blockedReason", ""))

	# 成交后的账面。买是掏钱、卖是进钱，两种方向在这里汇成一句给玩家看的话——
	# 页脚只负责印出来，不再自己算一遍（算了就会与 execute_trade 慢慢分叉）。
	var deal_price: int = int(selected.get("price", 0))
	var money_after: int = money - deal_price if side == SIDE_BUY else money + deal_price

	return {
		"pane": PANE_TRADE,
		"cityId": city_id,
		"cityLabel": city.display_name,
		"channel": channel,
		"channelLabel": Economy.channel_label(channel),
		"hasBlackMarket": has_market,
		"otherChannel": Economy.CHANNEL_SHOP if black else Economy.CHANNEL_BLACK_MARKET,
		"side": side,
		"sideLabel": "买入" if side == SIDE_BUY else "卖出",
		"otherSide": SIDE_SELL if side == SIDE_BUY else SIDE_BUY,
		"atCity": at_city,
		"refused": refused,
		"rows": rows,
		"rowCount": rows.size(),
		"cursor": cursor,
		"selected": _detail(selected, quote, templates, side),
		"money": money,
		"moneyLabel": AvatarViewModel.money_label(money),
		"moneyAfterLabel": AvatarViewModel.money_label(money_after),
		"dealSummary": "回车成交：%s %s（%s），身上 %s → %s。" % [
			"买入" if side == SIDE_BUY else "卖出",
			str(selected.get("label", "")),
			AvatarViewModel.money_label(deal_price),
			AvatarViewModel.money_label(money),
			AvatarViewModel.money_label(money_after),
		],
		"canTrade": blocked.is_empty() and not selected.is_empty(),
		"blockedReason": blocked,
	}


static func _quote_template_id(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	return str(row.get("templateId", ""))


## 货架上的一行。
static func _stock_row(
	quote: Dictionary, templates: Dictionary, money: int, at_city: bool
) -> Dictionary:
	var template_id: String = str(quote.get("templateId", ""))
	var template: Dictionary = _template(templates, template_id)
	var price: int = int(quote.get("unitPrice", 0))
	var affordable: bool = money >= price
	return {
		"kind": ROW_KIND_STOCK,
		"instanceId": "",
		"templateId": template_id,
		"label": _name(template, template_id),
		"rarityLabel": _rarity(template),
		"categoryLabel": _category(template),
		"detail": AvatarViewModel.item_detail(template),
		"price": price,
		"priceText": AvatarViewModel.money_label(price),
		"heldCount": 0,
		"enabled": at_city and affordable,
		"blockedReason": "" if affordable else "钱不够，先把 %s 攒出来。" % (
			AvatarViewModel.money_label(price - money)
		),
	}


## 背包里的每一行。同名多件各占一行——界面点的是一件具体的货，销赃时
## 卖掉的也必须是那一件（Economy.execute_trade 按 instanceId 取）。
##
## **每一件各报各的价**：同名多件的强化与词缀不同（一件 +2、一件白板），
## 价钱也就不该一样。这是"实例各不相同"这件事在价钱上第一次露出来（D-56）。
##
## 穿在身上的不会出现在这里：装备槽里的实例不在 avatar.inventory 里（穿戴会把它
## 从背包摘掉），所以"身上的货卖不掉"这条规则不需要在这儿再写一遍。逻辑层另有一道
## 显式拦截，为的是给出"先把它脱下"这句话（D-53）。
static func _held_rows(
	world: WorldState, economy: Economy, city_id: String, channel: String,
	templates: Dictionary, avatar: PlayerAvatar, at_city: bool
) -> Array:
	if avatar == null:
		return []
	var rules: ItemInstance = economy.item_rules()
	var rows: Array = []
	for instance_id in avatar.inventory:
		var instance: Dictionary = avatar.item_instances.get(instance_id, {})
		var template_id: String = str(instance.get("templateId", ""))
		if template_id.is_empty():
			continue
		var template: Dictionary = _template(templates, template_id)
		var quote: Dictionary = economy.get_price(
			world, city_id, template_id, channel, str(instance_id)
		)
		var row: Dictionary = AvatarViewModel.instance_info(rules, instance, template)
		row["kind"] = ROW_KIND_HELD
		row["instanceId"] = str(instance_id)
		row["templateId"] = template_id
		row["categoryLabel"] = _category(template)
		row["price"] = int(quote.get("sellPrice", 0)) if quote.get("ok", false) else 0
		row["priceText"] = AvatarViewModel.money_label(int(row["price"]))
		row["enabled"] = at_city
		row["blockedReason"] = "要在这座城里才卖得掉。"
		rows.append(row)
	return rows


# --- 铁匠铺那一页 ---

## 铁匠铺的修理页（D-64）。与强化的区别只在"花的是修的钱而不是烧的钱"——
## 同一块版面、同一套光标。这里只有工匠与满修两档（都在城里、都花工钱）；
## 便携工具是"不占炉子"的活计，放在背包里随时可用，不进铁匠铺（见 PANE_REPAIR）。
static func _build_repair(
	economy: Economy, templates: Dictionary, avatar: PlayerAvatar, city: City,
	at_city: bool, money: int, cursor: int, side: String
) -> Dictionary:
	var rules: ItemInstance = economy.item_rules()
	var rows: Array = []
	if avatar != null:
		for instance_id in avatar.inventory:
			var instance: Dictionary = avatar.item_instances.get(instance_id, {})
			var template: Dictionary = _template(templates, str(instance.get("templateId", "")))
			# 只有会受损的装备才进得了修理页；消耗品与工具不会损坏
			if not ItemInstance.AFFIX_CATEGORIES.has(str(template.get("category", ""))):
				continue
			rows.append(_repair_row(rules, instance, template, str(instance_id), at_city, money))

	cursor = clampi(cursor, 0, maxi(0, rows.size() - 1))
	var selected: Dictionary = rows[cursor] if not rows.is_empty() else {}
	var blocked: String = ""
	if avatar == null:
		blocked = "还没有化身，先完成开局创建。"
	elif not at_city:
		blocked = "你不在这座城——炉子得当面烧，修理也是。"
	elif rows.is_empty():
		blocked = "背包里没有会坏的东西。"
	elif not bool(selected.get("enabled", true)):
		blocked = str(selected.get("blockedReason", ""))

	return {
		"pane": PANE_REPAIR,
		"cityId": city.city_id,
		"cityLabel": city.display_name,
		"channel": Economy.CHANNEL_SHOP,
		"channelLabel": "铁匠铺",
		"hasBlackMarket": city.has_black_market,
		"otherChannel": Economy.CHANNEL_SHOP,
		"side": side,
		"sideLabel": "修理",
		"otherSide": side,
		"atCity": at_city,
		"refused": false,
		"rows": rows,
		"rowCount": rows.size(),
		"cursor": cursor,
		"selected": _repair_detail(selected),
		"money": money,
		"moneyLabel": AvatarViewModel.money_label(money),
		"moneyAfterLabel": AvatarViewModel.money_label(
			maxi(0, money - int(selected.get("price", 0)))
		),
		"dealSummary": _repair_summary(selected),
		"canTrade": blocked.is_empty() and not selected.is_empty(),
		"blockedReason": blocked,
	}


## 修理页左列的一行。工钱那格写满修那档的价——玩家看的是"修到满要多少"，
## 工匠那档更便宜，敲回车时用 chosen 档位结算（见 PANE_REPAIR）。
static func _repair_row(
	rules: ItemInstance, instance: Dictionary, template: Dictionary,
	instance_id: String, at_city: bool, money: int
) -> Dictionary:
	var row: Dictionary = AvatarViewModel.instance_info(rules, instance, template)
	var full: int = rules.repair_cost(instance, ItemInstance.REPAIR_FULL)
	var craftsman: int = rules.repair_cost(instance, ItemInstance.REPAIR_CRAFTSMAN)
	var cheapest: int = mini(full, craftsman)
	var enabled: bool = not rules.broken(instance) \
		or full > 0 or craftsman > 0
	var blocked_reason: String = ""
	if at_city and rules.broken(instance) and full <= 0 and craftsman <= 0:
		blocked_reason = "满耐久，不用修"
	elif at_city and money < cheapest:
		blocked_reason = "钱不够修到最便宜的那档"
	row["instanceId"] = instance_id
	row["kind"] = ROW_KIND_REPAIR
	row["price"] = cheapest  # 页脚按最省的那档报
	row["fullCost"] = full
	row["craftsmanCost"] = craftsman
	row["enabled"] = enabled and at_city and not blocked_reason
	row["blockedReason"] = blocked_reason
	row["storeBlocked"] = not at_city
	return row


static func _repair_summary(selected: Dictionary) -> String:
	if selected.is_empty():
		return ""
	if not bool(selected.get("enabled", true)):
		return str(selected.get("blockedReason", ""))
	return "回车修理：%s，工匠 %s / 满修 %s（满修按强化等级加价）。" % [
		str(selected.get("label", "")),
		AvatarViewModel.money_label(int(selected.get("craftsmanCost", 0))),
		AvatarViewModel.money_label(int(selected.get("fullCost", 0))),
	]


## 修理页右列：耐久的现在与两档修完的样子。和强化页一样 "一项、一个值、一句解释"。
static func _repair_detail(selected: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {}
	var factors: Array = [
		{"label": "当前耐久", "value": str(selected.get("durabilityText", "")),
			"hint": "损坏则都不参与数值"},
		{"label": "工匠", "value": AvatarViewModel.money_label(int(selected.get("craftsmanCost", 0))),
			"hint": "修回九成"},
		{"label": "满修", "value": AvatarViewModel.money_label(int(selected.get("fullCost", 0))),
			"hint": "修到满，按强化等级加价"},
	]
	return {
		"templateId": str(selected.get("templateId", "")),
		"label": str(selected.get("label", "")),
		"rarityLabel": str(selected.get("rarityLabel", "")),
		"categoryLabel": str(selected.get("categoryLabel", "")),
		"detail": str(selected.get("detail", "")),
		"durabilityText": str(selected.get("durabilityText", "")),
		"side": PANE_REPAIR,
		"sideLabel": "修理",
		"kind": ROW_KIND_REPAIR,
		"instanceId": str(selected.get("instanceId", "")),
		"price": int(selected.get("price", 0)),
		"unitPriceText": str(selected.get("durabilityText", "")),
		"sellPriceText": "满修",
		"dealText": str(selected.get("fullCost", 0)),
		"factorRows": factors,
		"affixRows": selected.get("affixRows", []),
		"refused": false,
	}

## 铁匠铺。左列是背包里能进炉子的货（武器与防具），右列是选中那一件的现在与
## 下一级。它和买卖共用这块版面，因为玩家在这里做的事与在商铺里是同一件——
## "看着一件货，决定要不要花钱"；区别只在花的是买货的钱还是改货的钱（D-57）。
static func _build_forge(
	economy: Economy, templates: Dictionary, avatar: PlayerAvatar, city: City,
	at_city: bool, money: int, cursor: int, channel: String, side: String
) -> Dictionary:
	var rules: ItemInstance = economy.item_rules()
	var rows: Array = []
	if avatar != null:
		for instance_id in avatar.inventory:
			var instance: Dictionary = avatar.item_instances.get(instance_id, {})
			var template: Dictionary = _template(templates, str(instance.get("templateId", "")))
			# 只有装备进得了炉子：消耗品的"强化"是炼金，那是另一件事
			if not ItemInstance.AFFIX_CATEGORIES.has(str(template.get("category", ""))):
				continue
			rows.append(_forge_row(rules, instance, template, str(instance_id), at_city, money))

	cursor = clampi(cursor, 0, maxi(0, rows.size() - 1))
	var selected: Dictionary = rows[cursor] if not rows.is_empty() else {}
	var blocked: String = ""
	if avatar == null:
		blocked = "还没有化身，先完成开局创建。"
	elif not at_city:
		blocked = "你不在这座城——炉子得当面烧。"
	elif rows.is_empty():
		blocked = "背包里没有能进炉子的东西。"
	elif not bool(selected.get("enabled", true)):
		blocked = str(selected.get("blockedReason", ""))

	return {
		"pane": PANE_FORGE,
		"cityId": city.city_id,
		"cityLabel": city.display_name,
		"channel": channel,
		"channelLabel": "铁匠铺",
		"hasBlackMarket": city.has_black_market,
		"otherChannel": Economy.CHANNEL_SHOP,
		"side": side,
		"sideLabel": "强化",
		"otherSide": side,
		"atCity": at_city,
		"refused": false,
		"rows": rows,
		"rowCount": rows.size(),
		"cursor": cursor,
		"selected": _forge_detail(selected),
		"money": money,
		"moneyLabel": AvatarViewModel.money_label(money),
		"moneyAfterLabel": AvatarViewModel.money_label(
			maxi(0, money - int(selected.get("price", 0)))
		),
		"dealSummary": _forge_summary(selected),
		"canTrade": blocked.is_empty() and not selected.is_empty(),
		"blockedReason": blocked,
	}


## 铁匠铺左列的一行。价格那一格写的是**这一炉的工钱**，不是货价——
## 玩家在这里花的是工钱，"到顶了"与"钱不够"都写在同一个位置，扫一眼就知道。
static func _forge_row(
	rules: ItemInstance, instance: Dictionary, template: Dictionary,
	instance_id: String, at_city: bool, money: int
) -> Dictionary:
	var row: Dictionary = AvatarViewModel.instance_info(rules, instance, template)
	var level: int = rules.enhancement(instance)
	var cap: int = rules.enhancement_max()
	var cost: int = rules.enhancement_cost(instance)
	var chance: int = rules.enhancement_chance_bp(instance)
	row["kind"] = ROW_KIND_FORGE
	row["instanceId"] = instance_id
	row["templateId"] = str(instance.get("templateId", ""))
	row["categoryLabel"] = _category(template)
	row["level"] = level
	row["cap"] = cap
	row["levelLabel"] = _level_label(level)
	row["chanceText"] = _percent(chance)
	row["costText"] = AvatarViewModel.money_label(cost)
	row["nextText"] = _next_level_text(rules, instance, level, cap)
	row["price"] = cost
	row["priceText"] = "已到顶" if level >= cap else AvatarViewModel.money_label(cost)
	row["enabled"] = at_city and level < cap and money >= cost
	row["blockedReason"] = _forge_block_reason(at_city, level, cap, cost, money)
	return row


## 下一级会改哪些数字。拿一份副本多强化一级算出来——"这一炉买到了什么"
## 是玩家按下回车之前唯一需要知道的事。
static func _next_level_text(
	rules: ItemInstance, instance: Dictionary, level: int, cap: int
) -> String:
	if level >= cap:
		return "已经到顶"
	var preview: Dictionary = instance.duplicate(true)
	preview["enhancement"] = level + 1
	var now: Dictionary = rules.effective_stats(instance)
	var next: Dictionary = rules.effective_stats(preview)
	var labels: Dictionary = {
		ItemInstance.STAT_ATTACK: "伤害",
		ItemInstance.STAT_ARMOR: "护甲",
		ItemInstance.STAT_MAGIC_RESIST: "魔抗",
	}
	var parts: Array = []
	for stat in [ItemInstance.STAT_ATTACK, ItemInstance.STAT_ARMOR,
			ItemInstance.STAT_MAGIC_RESIST]:
		if int(next[stat]) == int(now[stat]):
			continue
		parts.append("%s %d → %d" % [str(labels[stat]), int(now[stat]), int(next[stat])])
	if parts.is_empty():
		return "这一级不改变数值（模板这一项是 0）"
	return " · ".join(PackedStringArray(parts))


static func _forge_block_reason(
	at_city: bool, level: int, cap: int, cost: int, money: int
) -> String:
	if not at_city:
		return "要在这座城里才进得了炉子。"
	if level >= cap:
		return "已经强化到顶（+%d）。" % cap
	if money < cost:
		return "钱不够：这一炉要 %s，你只有 %s。" % [
			AvatarViewModel.money_label(cost), AvatarViewModel.money_label(money)
		]
	return ""


static func _forge_summary(selected: Dictionary) -> String:
	if selected.is_empty():
		return ""
	if not bool(selected.get("enabled", true)):
		return str(selected.get("blockedReason", ""))
	return "回车敲一炉：%s → %s（成功率 %s），花费 %s。" % [
		str(selected.get("levelLabel", "")),
		_level_label(int(selected.get("level", 0)) + 1),
		str(selected.get("chanceText", "")),
		str(selected.get("costText", "")),
	]


## 右列：这一件的现在与下一级。沿用价目那套"左边一项、右边一个值、后面一句解释"
## 的排法——两页长得一样，玩家换页时就不用重新认版。
static func _forge_detail(selected: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {}
	var level: int = int(selected.get("level", 0))
	var cap: int = int(selected.get("cap", 0))
	var factors: Array = [
		{"label": "当前等级", "value": str(selected.get("levelLabel", "")),
			"hint": "上限 +%d" % cap},
		{"label": "下一级", "value": _level_label(level + 1),
			"hint": str(selected.get("nextText", ""))},
		{"label": "成功率", "value": str(selected.get("chanceText", "")),
			"hint": "失败掉一级，钱照扣"},
		{"label": "工钱", "value": str(selected.get("costText", "")),
			"hint": "按基准价与等级取"},
	]
	return {
		"templateId": str(selected.get("templateId", "")),
		"label": str(selected.get("label", "")),
		"rarityLabel": str(selected.get("rarityLabel", "")),
		"categoryLabel": str(selected.get("categoryLabel", "")),
		"detail": str(selected.get("detail", "")),
		"durabilityText": str(selected.get("durabilityText", "")),
		"side": PANE_FORGE,
		"sideLabel": "强化",
		"kind": ROW_KIND_FORGE,
		"instanceId": str(selected.get("instanceId", "")),
		"price": int(selected.get("price", 0)),
		"unitPriceText": _level_label(level),
		"sellPriceText": _level_label(level + 1),
		"dealText": str(selected.get("costText", "")),
		"factorRows": factors,
		"affixRows": selected.get("affixRows", []),
		"refused": false,
	}


static func _level_label(level: int) -> String:
	return "未强化" if level <= 0 else "+%d" % level


## 基点转百分数（成功率）。取整数——"85.0%" 与 "85%" 说的是同一件事，
## 而多一个小数点只会让这一列看起来更挤。
static func _percent(bp: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = bp / 100
	return "%d%%" % whole


## 右列：这件货的价目。逐因子列出来，玩家才看得出"贵在哪"。
static func _detail(
	selected: Dictionary, quote: Dictionary, templates: Dictionary, side: String
) -> Dictionary:
	if selected.is_empty():
		return {}
	var template_id: String = str(selected.get("templateId", ""))
	var template: Dictionary = _template(templates, template_id)
	var factors: Array = []
	if not quote.is_empty():
		factors = [
			{"label": "基准价", "value": AvatarViewModel.money_label(int(quote.get("basePrice", 0))),
				"hint": "《数值框架》9.2"},
			{"label": "供需 · %s %d" % [
				str(quote.get("supplyDimensionLabel", "")), int(quote.get("supplyValue", 0))
			], "value": "×%.2f" % float(quote.get("supplyFactor", 1.0)),
				"hint": "缺则贵、足则贱"},
			{"label": "治安 %d" % int(quote.get("securityValue", 0)),
				"value": "×%.2f" % float(quote.get("securityFactor", 1.0)),
				"hint": "治安差则乱世抬价"},
			{"label": "地区溢价", "value": "×%.2f" % float(quote.get("premiumFactor", 1.0)),
				"hint": "这座城本身的贵贱"},
			{"label": "名声 %+d" % int(quote.get("reputation", 0)),
				"value": "×%.2f" % float(quote.get("reputationFactor", 1.0)),
				"hint": "敬重折扣、警惕抬价"},
			{"label": "渠道", "value": "×%.2f" % float(quote.get("channelBuyFactor", 1.0)),
				"hint": str(quote.get("channelLabel", ""))},
		]
	return {
		"templateId": template_id,
		"label": str(selected.get("label", template_id)),
		"rarityLabel": str(selected.get("rarityLabel", "")),
		"categoryLabel": str(selected.get("categoryLabel", "")),
		"detail": str(selected.get("detail", "")),
		"effectText": str(template.get("effectText", "")),
		"side": side,
		"sideLabel": "买入" if side == SIDE_BUY else "卖出",
		# 可成交的那几项原样带过来：调用方拿到 selected 就能直接下单，不必回头
		# 按光标去 rows 里再找一次——那样"选中的"与"卖掉的"就有可能不是同一件
		# （同名多件时，rows 的顺序变了就会卖掉另一件）。
		"kind": str(selected.get("kind", "")),
		"instanceId": str(selected.get("instanceId", "")),
		"price": int(selected.get("price", 0)),
		"baseText": "基准价 %s" % AvatarViewModel.money_label(int(quote.get("basePrice", 0))),
		"unitPriceText": AvatarViewModel.money_label(int(quote.get("unitPrice", 0))),
		"sellPriceText": AvatarViewModel.money_label(int(quote.get("sellPrice", 0))),
		"dealText": AvatarViewModel.money_label(int(selected.get("price", 0))),
		"factorRows": factors,
		"refused": bool(quote.get("refused", false)),
	}


static func _template(templates: Dictionary, template_id: String) -> Dictionary:
	var value: Variant = templates.get(template_id, null)
	return value if value is Dictionary else {}


static func _name(template: Dictionary, template_id: String) -> String:
	return str(template.get("displayName", template_id))


static func _rarity(template: Dictionary) -> String:
	return str(AvatarViewModel.RARITY_LABELS.get(str(template.get("rarity", "")), "—"))


static func _category(template: Dictionary) -> String:
	return str(CATEGORY_LABELS.get(str(template.get("category", "")), "杂项"))


## 与 AvatarViewModel 同一条约定：查不到就退回空表，于是名字退化成 ID，
## 界面仍然画得出来。
static func _lookup(lookups: Dictionary, key: String) -> Dictionary:
	var value: Variant = lookups.get(key, null)
	return value if value is Dictionary else {}
