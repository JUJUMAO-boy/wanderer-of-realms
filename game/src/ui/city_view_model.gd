class_name CityViewModel
extends RefCounted

## 城市面板的视图模型：把世界状态整理成界面能直接画的结构。
##
## 这一层是纯函数，不碰渲染、不碰节点，因此可以在无头环境下被测试。
## 之所以要单独拆出来，是因为"世界演化看不看得见"最终落在这些数字与文案的
## 组织方式上——净变化 +0.4 与「出生 +0.31 · 死亡 -0.45 · 净移民 +0.50」
## 是两种完全不同的信息。组织逻辑放这里，才能被验收测试钉住。

## 维度显示顺序。按"先人后财、先内后外"排，读者看一遍就建立起城市的心智模型。
const DIMENSION_ORDER: Array = [
	City.DIM_POPULATION,
	City.DIM_WEALTH,
	City.DIM_DEVELOPMENT,
	City.DIM_SECURITY,
	City.DIM_CULTURE,
	City.DIM_FACTION,
]

## 趋势线默认展示的维度
const DEFAULT_TREND_DIMENSION: String = City.DIM_POPULATION


## 左侧城市列表。deltas 为最近一次结算的 cityDeltas（可为空）。
static func build_list(world: WorldState, deltas: Dictionary = {}) -> Array:
	var out: Array = []
	for city_id in world.get_city_ids():
		var city: City = world.get_city(str(city_id))
		var tier: Dictionary = city.tier_progress()
		var slot: Dictionary = _city_delta(deltas, city.city_id)
		var population_milli: int = _dimension_milli(slot, City.DIM_POPULATION)
		out.append({
			"cityId": city.city_id,
			"displayName": city.display_name,
			"tierLabel": city.get_tier_label(),
			"tier": tier["tier"],
			"npcCount": city.npc_ids.size(),
			"populationDeltaText": format_signed(population_milli),
			"populationDeltaMilli": population_milli,
			"mostlyRising": _mostly_rising(slot),
			"progressRatio": float(tier["ratio"]),
			"downgradeRisk": bool(tier["downgradeRisk"]),
		})
	return out


## 单座城市的详情。deltas 为最近一次结算的 cityDeltas（可为空，
## 读档后尚未推进月份时就是空的，此时各行只显示数值与趋势）。
static func build_detail(
	world: WorldState, city_id: String, deltas: Dictionary = {}
) -> Dictionary:
	var city: City = world.get_city(city_id)
	if city == null:
		return {}

	var slot: Dictionary = _city_delta(deltas, city_id)
	var rows: Array = []
	for dimension in DIMENSION_ORDER:
		rows.append(_build_row(city, dimension, slot))

	var tier: Dictionary = city.tier_progress()
	var history: Dictionary = {}
	var trends: Dictionary = {}
	for dimension in DIMENSION_ORDER:
		var series: Array = world.get_history(city_id, dimension)
		history[dimension] = series
		trends[dimension] = series_stats(series)

	return {
		"cityId": city.city_id,
		"displayName": city.display_name,
		"tier": tier["tier"],
		"tierLabel": city.get_tier_label(),
		"tierProgress": tier,
		"tierNextText": tier_next_text(tier),
		"tierGapText": tier_gap_text(tier),
		"downgradeText": downgrade_text(tier),
		"rows": rows,
		"stats": _build_stats(world, city),
		"buildings": _build_buildings(world, city),
		"history": history,
		"trends": trends,
		"trendDimension": DEFAULT_TREND_DIMENSION,
		"historyMonths": world.get_history_length(city_id),
		"coords": {"x": city.coord_x, "y": city.coord_y},
	}


## 阶段推进的说明文字。返回空串表示已到顶。
static func tier_next_text(tier: Dictionary) -> String:
	if int(tier["nextTier"]) < 0:
		return "已是大城，无法再升"
	return "升为「%s」需同时满足：发展度 ≥ %d、人口 ≥ %d" % [
		str(tier["nextLabel"]), int(tier["needDevelopment"]), int(tier["needPopulation"])
	]


static func tier_gap_text(tier: Dictionary) -> String:
	if int(tier["nextTier"]) < 0:
		return ""
	return "当前差：发展度 %d、人口 %d——卡住的是%s" % [
		int(tier["gapDevelopment"]), int(tier["gapPopulation"]),
		str(tier.get("bindingLabel", "")),
	]


static func downgrade_text(tier: Dictionary) -> String:
	if not bool(tier.get("downgradeRisk", false)):
		return ""
	return "⚠ %s 已接近本阶段下限，再跌就要降级" % str(tier.get("bindingLabel", ""))


## 序列统计：趋势线的端点、极值与净变化。
static func series_stats(series: Array) -> Dictionary:
	if series.is_empty():
		return {
			"length": 0, "min": 0, "max": 0, "first": 0, "last": 0,
			"delta": 0, "deltaText": "0.00", "text": "尚无历史记录",
		}
	var low: int = int(series[0])
	var high: int = int(series[0])
	for value in series:
		var v: int = int(value)
		low = mini(low, v)
		high = maxi(high, v)
	var first: int = int(series[0])
	var last: int = int(series[series.size() - 1])
	var delta: int = last - first
	return {
		"length": series.size(),
		"min": low,
		"max": high,
		"first": first,
		"last": last,
		"delta": delta,
		"deltaText": ("+%d" % delta) if delta >= 0 else str(delta),
		"text": "近 %d 月：%d → %d（%s），区间 %d–%d" % [
			series.size(), first, last,
			("+%d" % delta) if delta >= 0 else str(delta), low, high,
		],
	}


## 千分之一单位转带符号的两位小数文本。负数不能走整数除法的截断，
## 否则 -450 会被算成 "-0.45" 之外的怪值（截断朝向零）。
static func format_signed(milli: int) -> String:
	var negative: bool = milli < 0
	var value: int = -milli if negative else milli
	@warning_ignore("integer_division")
	var whole: int = value / 1000
	@warning_ignore("integer_division")
	var hundredths: int = ((value % 1000) + 5) / 10
	if hundredths >= 100:
		whole += 1
		hundredths = 0
	# 四舍五入后归零的量不该显示成 "-0.00"：负号会让读者以为它在跌
	if whole == 0 and hundredths == 0:
		return "0.00"
	return "%s%d.%02d" % ["-" if negative else "+", whole, hundredths]


static func format_ratio(ratio: float) -> String:
	return "%d%%" % int(round(clampf(ratio, 0.0, 1.0) * 100.0))


# --- 内部 ---

static func _build_row(city: City, dimension: String, slot: Dictionary) -> Dictionary:
	var value: int = city.get_dimension(dimension)
	var milli: int = _dimension_milli(slot, dimension)
	var applied: int = _dimension_applied(slot, dimension)
	var carry: int = int(city.evolution_carry.get(dimension, 0))

	var items: Array = []
	for item in slot.get(dimension, {}).get("items", []):
		items.append({
			"label": str(item["label"]),
			"text": format_signed(int(item["milli"])),
			"milli": int(item["milli"]),
		})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absi(int(a["milli"])) > absi(int(b["milli"])))

	var carry_text: String = ""
	if carry != 0:
		# 余数说明为什么"贡献是正的、整数却没动"：不足一格的变化会攒到下月。
		carry_text = "余数 %s" % format_signed(carry)

	return {
		"key": dimension,
		"label": str(City.DIMENSION_LABELS.get(dimension, dimension)),
		"value": value,
		"bar": clampf(float(value) / 100.0, 0.0, 1.0),
		"deltaMilli": milli,
		"deltaText": format_signed(milli),
		"applied": applied,
		"carryMilli": carry,
		"carryText": carry_text,
		"items": items,
	}


static func _build_stats(world: WorldState, city: City) -> Array:
	var regular: int = world.get_routes_of_city(city.city_id, TradeRoute.KIND_REGULAR).size()
	var smuggling: int = world.get_routes_of_city(city.city_id, TradeRoute.KIND_SMUGGLING).size()
	var legendary: int = world.get_routes_of_city(city.city_id, TradeRoute.KIND_LEGENDARY).size()
	var named: int = 0
	for npc in world.get_city_npcs(city.city_id):
		if npc.is_named:
			named += 1
	var rows: Array = [
		{"label": "模拟居民", "value": "%d 人" % city.npc_ids.size()},
		{"label": "其中具名", "value": "%d 人" % named},
		{"label": "正规商路", "value": "%d 条" % regular},
		{"label": "走私航线", "value": "%d 条" % smuggling},
		{"label": "黑市渠道", "value": "有" if city.has_black_market else "无"},
	]
	# 传奇航线是事件给的稀罕物，没有就不占一行——每个城都写「传奇航线 0 条」
	# 会让这一行变成噪声，而它本来该是"我打出来的"那种提示。
	if legendary > 0:
		rows.append({"label": "传奇航线", "value": "%d 条" % legendary})
	# 未了结的城市事件同理：它是"这座城正在出事"的信号，没事就不该占一行。
	var active_events: int = world.active_event_count(city.city_id)
	if active_events > 0:
		rows.append({"label": "城中大事", "value": "%d 件未了" % active_events})
	return rows


static func _city_delta(deltas: Dictionary, city_id: String) -> Dictionary:
	return deltas.get(city_id, {})


static func _dimension_milli(slot: Dictionary, dimension: String) -> int:
	var entry: Dictionary = slot.get(dimension, {})
	return int(entry.get("milli", 0))


static func _dimension_applied(slot: Dictionary, dimension: String) -> int:
	var entry: Dictionary = slot.get(dimension, {})
	return int(entry.get("applied", 0))


## 六个维度里涨的比跌的多，就当作"向好"。列表上用它给一行做颜色倾向。
static func _mostly_rising(slot: Dictionary) -> bool:
	var up: int = 0
	var down: int = 0
	for dimension in DIMENSION_ORDER:
		var milli: int = _dimension_milli(slot, dimension)
		if milli > 0:
			up += 1
		elif milli < 0:
			down += 1
	return up >= down


## 详情栏的建筑列表（D-69~D-72）。每条给界面可画的字段，数值原样不带任何格式化
## 之外的加工。state 由可用等级判定（>0 运营、否则关闭）；投资交互是否可用由
## 存在门槛 + 未到上限 + 钱包够不够共同决定。
static func _build_buildings(world: WorldState, city: City) -> Array:
	var balance: Dictionary = ContentLoader.get_balance_section("buildings")
	var max_level: int = int(balance.get("maxLevel", 10))
	var avatar: PlayerAvatar = world.avatar
	var money: int = avatar.money if avatar != null else 0
	var out: Array = []
	for bid in ContentLoader.get_city_building_ids(city.city_id):
		var cfg: Dictionary = ContentLoader.get_building_config(bid)
		if cfg.is_empty():
			continue
		var avail: int = CityBuildings.available_level(cfg, city, balance)
		var invested: int = CityBuildings.invested_level(world, city.city_id, bid)
		var effective: int = CityBuildings.effective_level(cfg, city, invested, balance)
		var category_label: String = (
			"地标" if str(cfg.get("category", "")) == "landmark" else "功能"
		)
		var cost: int = 0
		var enabled: bool = false
		if avail > 0 and effective < max_level:
			cost = CityBuildings.invest_cost(balance, effective)
			enabled = money >= cost
		out.append({
			"buildingId": bid,
			"displayName": str(cfg.get("displayName", bid)),
			"categoryLabel": category_label,
			"function": str(cfg.get("function", "")),
			"level": effective,
			"availableLevel": avail,
			"investedLevel": invested,
			"state": "operational" if avail > 0 else "closed",
			"investCost": cost,
			"investEnabled": enabled,
			"money": money,
			"dimensionBonusText": _dimension_bonus_text(cfg),
			"presentationHint": str(cfg.get("presentationHint", "")),
		})
	return out


## 建筑的维度效果文案。dimensionBonus 为 {维度: 每级系数}，拼成"每级"口径。
static func _dimension_bonus_text(cfg: Dictionary) -> String:
	var bonus: Dictionary = cfg.get("dimensionBonus", {})
	if bonus.is_empty():
		return ""
	var parts: Array = []
	for dimension in bonus:
		parts.append("+%s %d/级" % [
			str(City.DIMENSION_LABELS.get(str(dimension), str(dimension))),
			int(bonus[dimension]),
		])
	var text: String = ""
	for i in range(parts.size()):
		if i > 0:
			text += "、"
		text += str(parts[i])
	return text
