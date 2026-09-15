class_name SmugglingViewModel
extends RefCounted

## 走私航线界面的视图模型。
##
## 一屏一行事：**在这座城建立走私航线**、以及**撤销自己已经建的**。两类合成一个
## 列表而不是分两栏，是因为它们共用同一个动作（回车执行光标所在那一行）；分栏
## 就要再引入"当前在哪一栏"的状态，而玩家要的只是"对这一行按回车"。
##
## 每行自带说明：可建的写距离与查抄概率，不可建的写为什么不行。理由来自
## WorldSim.smuggling_check，界面不自己再判一次规则——两份规则迟早会不一致。

const ROW_KIND_BUILD: String = "build"
const ROW_KIND_CANCEL: String = "cancel"
const ROW_KIND_BLOCKED: String = "blocked"


## world 只读，用来取城市与治安。
## options 来自 WorldSim.smuggling_options（带 ok / reason / distance），
## owned 来自 WorldSim.player_smuggling_routes（TradeRoute 数组）。
## rules 是界面上要摆出来的那几个配置值，一次传进来而不是摊成五个位置参数：
##   {confiscationPermille, incomePerRoute, reputationLoss, karmaLoss, maxPerCity}
static func build(
	world: WorldState,
	options: Array,
	owned: Array,
	city_id: String,
	city_names: Dictionary,
	cursor: int,
	rules: Dictionary
) -> Dictionary:
	var city: City = world.get_city(city_id)
	if city == null:
		return {}
	var here: String = _city_label(city_names, city_id)
	var confiscation_permille: int = int(rules.get("confiscationPermille", 200))
	var income_per_route: int = int(rules.get("incomePerRoute", 0))
	var rows: Array = []

	# 己方航线排在前面：那是玩家最关心的，也是唯一撤得掉的
	for route in owned:
		var other_id: String = str(route.other_city(city_id))
		rows.append({
			"kind": ROW_KIND_CANCEL,
			"key": str(route.route_id),
			"cityId": other_id,
			"label": "%s ↔ %s" % [here, _city_label(city_names, other_id)],
			"detail": "你建的 · 月入 %s · 查抄 %d%%/月 · 回车撤销" % [
				AvatarViewModel.money_label(income_per_route),
				_confiscation_percent(world.get_city(other_id), confiscation_permille),
			],
			"actionLabel": "撤销",
			"enabled": true,
		})

	for option in options:
		var other_id: String = str(option["cityId"])
		var ok: bool = bool(option.get("ok", false))
		var detail: String = str(option.get("reason", "不可建立"))
		if ok:
			detail = "距离 %d · 查抄 %d%%/月 · 回车建立" % [
				int(option.get("distance", 0)),
				_confiscation_percent(world.get_city(other_id), confiscation_permille),
			]
		rows.append({
			"kind": ROW_KIND_BUILD if ok else ROW_KIND_BLOCKED,
			"key": "%s__%s" % [city_id, other_id],
			"cityId": other_id,
			"label": "%s ↔ %s" % [here, _city_label(city_names, other_id)],
			"detail": detail,
			"actionLabel": "建立" if ok else "不可建",
			"enabled": ok,
		})

	return {
		"cityId": city_id,
		"cityLabel": here,
		"rows": rows,
		"rowCount": rows.size(),
		"cursor": clampi(cursor, 0, maxi(0, rows.size() - 1)),
		"ownedCount": owned.size(),
		"ownedIncome": owned.size() * income_per_route,
		"incomePerRoute": income_per_route,
		"cityConfiscationPercent": _confiscation_percent(city, confiscation_permille),
		"citySecurity": city.security,
		"hasBlackMarket": city.has_black_market,
		"reputationLoss": int(rules.get("reputationLoss", 0)),
		"karmaLoss": int(rules.get("karmaLoss", 0)),
		"maxPerCity": int(rules.get("maxPerCity", 0)),
	}


## 某座城的走私查抄概率（百分比整数）。查抄概率 = 治安/100 × 系数（9.4 节）；
## 界面把它摆出来是因为"能不能建"之外，玩家还得能比较哪条更划算。
static func _confiscation_percent(city: City, permille: int) -> int:
	if city == null:
		return 0
	return int(round(float(city.security) * float(permille) / 1000.0))


static func _city_label(city_names: Dictionary, city_id: String) -> String:
	return str(city_names.get(city_id, city_id))
