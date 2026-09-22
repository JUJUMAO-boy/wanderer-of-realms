class_name PrayerViewModel
extends RefCounted

## 祈祷的视图模型（M25/M-A）。
##
## 祈祷不新增常驻面板——复用 VIEW_EVENT 的抉择形态（D-90："复用既有抉择面板
## 形态，不新开 view"）。所以这里要做的事，是把神系配置摊成 EventPanel 能消费的
## 那副样子：列表里一行"向诸神祈祷"，右列直接进抉择（MODE_BRANCH），把四位神
## 与各自此刻的回应摆开。
##
## 后果预览与交付走同一个函数（GodBlessing.pray_result），"选项上写着得赐恩惠、
## 结算却是神罚" 这种错没有藏身处——行里就是结算本身。

const MODE_BRANCH: int = 1

## gods 是 gods.json 的数组，karma 为当前善恶（读虔诚用），city_names 只管给
## 面板一个合理的城市题头（祈祷不挑城，城市名只做展示）。
static func build(gods: Array, karma: int, city_names: Dictionary) -> Dictionary:
	var branches: Array = []
	for god in gods:
		if not (god is Dictionary):
			continue
		var result: Dictionary = GodBlessing.pray_result(
			(god as Dictionary), karma, 0
		)
		branches.append(_branch(god as Dictionary, result))
	if branches.is_empty():
		return {}
	return {
		"cityId": "",
		"cityLabel": "诸神",
		"hereCityId": "",
		"atCity": true,
		"rows": [_row(city_names)],
		"rowCount": 1,
		"cursor": 0,
		"selected": _row(city_names),
		"mode": MODE_BRANCH,
		"activeCount": 1,
		"branches": branches,
		"selectedIsActive": true,
	}


## 列表行：一件事——"向诸神祈祷"。
static func _row(city_names: Dictionary) -> Dictionary:
	return {
		"kind": "active",
		"eventId": "",
		"templateId": "prayer",
		"title": "向诸神祈祷",
		"scriptRef": "prayer",
		"cityLabel": "诸神",
		"summary": "跪下向诸神求一字回音：选谁，听谁的。",
		"dialogue": [],
		"reason": "你的善恶替你说着话",
		"effect": "恩惠与神罚都当场结清，神不落存档。",
		"statusLabel": "未了",
		"enabled": true,
		"canResolve": true,
		"blockedReason": "",
		"outcomeLabel": "",
	}


## 抉择行 = 一位神。预览与交付同源（pray_result），把此刻的回应摊在行上。
static func _branch(god: Dictionary, result: Dictionary) -> Dictionary:
	var cursed: bool = bool(result.get("cursed", false))
	var ok: bool = bool(result.get("ok", false))
	var essence: String
	if cursed:
		essence = "神罚：%s" % str(result.get("penalty", ""))
	elif ok:
		essence = str(result.get("effect", ""))
	else:
		essence = "神未垂听（%s）" % str(result.get("cost", ""))
	return {
		"branchId": str(god.get("id", "")),
		"godId": str(god.get("id", "")),
		"isCombat": false,
		"label": "%s · %s" % [str(god.get("name", "")), str(god.get("title", ""))],
		"detail": essence,
		"effectLabel": "规则扇·%s" % str(god.get("domain", "")),
		"enabled": true,
	}