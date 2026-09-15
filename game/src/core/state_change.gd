class_name StateChange
extends RefCounted

## 城市状态变更请求（技术设计文档 10.3 节）。
##
## 这是城市六维的**唯一外部写入载体**：任务、事件、玩家的所有影响都先变成
## 一条 StateChange，交给 WorldSim.applyStateChange，再由月度结算统一落账。
## 没有任何模块能绕过它直接改城市数值。
##
## changeId 是幂等键。同一 changeId 重复提交只落账一次——读档重试、脚本异常
## 或玩家重复交付都会产生重复提交，而重复加算在数值上表现得极其隐蔽
## （城市凭空多涨了一截，且无从追溯是哪一次造成的）。

const SOURCE_QUEST: String = "quest"
const SOURCE_EVENT: String = "event"
const SOURCE_PLAYER: String = "player"
const SOURCE_DECAY: String = "decay"

const ALL_SOURCES: Array = [SOURCE_QUEST, SOURCE_EVENT, SOURCE_PLAYER, SOURCE_DECAY]

var change_id: String = ""
var city_id: String = ""
var dimension: String = ""
var delta: int = 0
var source: String = SOURCE_QUEST
var source_ref_id: String = ""
var submitted_at_month: int = 0


static func make(
	p_change_id: String,
	p_city_id: String,
	p_dimension: String,
	p_delta: int,
	p_source: String,
	p_source_ref_id: String,
	p_submitted_at_month: int
) -> StateChange:
	var c := StateChange.new()
	c.change_id = p_change_id
	c.city_id = p_city_id
	c.dimension = p_dimension
	c.delta = p_delta
	c.source = p_source
	c.source_ref_id = p_source_ref_id
	c.submitted_at_month = p_submitted_at_month
	return c


## 校验字段约束。通过返回空串，否则返回可直接展示给调用方的错误说明。
func validate() -> String:
	if change_id.is_empty():
		return "缺少 changeId（幂等键不能为空）"
	if city_id.is_empty():
		return "缺少 cityId"
	if not City.ALL_DIMENSIONS.has(dimension):
		return "未知维度：%s" % dimension
	if delta == 0:
		return "delta 不能为 0（零变更不应提交）"
	if not ALL_SOURCES.has(source):
		return "未知变更来源：%s" % source
	if source_ref_id.is_empty():
		return "缺少 sourceRefId（无法追溯变更来源）"
	if submitted_at_month < 0:
		return "submittedAtMonth 不能为负：%d" % submitted_at_month
	return ""


## 载荷指纹。同一个 changeId 携带不同载荷意味着调用方复用了幂等键，
## 这是真冲突（CONFLICT），与「同一变更被重复提交」（幂等，静默忽略）不同。
func signature() -> String:
	return "%s|%s|%s|%d|%s|%s" % [
		change_id, city_id, dimension, delta, source, source_ref_id
	]


func to_dict() -> Dictionary:
	return {
		"changeId": change_id,
		"cityId": city_id,
		"dimension": dimension,
		"delta": delta,
		"source": source,
		"sourceRefId": source_ref_id,
		"submittedAtMonth": submitted_at_month,
	}


static func from_dict(data: Dictionary) -> StateChange:
	return StateChange.make(
		str(data.get("changeId", "")),
		str(data.get("cityId", "")),
		str(data.get("dimension", "")),
		int(data.get("delta", 0)),
		str(data.get("source", SOURCE_QUEST)),
		str(data.get("sourceRefId", "")),
		int(data.get("submittedAtMonth", 0))
	)
