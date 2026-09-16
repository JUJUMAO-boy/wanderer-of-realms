class_name HiddenEventViewModel
extends RefCounted

## 隐藏属性事件的视图模型（M17）。
##
## 隐藏事件不新增常驻面板——它复用 VIEW_EVENT 的抉择形态（D-90："复用既有抉择
## 面板形态，不新开 view"）。所以这里要做的事，是把一条隐藏事件 config 摊成
## EventPanel 能消费的那副样子：列表里一件活动中的事（行上方写着"命运在叩门"），
## 右列直接进抉择（MODE_BRANCH），把三种做法与各自后果摆开。
##
## 与 EventViewModel 同一条道理：后果预览与交付走同一个函数
## （HiddenAttributeSystem.outcome_preview），"选项上写着善恶 +10、落账却是 +20"
## 这种错误没有藏身处。

const ROW_KIND_ACTIVE: String = "active"
const ROW_KIND_FATEFUL: String = "active"

const MODE_BRANCH: int = 1


## config 是一条 hidden_events.json 里的事件。city_id 是这扇门的所在（声誉按城读，
## 善恶/幸运是全局）。avatar 只是拿来读当前隐藏属性以侧写出档位文案，不改它。
static func build(
	config: Dictionary, avatar: PlayerAvatar, city_id: String, city_names: Dictionary
) -> Dictionary:
	if config.is_empty():
		return {}
	var template_id: String = str(config.get("templateId", ""))
	var band: String = _band_of(config, avatar, city_id)
	var row: Dictionary = _row(config, city_id, city_names, band)
	var branches: Array = _branches(config)
	return {
		"cityId": city_id,
		"cityLabel": str(city_names.get(city_id, city_id)),
		"hereCityId": city_id,
		"atCity": true,
		"rows": [row],
		"rowCount": 1,
		"cursor": 0,
		"selected": row,
		"mode": MODE_BRANCH,
		"activeCount": 1,
		"branches": branches,
		"selectedIsActive": true,
		"templateId": template_id,
	}


## 列表行。一件"活动中的事"——只是这件的来由是一场命运的叩门，不是城市的变故。
static func _row(config: Dictionary, city_id: String, city_names: Dictionary,
		band: String) -> Dictionary:
	return {
		"kind": ROW_KIND_ACTIVE,
		"eventId": "",
		"templateId": str(config.get("templateId", "")),
		"title": str(config.get("displayName", "")),
		"scriptRef": str(config.get("scriptRef", config.get("templateId", ""))),
		"cityLabel": str(city_names.get(city_id, city_id)),
		"summary": str(config.get("summary", "")),
		"dialogue": config.get("dialogue", []),
		"reason": band,
		"effect": "这是命运叩门，不是城里的变故——你的选择会留在这一世的痕迹上。",
		"statusLabel": "未了",
		"enabled": true,
		"canResolve": true,
		"blockedReason": "",
		"outcomeLabel": "",
	}


## 抉择行。后果预览与交付同源（HiddenAttributeSystem.outcome_preview），所以
## 这里写出的效果就是落账会落出的效果。
static func _branches(config: Dictionary) -> Array:
	var out: Array = []
	for branch in config.get("branches", []):
		var preview: Dictionary = HiddenAttributeSystem.outcome_preview(branch)
		out.append({
			"branchId": str(branch.get("branchId", "")),
			"isCombat": false,
			"label": str(preview.get("label", "")),
			"detail": str(preview.get("detail", "")),
			"effectLabel": HiddenAttributeSystem.effect_label(preview),
			"enabled": true,
		})
	return out


## 侧写出玩家此刻站到哪一档，做行的"来由"文案。不把数值摆上常驻面板，但让触发
## 这件事的"被世界看着"的感觉从文字里透出来。
static func _band_of(config: Dictionary, avatar: PlayerAvatar, city_id: String) -> String:
	var kind: String = str(config.get("trigger", {}).get("attr", ""))
	match kind:
		"karma":
			var k: int = avatar.karma
			if k >= HiddenAttributeSystem.GOOD_THRESHOLD:
				return "你的灵魂带着光"
			if k <= HiddenAttributeSystem.EVIL_THRESHOLD:
				return "你浑身笼罩着不祥"
		"luck":
			var l: int = avatar.luck
			if l <= HiddenAttributeSystem.LUCK_THRESHOLD * -1:
				return "一股刻意般的霉运缠在身上"
			if l >= HiddenAttributeSystem.LUCK_THRESHOLD:
				return "吉星正悬在头顶"
		"reputation":
			var r: int = HiddenAttributeSystem.read_attr(avatar, "reputation", city_id)
			if r >= 80:
				return "这座城市记着你的名字"
	return "命运低语"