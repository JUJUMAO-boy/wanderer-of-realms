class_name TrainingGate
extends RefCounted

## 训练师双币种规则层（M-B 剩余，9.31 节 D-135）。
##
## 训练不像普通买卖那样只花铜币：还从灵魂里刨下一丝业力（karma 递减，"透支"）。
## 这份代价不落盘新字段——karma 本就是 PlayerAvatar 上跨世保留的隐藏属性，训练往
## 负方向推它，转世后善因还在账上，神恩（M25 GodBlessing 由 karma 派生虔诚）随之变。
##
## 只做"报价/付款"两件事，全部静态函数、无 IO、可无头断言：quote 只读、pay 落账。
## balance.json 的 training 段给数值：copper（每次学费）、karmaCost（每次业力扣减）、
## skillGain（胜利给的熟练度溢价——见 main._grant_sparring_reward，这里不负责发放）。

const ERROR_NONE: String = ""
const ERROR_POOR: String = "POOR"
const ERROR_KARMA_EXHAUSTED: String = "KARMA_EXHAUSTED"
const _SECTION: String = "training"


static func _rate(world: WorldState) -> Dictionary:
	var balance: Dictionary = ContentLoader.get_balance_section(_SECTION)
	return {
		"copper": int(balance.get("copper", 0)),
		"karmaCost": int(balance.get("karmaCost", 0)),
		"skillGain": int(balance.get("skillGain", 0)),
	}


## 问价：钱够扣、业力也够扣才能受训。返回 {ok, copper, karmaCost, skillGain, reason}。
## 不改变任何状态——先问价、过关再 pay，需求侧照旧。
static func quote(world: WorldState) -> Dictionary:
	var rate: Dictionary = _rate(world)
	var copper: int = int(rate["copper"])
	var karma_cost: int = int(rate["karmaCost"])
	var reason: String = ERROR_NONE
	if world == null or world.avatar == null:
		reason = "还没站到教练面前。"
	elif world.avatar.money < copper:
		reason = "你身上的铜币不够这场的学费。"
	elif world.avatar.karma - karma_cost < PlayerAvatar.HIDDEN_ATTR_MIN:
		reason = "你的业力已经薄得撑不起再透支一次了。"
	return {
		"ok": reason == ERROR_NONE,
		"copper": copper,
		"karmaCost": karma_cost,
		"skillGain": int(rate["skillGain"]),
		"reason": reason,
	}


## 付款：扣学费与业力。失败不落任何账（先复查 quote，防止调用方忘了先问）。
## 成功返回 {ok, copper, karmaCost}，被扣的数值带回，供文案引用。
static func pay(world: WorldState) -> Dictionary:
	var ask: Dictionary = quote(world)
	if not bool(ask.get("ok", false)):
		return {"ok": false, "reason": str(ask.get("reason", ""))}
	var copper: int = int(ask["copper"])
	var karma_cost: int = int(ask["karmaCost"])
	var avatar: PlayerAvatar = world.avatar
	avatar.money -= copper
	avatar.set_karma(avatar.karma - karma_cost)
	return {"ok": true, "copper": copper, "karmaCost": karma_cost}