class_name CityEvent
extends RefCounted

## 城市事件实例（技术设计文档 3.2 节 EVENT_INSTANCE）。
##
## 存档只记**实例状态**，不复制剧本文本：分支后果与关键对白都在 events.json 里，
## 按 templateId 现查（3.2 节原文）。
##
## 但**持续效果要冻结**：封港是否中断航线、每月扣多少，是这场事件在跑的时候依赖
## 的东西，内容表改了不该让一场进行中的事件中途换规则。这与 QUEST 的
## rewardSnapshot「生成时冻结」是同一条理由（3.2 节）。

## 封锁中：城市在流血，等玩家介入。
const PHASE_BLOCKADE: int = 1
## 已了结。
const PHASE_DONE: int = 2

var event_id: String = ""
var template_id: String = ""
var city_id: String = ""
var phase: int = PHASE_BLOCKADE
var triggered_month: int = 0
## 参与 NPC（3.2 节字段）。EV-02 的三个相关方（行会、银鳞、利维坦）都没有对应的
## 模拟 NPC，所以 MVP 里这个字段恒为空——字段留着，等具名 NPC 进来再填。
var participant_npc_ids: Array = []
var resolved: bool = false
var resolved_month: int = 0
## 玩家最后选的做法。打输了的战斗也会写进来（那次没有结束事件）。
var branch_id: String = ""

## 冻结的持续效果
var halt_routes: bool = false
## {dimension, delta}，每月结算扣一次；空字典表示没有持续代价
var drain: Dictionary = {}


static func make(
	p_event_id: String, p_template_id: String, p_city_id: String,
	p_triggered_month: int, p_halt_routes: bool, p_drain: Dictionary
) -> CityEvent:
	var instance := CityEvent.new()
	instance.event_id = p_event_id
	instance.template_id = p_template_id
	instance.city_id = p_city_id
	instance.triggered_month = p_triggered_month
	instance.halt_routes = p_halt_routes
	instance.drain = p_drain.duplicate(true)
	return instance


func is_active() -> bool:
	return not resolved


## 这场事件有没有每月持续代价。封港有（港口不通，城一直在流血），有些事件没有。
func has_drain() -> bool:
	return not drain.is_empty()


func to_dict() -> Dictionary:
	return {
		"eventId": event_id,
		"templateId": template_id,
		"cityId": city_id,
		"phase": phase,
		"triggeredMonth": triggered_month,
		"participantNpcIds": participant_npc_ids.duplicate(),
		"resolved": resolved,
		"resolvedMonth": resolved_month,
		"branchId": branch_id,
		"haltRoutes": halt_routes,
		"drain": drain.duplicate(true),
	}


static func from_dict(data: Dictionary) -> CityEvent:
	var instance := CityEvent.new()
	instance.event_id = str(data.get("eventId", ""))
	instance.template_id = str(data.get("templateId", ""))
	instance.city_id = str(data.get("cityId", ""))
	instance.phase = int(data.get("phase", PHASE_BLOCKADE))
	instance.triggered_month = int(data.get("triggeredMonth", 0))
	instance.participant_npc_ids = data.get("participantNpcIds", []).duplicate()
	instance.resolved = bool(data.get("resolved", false))
	instance.resolved_month = int(data.get("resolvedMonth", 0))
	instance.branch_id = str(data.get("branchId", ""))
	instance.halt_routes = bool(data.get("haltRoutes", false))
	instance.drain = data.get("drain", {}).duplicate(true)
	return instance
