class_name Quest
extends RefCounted

## 委托任务实体（技术设计文档 3.2 节 QUEST 的字段）。
##
## 只有**玩家接下的**委托会进世界状态：委托板是城市六维与世界标记的纯函数
## （见 QuestBoard），落盘反而需要额外同步"任务随城市状态出现或消失"这件事。
##
## reward 是生成时冻结的报酬快照。3.2 节要求"生成时确定并冻结，而非完成时再算"，
## 理由是完成时重算会让同样的任务报酬随世界状态漂移，玩家无法预期。分支只在这个
## 冻结值上乘修正系数（QuestSystem.complete），所以报酬不会因为世界变了而变。

const STATE_ACTIVE: String = "active"
const STATE_DONE: String = "done"
const STATE_EXPIRED: String = "expired"

var quest_id: String = ""
## 剧本身份（QT-01…），与「哪一类委托」分开：同一份剧本可以出三档委托
var template_id: String = ""
var quest_type: String = ""
var city_id: String = ""
## 委托人。MVP 不绑定具体 NPC——6 类委托的委托人都是行会/守卫队这类机构
## （《委托任务剧本》每篇的"关联"），绑定到某个模拟 NPC 反而会让同一个
## 行会在不同城市由不同人发布，与剧本不符。字段留着，等个人委托进来再填。
var giver_label: String = ""
var giver_npc_id: String = ""
var state: String = STATE_ACTIVE
var tier_id: String = ""
var reward: Dictionary = {}
var accepted_month: int = 0
var deadline_month: int = 0

## 报酬快照的字段。stateGain 是城市六维的增量（按档位取自 10.1 表），
## 其余三项是玩家的即时收益（10.3 表）。
const REWARD_MONEY: String = "moneyCopper"
const REWARD_REPUTATION: String = "reputationGain"
const REWARD_KARMA: String = "karmaGain"
const REWARD_STATE_GAIN: String = "stateGain"
const REWARD_DIMENSION: String = "dimension"


static func make(
	p_quest_id: String, p_template_id: String, p_quest_type: String, p_city_id: String,
	p_giver_label: String, p_tier_id: String, p_reward: Dictionary,
	p_accepted_month: int, p_deadline_month: int
) -> Quest:
	var q := Quest.new()
	q.quest_id = p_quest_id
	q.template_id = p_template_id
	q.quest_type = p_quest_type
	q.city_id = p_city_id
	q.giver_label = p_giver_label
	q.tier_id = p_tier_id
	q.reward = p_reward.duplicate(true)
	q.accepted_month = p_accepted_month
	q.deadline_month = p_deadline_month
	return q


func is_active() -> bool:
	return state == STATE_ACTIVE


func money_copper() -> int:
	return int(reward.get(REWARD_MONEY, 0))


func reputation_gain() -> int:
	return int(reward.get(REWARD_REPUTATION, 0))


func karma_gain() -> int:
	return int(reward.get(REWARD_KARMA, 0))


func state_gain() -> int:
	return int(reward.get(REWARD_STATE_GAIN, 0))


func dimension() -> String:
	return str(reward.get(REWARD_DIMENSION, ""))


## 过期判定。deadline 落在第 N 月，表示第 N 月的月末结算时仍未交付即失效。
func is_overdue(month: int) -> bool:
	return deadline_month > 0 and month > deadline_month


func to_dict() -> Dictionary:
	return {
		"questId": quest_id,
		"templateId": template_id,
		"questType": quest_type,
		"cityId": city_id,
		"giverLabel": giver_label,
		"giverNpcId": giver_npc_id,
		"state": state,
		"tierId": tier_id,
		"reward": reward.duplicate(true),
		"acceptedMonth": accepted_month,
		"deadlineMonth": deadline_month,
	}


static func from_dict(data: Dictionary) -> Quest:
	var q := Quest.new()
	q.quest_id = str(data.get("questId", ""))
	q.template_id = str(data.get("templateId", ""))
	q.quest_type = str(data.get("questType", ""))
	q.city_id = str(data.get("cityId", ""))
	q.giver_label = str(data.get("giverLabel", ""))
	q.giver_npc_id = str(data.get("giverNpcId", ""))
	q.state = str(data.get("state", STATE_ACTIVE))
	q.tier_id = str(data.get("tierId", ""))
	q.reward = data.get("reward", {}).duplicate(true)
	q.accepted_month = int(data.get("acceptedMonth", 0))
	q.deadline_month = int(data.get("deadlineMonth", 0))
	return q
