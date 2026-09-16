class_name NpcInteractionViewModel
extends RefCounted

## NPC 居民视图的视图模型（M18 表现层）。与其它视图模型同一个理由："面板该显示
## 什么"是纯函数，能在无头环境里被验收测试钉住；"怎么画"留给面板。
##
## 它把规则层 NpcInteractionSystem 的 `resident_card` 排成一根可导航的纵向名单，
## 并附上对当前选中居民"此刻能不能聊 / 送 / 雇"的判断与可用物品候选。所有文案
## 照既有风格：一行为一个人，选中高亮，底部动作按可用性置灰。

## 底部动作的游标态（界面用一根光标在动作行间走）。
const ACTION_TALK_AMBITION: String = "talk_ambition"
const ACTION_TALK_RUMOR: String = "talk_rumor"
const ACTION_TALK_FAITH: String = "talk_faith"
const ACTION_GIFT: String = "gift"
const ACTION_HIRE: String = "hire"

const ACTIONS: Array = [
	{"id": ACTION_TALK_AMBITION, "label": "交谈·志向"},
	{"id": ACTION_TALK_RUMOR, "label": "交谈·传闻"},
	{"id": ACTION_TALK_FAITH, "label": "交谈·信仰"},
	{"id": ACTION_GIFT, "label": "送礼"},
	{"id": ACTION_HIRE, "label": "雇佣"},
]

## 名单 + 详情 + 动作三态一次成型。rules 是 NpcInteractionSystem，city_id 决定名单，
## resident_cursor 指到第几位居民，action_cursor 指到底部第几个动作（-1=未选中动作）。
static func build(rules, avatar, world, city_id: String,
		resident_cursor: int = 0, action_cursor: int = -1) -> Dictionary:
	var rows: Array = []
	if world != null:
		for card in rules.list_residents(world, avatar, city_id):
			rows.append(card)
	resident_cursor = clampi(resident_cursor, 0, maxi(0, rows.size() - 1))
	var selected: Dictionary = rows[resident_cursor] if not rows.is_empty() else {}
	for i in range(rows.size()):
		rows[i]["selected"] = (i == resident_cursor)

	# 动作行：谁能做、为什么不能
	var actions: Array = []
	var selected_hireable: bool = bool(selected.get("hireable", false))
	for action in ACTIONS:
		var id: String = str(action["id"])
		var can: bool = true
		var reason: String = ""
		if id == ACTION_HIRE:
			can = selected_hireable and int(selected.get("affinity", 0)) >= rules.hire_min_affinity()
			if not can:
				reason = _hire_reason(selected, rules)
		if id == ACTION_GIFT and selected.is_empty():
			can = false
			reason = "没有选中居民"
		if id.begins_with("talk_") and selected.is_empty():
			can = false
			reason = "没有选中居民"
		actions.append({"id": id, "label": str(action["label"]), "can": can, "reason": reason})
	action_cursor = clampi(action_cursor, -1, actions.size() - 1)
	for i in range(actions.size()):
		actions[i]["selected"] = (i == action_cursor)

	return {
		"rows": rows,
		"selected": selected,
		"hasSelected": not selected.is_empty(),
		"residentCursor": resident_cursor,
		"actions": actions,
		"actionCursor": action_cursor,
		"currentHire": rules.current_hire(world),
		"hireMinAffinity": rules.hire_min_affinity(),
	}


static func _hire_reason(selected: Dictionary, rules) -> String:
	if selected.is_empty():
		return "没有选中居民"
	if not bool(selected.get("hireable", false)):
		return "这位居民不愿受雇"
	if int(selected.get("affinity", 0)) < rules.hire_min_affinity():
		return "好感还不够雇"
	return ""