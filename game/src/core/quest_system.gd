class_name QuestSystem
extends RefCounted

## 委托模块（接口 I-15 ~ I-18）。
##
## 职责边界：生成（QuestBoard 是纯函数，这里只做转发与校验）、接受、交付、
## 放弃。**不自己写城市六维**——交付时把变更请求交给 WorldSim.applyStateChange，
## 由它在月末落账（10.4 节的"月中不变"）。本类因此不引用 WorldSim，依赖方向
## 保持单向：WorldSim → QuestSystem。
##
## 交付的后果分三层，这也是 M4.2 与 M4.3 的全部内容：
##   1. 即时：玩家的钱、声誉、善恶（玩家自己的账，不等月末）
##   2. 月末：该城对应维度的增量（StateChange，10.1 表 × 分支修正）
##   3. 往后：世界标记 + 延迟后果（分支里的"数月后塌方"这一类）

## 与 WorldSim 同名常量取同一个字符串：错误码是跨模块契约，界面拿它做分支。
const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"
const ERROR_CAPACITY_EXCEEDED: String = "CAPACITY_EXCEEDED"

## 世界标记的前缀。写成 quest.<城市>.<委托类型>.<后果>——带上城市是因为同一类
## 委托在八座城各办各的，标记若不带城，"在艾德兰办砸的修缮"会让索恩港的修缮
## 委托也变多。
const FLAG_PREFIX: String = "quest."

## 战斗交付的分支前缀：completion 时传 "combat:release" 表示"战场上选择放走"。
## 战斗的四种倒地处理（M5.4）与"打输了"分别对应配置里的一个结局。
const COMBAT_PREFIX: String = "combat:"

var world: WorldState = null
var _rules: Dictionary = {}


static func create(p_world: WorldState) -> QuestSystem:
	var system := QuestSystem.new()
	system.world = p_world
	system._rules = ContentLoader.get_balance_section("quests")
	return system


## balance 的 quests 段。界面要摆出上限一类的东西时从这里取，
## 不必各自去 ContentLoader 里翻。
func rules() -> Dictionary:
	return _rules


# --- I-15 列出某城可接任务 ---

## 委托板（M4.1）。这一份不落盘，每次打开都按当前城市状态重新推导。
func list_available(city_id: String, month: int) -> Array:
	return QuestBoard.offers(world, city_id, month, _rules)


# --- I-16 接受 ---

## 接下板上的一张委托。按 questId 在全部城市的板子上找——界面手上就有 Quest 对象，
## 但按 id 找能让"读档后重放同一次点击"也走同一条路。
func accept(quest_id: String, month: int) -> Dictionary:
	if world.find_quest(quest_id) != null:
		return _fail(ERROR_PRECONDITION_FAILED, "这张委托已经在你手上了")
	var cap: int = int(_rules.get("maxAccepted", 3))
	if world.active_quest_count() >= cap:
		return _fail(ERROR_CAPACITY_EXCEEDED, "手上的委托已经到 %d 张，先办掉几张" % cap)
	var offer: Quest = _find_offer(quest_id, month)
	if offer == null:
		return _fail(ERROR_NOT_FOUND, "板上已经没有这张委托了：%s" % quest_id)
	world.add_quest(offer)
	return {
		"ok": true,
		"questId": offer.quest_id,
		"cityId": offer.city_id,
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 在全部城市的当前板面上找一张委托。
func _find_offer(quest_id: String, month: int) -> Quest:
	for city_id in world.get_city_ids():
		for offer in QuestBoard.offers(world, str(city_id), month, _rules):
			if offer.quest_id == quest_id:
				return offer
	return null


# --- I-17 交付 ---

## 交付一张委托，按 branch_id 选定后果。返回给界面用的明细。
##
## 分支产物在这里一次性算清：城市增量、玩家收益、世界标记、延迟后果。
## 界面上"选哪一项"与"选了之后世界怎么变"因此只有一处对应关系。
func complete(quest_id: String, branch_id: String, month: int) -> Dictionary:
	var quest: Quest = world.find_quest(quest_id)
	if quest == null:
		return _fail(ERROR_NOT_FOUND, "没有这张委托：%s" % quest_id)
	if not quest.is_active():
		return _fail(ERROR_PRECONDITION_FAILED, "这张委托已经了结了")
	if resolve_outcome(quest.quest_type, branch_id).is_empty():
		return _fail(ERROR_INVALID_ARGUMENT, "%s 没有这个选项：%s" % [
			quest_type_label(quest.quest_type), branch_id
		])
	if world.get_city(quest.city_id) == null:
		return _fail(ERROR_NOT_FOUND, "委托所在的城市不存在：%s" % quest.city_id)

	var amplify: float = reputation_multiplier(world, quest.city_id, _rules)
	var preview: Dictionary = outcome_preview(quest, branch_id, amplify)
	var state_delta: int = int(preview["stateDelta"])
	var money: int = int(preview["money"])
	var reputation: int = int(preview["reputation"])
	var karma: int = int(preview["karma"])

	var avatar: PlayerAvatar = world.avatar
	if avatar != null:
		avatar.money += money
		avatar.set_reputation(quest.city_id, avatar.get_reputation(quest.city_id) + reputation)
		avatar.karma += karma

	# M4.3：后果链的写入侧。标记带城市与类型，供生成侧按城读回
	var flags: Array = _write_flags(quest, preview["outcome"])
	var delayed: Array = _queue_delayed(quest, preview["outcome"], month)

	# 城市增量走唯一写入口。零额度的选项（转卖公粮这类对城市无增益的）不提交——
	# StateChange 明确拒绝 delta == 0，那是"没有变更"而不是"变更了 0 点"。
	var change: StateChange = null
	if state_delta != 0:
		change = StateChange.make(
			"quest-%s-%s" % [quest.quest_id, branch_id],
			quest.city_id,
			quest.dimension(),
			state_delta,
			StateChange.SOURCE_QUEST,
			quest.quest_id,
			month
		)

	quest.state = Quest.STATE_DONE
	return {
		"ok": true,
		"questId": quest.quest_id,
		"cityId": quest.city_id,
		"branchId": branch_id,
		"label": str(preview["label"]),
		"detail": str(preview["detail"]),
		"dimension": quest.dimension(),
		"stateDelta": state_delta,
		"money": money,
		"reputation": reputation,
		"karma": karma,
		"reputationMultiplier": amplify,
		"flags": flags,
		"delayed": delayed,
		"change": change,
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 某个选项的完整后果。**交付与界面预览共用这一处**——界面若自己再算一遍，
## "选项上写着 +6、落账却是 +4"这种错误就只能靠人肉发现。
## amplify 是 6 章的声誉联动系数。
static func outcome_preview(quest: Quest, branch_id: String, amplify: float) -> Dictionary:
	var outcome: Dictionary = resolve_outcome(quest.quest_type, branch_id)
	if outcome.is_empty():
		return {}
	var money: int = apply_multiplier(quest.money_copper(),
		float(outcome.get("moneyMultiplier", 1.0)))
	return {
		"branchId": branch_id,
		"label": str(outcome.get("label", "")),
		"detail": str(outcome.get("detail", "")),
		"dimension": quest.dimension(),
		"stateDelta": apply_multiplier(quest.state_gain(), float(outcome.get("stateMultiplier", 1.0))),
		"money": int(round(float(money) * amplify)),
		"reputation": int(outcome.get("reputationGain", quest.reputation_gain())),
		"karma": int(outcome.get("karmaGain", quest.karma_gain())),
		"outcome": outcome,
	}


## 一个分支的后果配置。branch_id 为 "combat:<倒地处理|defeat>" 时从该类型的
## combat.outcomes 里取，否则从 branches 里按 branchId 取。
static func resolve_outcome(quest_type: String, branch_id: String) -> Dictionary:
	var config: Dictionary = ContentLoader.get_quest_type(quest_type)
	if config.is_empty():
		return {}
	if branch_id.begins_with(COMBAT_PREFIX):
		var key: String = branch_id.substr(COMBAT_PREFIX.length())
		# 表里没有战斗段的类型写的是 "combat": null，而 get 的缺省值只在键不存在时
		# 生效——所以这里必须显式判类型，否则拿到的是 null 而不是空字典。
		var raw: Variant = config.get("combat", null)
		if not (raw is Dictionary):
			return {}
		var combat: Dictionary = raw
		var outcomes: Dictionary = combat.get("outcomes", {})
		var outcome: Dictionary = outcomes.get(key, {})
		if outcome.is_empty():
			return {}
		return {
			"branchId": branch_id,
			"label": str(outcome.get("label", "")),
			"detail": str(outcome.get("detail", "")),
			"stateMultiplier": float(outcome.get("stateMultiplier", 1.0)),
			"moneyMultiplier": float(outcome.get("moneyMultiplier", 1.0)),
			"reputationGain": int(outcome.get("reputationGain", 0)),
			"karmaGain": int(outcome.get("karmaGain", 0)),
			"flags": outcome.get("flags", []),
		}
	var branch: Dictionary = find_branch(config, branch_id)
	if branch.is_empty():
		return {}
	var resolved: Dictionary = branch.duplicate(true)
	resolved["branchId"] = branch_id
	return resolved


static func find_branch(config: Dictionary, branch_id: String) -> Dictionary:
	for branch in config.get("branches", []):
		if str(branch.get("branchId", "")) == branch_id:
			return branch
	return {}


## 6 章的声誉联动系数。敬重（≥ 阈值）放大回报，敌视（≤ 负阈值）打对折。
## 只作用在金钱上——让声誉再去放大声誉，敌视会自我强化成解不开的死结。
static func reputation_multiplier(world: WorldState, city_id: String, rules: Dictionary) -> float:
	var avatar: PlayerAvatar = world.avatar
	if avatar == null:
		return 1.0
	var value: int = avatar.get_reputation(city_id)
	if value >= int(rules.get("reputationRespectThreshold", 60)):
		return float(rules.get("reputationRespectMultiplier", 1.5))
	if value <= int(rules.get("reputationHostileThreshold", -60)):
		return float(rules.get("reputationHostileMultiplier", 0.5))
	return 1.0


static func apply_multiplier(base: int, multiplier: float) -> int:
	if base == 0 or multiplier == 0.0:
		return 0
	var scaled: int = int(round(float(base) * multiplier))
	# 非零分支就至少留 1 点：否则"少给一点"会把增量抹成 0，
	# 玩家看到的是"我明明办了事，城市一动不动"
	if scaled == 0:
		return 1 if base > 0 else -1
	return scaled


func _write_flags(quest: Quest, outcome: Dictionary) -> Array:
	var written: Array = []
	for raw in outcome.get("flags", []):
		var flag: String = "%s%s.%s.%s" % [FLAG_PREFIX, quest.city_id, quest.quest_type, str(raw)]
		world.world_flags[flag] = true
		written.append(flag)
	return written


## 延迟后果先记下来，到期由月度结算提升为 StateChange（见 promote_due_consequences）。
func _queue_delayed(quest: Quest, outcome: Dictionary, month: int) -> Array:
	var delayed: Variant = outcome.get("delayed", null)
	if not (delayed is Dictionary):
		return []
	var cfg: Dictionary = delayed
	var seq: int = _next_consequence_seq()
	var record: Dictionary = {
		"dueMonth": month + int(cfg.get("months", 0)),
		"cityId": quest.city_id,
		"dimension": str(cfg.get("dimension", "")),
		"delta": int(cfg.get("delta", 0)),
		"text": str(cfg.get("text", "")),
		"questId": quest.quest_id,
		"seq": seq,
	}
	world.pending_consequences.append(record)
	return [record]


## 幂等键的后半段。同一条委托理论上只会排一次延迟后果，但读档重放同一批交付
## 时序号必须稳定，所以取"现有条数 + 1"而不是随机数。
func _next_consequence_seq() -> int:
	return world.pending_consequences.size() + 1


# --- I-18 放弃 ---

## 放弃。不扣声誉——人还没交付，账上没什么可扣的；但那一单就此让给别人。
func abandon(quest_id: String) -> Dictionary:
	var quest: Quest = world.find_quest(quest_id)
	if quest == null:
		return _fail(ERROR_NOT_FOUND, "没有这张委托：%s" % quest_id)
	world.remove_quest(quest_id)
	return {
		"ok": true, "questId": quest_id, "cityId": quest.city_id,
		"errorCode": ERROR_NONE, "error": "",
	}


# --- 月度结算的两个钩子（由 WorldSim 调用）---

## 到期的延迟后果 → 变更请求 + 事件文案。本模块只产出请求，提交由 WorldSim 做，
## 因为城市状态只有一个写入口。
func promote_due_consequences(month: int) -> Dictionary:
	var changes: Array = []
	var notices: Array = []
	var keep: Array = []
	for record in world.pending_consequences:
		if int(record.get("dueMonth", 0)) > month:
			keep.append(record)
			continue
		var change := StateChange.make(
			"quest-late-%s-%d" % [str(record.get("questId", "")), int(record.get("seq", 0))],
			str(record.get("cityId", "")),
			str(record.get("dimension", "")),
			int(record.get("delta", 0)),
			StateChange.SOURCE_QUEST,
			str(record.get("questId", "")),
			month
		)
		if change.validate().is_empty():
			changes.append(change)
			notices.append({
				"cityId": str(record.get("cityId", "")),
				"text": str(record.get("text", "")),
			})
	world.pending_consequences = keep
	return {"changes": changes, "notices": notices}


## 过期的委托。手上有张欠条却一直不办，城里的耐心会用完（扣该城声誉），
## 那张告示也就撤了——挂着不办不该是免费的。
func expire_overdue(month: int) -> Array:
	var notices: Array = []
	var loss: int = int(_rules.get("expireReputationLoss", 0))
	for quest in world.get_quests():
		if not quest.is_active() or not quest.is_overdue(month):
			continue
		quest.state = Quest.STATE_EXPIRED
		if loss > 0 and world.avatar != null:
			world.avatar.set_reputation(
				quest.city_id, world.avatar.get_reputation(quest.city_id) - loss
			)
		notices.append({
			"cityId": quest.city_id,
			"text": "「%s」的委托过了期限，%s 撤了告示" % [
				_tier_label(quest.tier_id), quest.giver_label
			],
		})
	return notices


static func _tier_label(tier_id: String) -> String:
	var tier: Dictionary = ContentLoader.get_quest_tier(tier_id)
	return str(tier.get("displayName", tier_id))


## 界面用的中文档位名与类型名。视图模型统一从这里取，免得两处各写一份翻译。
static func quest_type_label(quest_type: String) -> String:
	var config: Dictionary = ContentLoader.get_quest_type(quest_type)
	return str(config.get("displayName", quest_type))


static func _fail(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"errorCode": error_code,
		"error": message,
	}
