class_name EncounterViewModel
extends RefCounted

## 世界遭遇的视图模型（《技术设计文档》9.12 节，D-60）。纯函数：只算"该显示什么"，
## 不掷骰子、不改世界。
##
## 三个做法的成功率都在这里算好写进行上——玩家要的是"这一下大概几成"，
## 而不是选了才知道。算式本身在 EncounterSystem 里（那里可以被直接断言），
## 这里只是转调，不另写一份，免得界面上的数与判定用的数迟早对不上。
##
## 与委托、城中大事的版式分别：遭遇只有一件事，所以没有"列表 + 抉择"两个模式。
## 左列是对手（只看，不能点——仗还没打，挑不了先打谁），右列来龙去脉 + 三个做法。

const CONTEXT_LABELS: Dictionary = {
	EncounterSystem.CONTEXT_CITY: "城里",
	EncounterSystem.CONTEXT_ROAD: "商路上",
	EncounterSystem.CONTEXT_WILD: "荒野",
}

## 危险区的显示名，下标即档位。
const TIER_LABELS: Array = ["近郊", "远郊", "荒野深处"]

const CATEGORY_LABELS: Dictionary = {
	"beast": "野兽", "undead": "亡灵", "humanoid": "人形", "dragon": "龙类",
}


## 组装一屏遭遇。player_threat 由调用方给（它手上才有派生值）；
## 绕开与交涉的成功率转调 system，所以界面上的数与真正判定的数同源。
static func build(
	system: EncounterSystem,
	spec: Dictionary,
	player_threat: int,
	city_names: Dictionary,
	cursor: int = 0
) -> Dictionary:
	if spec.is_empty() or system == null:
		return {}
	var city_id: String = str(spec.get("nearestCityId", spec.get("cityId", "")))
	var city_label: String = str(city_names.get(city_id, city_id))
	var threat: int = int(spec.get("threatLevel", 0))
	var reputation: int = 0
	if system.world != null and system.world.avatar != null:
		reputation = system.world.avatar.get_reputation(city_id)

	var rows: Array = []
	for opponent in _array_of(spec.get("opponents", null)):
		rows.append(_opponent_row(opponent))
	var choices: Array = _choices(system, spec, reputation)
	var index: int = clampi(cursor, 0, maxi(0, choices.size() - 1))
	var gap: int = threat - player_threat
	return {
		"encounterId": str(spec.get("encounterId", "")),
		"context": str(spec.get("context", "")),
		"contextLabel": str(CONTEXT_LABELS.get(str(spec.get("context", "")), "")),
		"cityId": city_id,
		"cityLabel": city_label,
		"pos": spec.get("pos", [0, 0]),
		"tier": int(spec.get("tier", 0)),
		"tierLabel": _tier_label(int(spec.get("tier", 0))),
		"title": str(spec.get("title", "")),
		"story": str(spec.get("story", "")),
		"threatLevel": threat,
		"playerThreat": player_threat,
		"levelGap": gap,
		"dangerLabel": _danger_label(gap),
		"outmatched": gap > _level_gap_threshold(),
		"rows": rows,
		"rowCount": rows.size(),
		"choices": choices,
		"choiceCount": choices.size(),
		"cursor": index,
		"selected": choices[index] if not choices.is_empty() else {},
		"reputation": reputation,
		"reputationLabel": _reputation_label(reputation),
		"parleyable": bool(spec.get("parleyable", false)),
	}


## 对手行。只看不点：仗还没打，挑不了先打谁。
static func _opponent_row(opponent: Dictionary) -> Dictionary:
	var threat: int = int(opponent.get("threatLevel", 0))
	var hp: int = int(opponent.get("hp", 0))
	var category: String = str(opponent.get("category", ""))
	return {
		"unitId": str(opponent.get("unitId", "")),
		"name": str(opponent.get("name", "")),
		"isNpc": bool(opponent.get("isNpc", false)),
		"npcId": str(opponent.get("npcId", "")),
		"category": category,
		"categoryLabel": str(CATEGORY_LABELS.get(category, "")),
		"threatLevel": threat,
		"hp": hp,
		"maxHp": hp,
		"threatLabel": "TL %d" % threat,
		"hpLabel": "%d 血" % hp,
	}


## 三个做法。顺序是行动顺序：迎战在最上——最直接的那条路不该排在人后面。
static func _choices(system: EncounterSystem, spec: Dictionary, reputation: int) -> Array:
	var threat: int = int(spec.get("threatLevel", 0))
	var count: int = _array_of(spec.get("opponents", null)).size()
	var out: Array = [
		{
			"choiceId": EncounterSystem.CHOICE_FIGHT,
			"label": "迎战",
			"detail": "打一场。多数战斗是被打倒而不是被打死，倒下之后怎么办由你说了算。",
			"effectLabel": "%d 个对手，最高 TL %d" % [count, threat],
			"enabled": true,
			"blockedReason": "",
		},
		{
			"choiceId": EncounterSystem.CHOICE_AVOID,
			"label": "绕开",
			"detail": "换条路走，花 %d 天。甩不掉就只能打。" % system.avoid_time_days(),
			"effectLabel": "成功率 %d%%" % _percent(_avoid_chance_bp(system)),
			"enabled": true,
			"blockedReason": "",
		},
	]
	if bool(spec.get("parleyable", false)):
		out.append({
			"choiceId": EncounterSystem.CHOICE_PARLEY,
			"label": "交涉",
			"detail": "亮出你在这座城的名声。%s" % _reputation_note(reputation),
			"effectLabel": "成功率 %d%%" % _percent(system.parley_chance_bp(reputation)),
			"enabled": true,
			"blockedReason": "",
		})
	else:
		out.append({
			"choiceId": EncounterSystem.CHOICE_PARLEY,
			"label": "交涉",
			"detail": "说不动的东西没有交涉可言。",
			"effectLabel": "",
			"enabled": false,
			"blockedReason": str(spec.get("parleyBlockReason", "它们不跟你讲道理")),
		})
	return out


## 绕开成功率：拿玩家自己的敏捷与幸运去问系统要（算式在那边只有一份）。
static func _avoid_chance_bp(system: EncounterSystem) -> int:
	if system.world == null or system.world.avatar == null:
		return 0
	return system.avoid_chance_bp(system.world.avatar.attributes, system.world.avatar.luck)


## 危险等级的一句话。越级那一档单独标出来——13.2 节的惩罚会实打实地扣命中与伤害，
## 玩家必须在按下"迎战"之前知道这件事。
static func _danger_label(gap: int) -> String:
	var threshold: int = _level_gap_threshold()
	if gap > threshold:
		return "比你强出一大截"
	if gap > 0:
		return "比你强一些"
	if gap == 0:
		return "与你势均力敌"
	return "不如你"


static func _level_gap_threshold() -> int:
	return int(ContentLoader.get_balance_section("combat").get("levelGapThreshold", 5))


static func _tier_label(tier: int) -> String:
	var label: String = str(TIER_LABELS[clampi(tier, 0, TIER_LABELS.size() - 1)])
	return "%s（第 %d 档）" % [label, tier + 1]


static func _reputation_label(reputation: int) -> String:
	if reputation >= 60:
		return "敬重 %d" % reputation
	if reputation <= -60:
		return "敌视 %d" % reputation
	if reputation <= -20:
		return "警惕 %d" % reputation
	return "无名 %d" % reputation


static func _reputation_note(reputation: int) -> String:
	if reputation >= 60:
		return "这座城市敬重你，路会让开。"
	if reputation <= -60:
		return "这座城市敌视你，没什么可谈的。"
	return "名声在这条路上兑得有限。"


static func _percent(bp: int) -> int:
	return int(round(float(bp) / 100.0))


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []
