class_name EventSystem
extends RefCounted

## 城市事件模块（M7.1，接口 I-07 的调用方之一）。
##
## 与委托同一套骨架：**不自己写城市六维**——封港的瞬时冲击、每月的持续扣减、
## 分支的城市增量，一律变成 StateChange 交给 WorldSim 落账（10.4 节的"月中不变"）。
## 本类因此不引用 WorldSim，依赖方向保持单向：WorldSim → EventSystem。
##
## 一条事件的三种后果，对应三个不同的时间：
##   1. 触发：城被扣一笔（EV-02 的财富 -30）、航线收益中断，本月就落账
##   2. 持续：不解封就一直流血（每月 -3），由 apply_monthly_drain 每月重复
##   3. 了结：玩家选一个做法，玩家自己的钱/声誉/善恶当场结清，城市的增量排进
##      变更队列（下个整月落账）、世界标记与传奇航线是往后的事
##
## 事件实例（CityEvent）落盘，事件模板（events.json）不落盘——脚本改了对白，
## 存档里那场事件该说的话就跟着变，而不是冻结在旧文案上（3.2 节）。

## 与 WorldSim / QuestSystem 同名常量取同一个字符串：错误码是跨模块契约。
const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"
const ERROR_CONTENT_MISSING: String = "CONTENT_MISSING"

## 世界标记的前缀。写成 event.<城市>.<事件>.<后果>——与委托的 quest. 前缀同构，
## 中间带上城市是因为"在索恩港杀掉的利维坦"不该让别处的同类事件也当作已了结。
const FLAG_PREFIX: String = "event."

## 战斗痕迹的前缀。Combat 把"战场上怎么处置了谁"写成 combat.<处置>.<单位>。
## 触发条件里的"血腥味"读的就是它——它不带城市，只能按全局读，见 D-38。
const COMBAT_FLAG_PREFIX: String = "combat."

const OUTCOME_VICTORY: String = "victory"
const OUTCOME_DEFEAT: String = "defeat"

## 封港一直没人管、世界自己走完时写进 branchId 的记号。它不是配置里的分支——
## 没有任何人做选择：海怪退回深海，船改走了别的航道，这一场就此结束，不会再来。
## （要它复发，只能靠分赃那条把病根留着的路，见 _recently_resolved。）
const BRANCH_LIFTED: String = "lifted"

var world: WorldState = null
var _rules: Dictionary = {}


static func create(p_world: WorldState) -> EventSystem:
	var system := EventSystem.new()
	system.world = p_world
	system._rules = ContentLoader.get_balance_section("events")
	return system


## balance 的 events 段。界面要摆出冷却月数一类的东西时从这里取。
func rules() -> Dictionary:
	return _rules


# --- 读取 ---

## 进行中的事件，按触发月份与 id 排序。city_id 非空时只看那一座城。
func active(city_id: String = "") -> Array:
	var out: Array = []
	for event in world.get_events():
		if not event.is_active():
			continue
		if not city_id.is_empty() and event.city_id != city_id:
			continue
		out.append(event)
	return out


func active_count(city_id: String = "") -> int:
	return active(city_id).size()


func find(event_id: String) -> CityEvent:
	return world.find_event(event_id)


## 这座城有没有正在跑的事件。同一座城一次只跑一场：两场封港叠在一起，
## 玩家面对的是两份一模一样的告示，而"我处理的是哪一场"没有答案。
func has_active_in(city_id: String) -> bool:
	return not active(city_id).is_empty()


## 模板配置。界面与结算都按 templateId 现查 events.json，不在实例里存副本。
func template_of(event: CityEvent) -> Dictionary:
	if event == null:
		return {}
	return ContentLoader.get_event_template(event.template_id)


static func template_label(config: Dictionary, fallback: String = "") -> String:
	var name: String = str(config.get("displayName", ""))
	if not name.is_empty():
		return name
	return fallback


# --- 触发（I-07 的调用方）---

## 本月有没有满足条件的事件该发生。返回 {events, changes, notices}：
## 本模块只产出变更请求，提交是 WorldSim 的事。
##
## 触发判定排在月度结算的落账之前（见 WorldSim.settle_month 的顺序），
## 于是封港的瞬时冲击在触发当月就落下来，而不是"这个月封港、下个月才扣钱"。
func check_triggers(month: int) -> Dictionary:
	var triggered: Array = []
	var changes: Array = []
	var notices: Array = []
	for config in ContentLoader.get_events():
		var template_id: String = str(config.get("templateId", ""))
		var city_id: String = str(config.get("cityId", ""))
		if template_id.is_empty() or city_id.is_empty():
			continue
		if not conditions_met(config, city_id, month):
			continue
		var blockade: Dictionary = _dict_of(config.get("blockade", null))
		var event := CityEvent.make(
			"ev-%s-%d" % [template_id, month],
			template_id,
			city_id,
			month,
			bool(blockade.get("haltRoutes", false)),
			_dict_of(blockade.get("drainPerMonth", null))
		)
		world.add_event(event)
		triggered.append(event)
		for change in _changes_of(blockade, event, "blockade", month):
			changes.append(change)
		notices.append({
			"cityId": city_id,
			"text": "%s：%s" % [
				template_label(config, template_id), str(blockade.get("text", ""))
			],
		})
	return {"events": triggered, "changes": changes, "notices": notices}


## 这场事件现在该不该发生。三道门：城市存在、条件满足、以及**没有正在跑或刚了结的**。
func conditions_met(config: Dictionary, city_id: String, month: int) -> bool:
	var city: City = world.get_city(city_id)
	if city == null:
		return false
	if has_active_in(city_id):
		return false
	if _recently_resolved(str(config.get("templateId", "")), city_id, month):
		return false

	var trigger: Dictionary = _dict_of(config.get("trigger", null))
	var dimension: String = str(trigger.get("dimension", ""))
	if not dimension.is_empty() and city.get_dimension(dimension) < int(trigger.get("atLeast", 0)):
		return false
	return _smell_condition_met(trigger, city_id)


## "血腥味"。两种味道满足一种即可：这座城还在跑走私（有见不得光的货），
## 或者世界上已经有战斗留下的痕迹（有人动过手）。
##
## 取"或"而不是"与"：8.2 节要的是"条件开局即满足、不必先做前置任务"，
## 而索恩港开局只有走私航线、没有任何战斗标记。两项都要求的话，
## 玩家必须先随便打一场才会看见海怪——那正是剧本不想让玩家做的事。
func _smell_condition_met(trigger: Dictionary, city_id: String) -> bool:
	var need_smuggling: int = int(trigger.get("smellSmugglingRoutes", 0))
	var need_combat: int = int(trigger.get("smellCombatFlags", 0))
	if need_smuggling <= 0 and need_combat <= 0:
		return true
	if need_smuggling > 0:
		var routes: int = world.get_routes_of_city(city_id, TradeRoute.KIND_SMUGGLING).size()
		if routes >= need_smuggling:
			return true
	if need_combat > 0:
		var marks: int = 0
		for flag in world.world_flags:
			if str(flag).begins_with(COMBAT_FLAG_PREFIX) and bool(world.world_flags[flag]):
				marks += 1
		if marks >= need_combat:
			return true
	return false


## 这场事件在这座城是不是已经了结过、且不该再来一次。
##
## 判据只有一条：**上一次是怎么了结的**，以及那个结局有没有写明 recurrence。
## 剧本里的"可能复发"落在分赃分支上——病根（倒货的水路）还在，所以隔一阵子会
## 再封一次港；讨伐成功、揭发银鳞、以及"世界自己走完"都算了结，无论条件再满足
## 多少次都不该重演。
##
## 自发解除（lifted）之所以也算了结而不是"未根除"，是怕世界在无人过问时永远
## 振荡：财富涨回阈值 → 再封一次 → 再自行解除，如此往复。那会让"快进十年"把
## 一座城的贸易反复掐断，而玩家什么也没做。
func _recently_resolved(template_id: String, city_id: String, month: int) -> bool:
	var latest_month: int = -1
	var latest_branch: String = ""
	for event in world.get_events():
		if event.template_id != template_id or event.city_id != city_id:
			continue
		if not event.resolved:
			continue
		if event.resolved_month > latest_month:
			latest_month = event.resolved_month
			latest_branch = event.branch_id
	if latest_month < 0:
		return false
	var recurrence: bool = false
	if latest_branch != BRANCH_LIFTED:
		var config: Dictionary = ContentLoader.get_event_template(template_id)
		recurrence = bool(find_branch(config, latest_branch).get("recurrence", false))
	if not recurrence:
		return true
	return month - latest_month < int(_rules.get("recurrenceCooldownMonths", 12))


# --- 持续 ---

## 封港中的城市。WorldSim 把它交给 Economy.settle_routes——这些城相关的航线
## 收益整条中断（不是注销：航运停摆，解封即恢复，见 D-37）。
func blockade_cities() -> Dictionary:
	var out: Dictionary = {}
	for event in active():
		if event.halt_routes:
			out[event.city_id] = true
	return out


## 每月一次的持续代价。返回 {changes, notices}，提交由 WorldSim 做。
##
## 触发当月不扣：那个月已经吃了瞬时冲击（-30），再叠一笔 -3 会让人分不清
## "触发时扣了多少"。从下一个整月开始流血。
##
## 一直没人管也是有尽头的：拖过 blockadeLiftMonths 个月，港口自己缓过来了
## （船改走别的航道，海怪退回深海）。这一条不是为了好玩，而是不让"快进十年"
## 把整座城慢慢放干——每月的持续扣减没有尽头，财富会被钳到 0 并一直贴在 0 上。
## 解除之后这一场不会再演（同"病根已除"，见 _recently_resolved）。
func apply_monthly_drain(month: int) -> Dictionary:
	var changes: Array = []
	var notices: Array = []
	var lift_months: int = int(_rules.get("blockadeLiftMonths", 0))
	for event in active():
		if event.triggered_month >= month:
			continue
		var config: Dictionary = ContentLoader.get_event_template(event.template_id)
		var label: String = template_label(config, event.template_id)
		if lift_months > 0 and month - event.triggered_month >= lift_months:
			event.resolved = true
			event.phase = CityEvent.PHASE_DONE
			event.resolved_month = month
			event.branch_id = BRANCH_LIFTED
			notices.append({
				"cityId": event.city_id,
				"text": "「%s」一直没人管，船改走了别的航道，封锁自己松了下来。" % label,
			})
			continue
		if not event.has_drain():
			continue
		var dimension: String = str(event.drain.get("dimension", ""))
		var delta: int = int(event.drain.get("delta", 0))
		if dimension.is_empty() or delta == 0:
			continue
		var change := StateChange.make(
			"event-%s-drain-%d" % [event.event_id, month],
			event.city_id,
			dimension,
			delta,
			StateChange.SOURCE_EVENT,
			event.event_id,
			month
		)
		changes.append(change)
		notices.append({
			"cityId": event.city_id,
			"text": "「%s」还在继续：%s %+d" % [
				label, _dimension_label(dimension), delta
			],
		})
	return {"changes": changes, "notices": notices}


# --- 交付 ---

## 玩家选了一个做法。带战斗的分支不走这里——它在战场上分胜负，选中那一刻
## 还不知道后果（与委托的 combat 分支同一条设计）。
func resolve(event_id: String, branch_id: String, month: int) -> Dictionary:
	var event: CityEvent = find(event_id)
	var checked: Dictionary = _check_branch(event, branch_id)
	if not checked.is_empty():
		return checked
	var config: Dictionary = ContentLoader.get_event_template(event.template_id)
	var branch: Dictionary = find_branch(config, branch_id)
	if bool(branch.get("isCombat", false)):
		# 讨伐的后果分胜负两套，选中那一刻还不知道是哪一套——界面走
		# resolve_combat（打完由战场报胜负），这里拦住而不是随便挑一套。
		return _fail(ERROR_INVALID_ARGUMENT, "「%s」要打完才知道结果，先在战场上分胜负" % [
			str(branch.get("label", branch_id))
		])
	return _apply(event, config, branch, {}, month)


## 战斗分支的收尾（M5 的战果 → 事件的结局）。won 决定走 victory 还是 defeat。
func resolve_combat(event_id: String, won: bool, month: int) -> Dictionary:
	var event: CityEvent = find(event_id)
	var checked: Dictionary = _check_branch(event, "")
	if not checked.is_empty():
		return checked
	var config: Dictionary = ContentLoader.get_event_template(event.template_id)
	var branch: Dictionary = _combat_branch(config)
	if branch.is_empty():
		return _fail(ERROR_CONTENT_MISSING, "这场事件没有可打的分支：%s" % event.template_id)
	var outcome_key: String = OUTCOME_VICTORY if won else OUTCOME_DEFEAT
	var outcome: Dictionary = outcome_of(branch, outcome_key)
	if outcome.is_empty():
		return _fail(ERROR_CONTENT_MISSING, "「%s」没有 %s 这一套后果" % [
			template_label(config, event.template_id), outcome_key
		])
	return _apply(event, config, branch, outcome, month)


## 交付前的三道门。branch_id 为空表示"由战场定做法"，只校验事件本身。
func _check_branch(event: CityEvent, branch_id: String) -> Dictionary:
	if event == null:
		return _fail(ERROR_NOT_FOUND, "没有这场事件")
	if not event.is_active():
		return _fail(ERROR_PRECONDITION_FAILED, "这场事已经了结了")
	if world.get_city(event.city_id) == null:
		return _fail(ERROR_NOT_FOUND, "事件所在的城市不存在：%s" % event.city_id)
	var config: Dictionary = ContentLoader.get_event_template(event.template_id)
	if config.is_empty():
		return _fail(ERROR_CONTENT_MISSING, "内容表里没有这场事件：%s" % event.template_id)
	if branch_id.is_empty():
		return {}
	if find_branch(config, branch_id).is_empty():
		return _fail(ERROR_INVALID_ARGUMENT, "「%s」没有这个做法：%s" % [
			template_label(config, event.template_id), branch_id
		])
	return {}


## 把选定的后果落到世界上。分支与战斗结局走的是同一条路：战斗结局是"分支的
## 两套后果之一"，字段形状与分支完全一样（changes / reputation / karma / flags）。
func _apply(
	event: CityEvent, config: Dictionary, branch: Dictionary, outcome: Dictionary, month: int
) -> Dictionary:
	var branch_id: String = str(branch.get("branchId", ""))
	# 非战斗分支的后果直接写在分支上；战斗分支的两套后果写在 outcomes 里
	var spec: Dictionary = branch if outcome.is_empty() else outcome
	var preview: Dictionary = branch_preview(config, branch_id, _outcome_key_of(branch, outcome))

	var changes: Array = _changes_of(spec, event, branch_id, month)
	var avatar: PlayerAvatar = world.avatar
	var reputation: int = int(spec.get("reputation", 0))
	var karma: int = int(spec.get("karma", 0))
	if avatar != null:
		avatar.set_reputation(event.city_id, avatar.get_reputation(event.city_id) + reputation)
		avatar.karma += karma
		# 功绩（D-62）：处置过一次就算一次，打输了也算——"管过这件事"本身就是经历
		avatar.note_deed(PlayerAvatar.DEED_EVENTS_RESOLVED)

	var flags: Array = _write_flags(event, spec)
	var unlock: Dictionary = _route_unlock_of(spec, event)

	# 有些结局不了结这件事：讨伐失败就是其一——人活着回来了，海怪也还在，
	# 封港、断航、每月流血都照旧（《城市事件剧本》EV-02「什么都没变」）。
	# 缺省是了结，只有配置里写明 resolved: false 的才留在这场危机里。
	var ends_event: bool = bool(spec.get("resolved", true))
	event.branch_id = branch_id
	if ends_event:
		event.resolved = true
		event.phase = CityEvent.PHASE_DONE
		event.resolved_month = month

	return {
		"ok": true,
		"eventId": event.event_id,
		"templateId": event.template_id,
		"cityId": event.city_id,
		"branchId": branch_id,
		"label": str(preview.get("label", "")),
		"detail": str(preview.get("detail", "")),
		"isCombat": bool(branch.get("isCombat", false)),
		"eventEnded": ends_event,
		"changes": changes,
		"deltas": preview.get("deltas", []),
		# 事件不给钱：报酬是"城活过来了"与那条传奇航线（《城市事件剧本》EV-02）
		"money": 0,
		"reputation": reputation,
		"karma": karma,
		"flags": flags,
		"unlockRoute": unlock,
		"recurrence": bool(spec.get("recurrence", false)),
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 一个做法的完整后果。**交付与界面预览共用这一处**（与委托的 outcome_preview
## 同一条理由：两处各算一份，"选项上写 +30、落账却是 +20"就只能靠人眼发现）。
##
## outcome_key 为空时，带战斗的分支返回战役信息与两套后果的预告，不假装知道胜负。
static func branch_preview(
	config: Dictionary, branch_id: String, outcome_key: String = ""
) -> Dictionary:
	var branch: Dictionary = find_branch(config, branch_id)
	if branch.is_empty():
		return {}
	if bool(branch.get("isCombat", false)):
		var key: String = outcome_key
		if key.is_empty():
			var outcomes: Dictionary = _dict_of(branch.get("outcomes", null))
			var victory: Dictionary = _dict_of(outcomes.get(OUTCOME_VICTORY, null))
			var defeat: Dictionary = _dict_of(outcomes.get(OUTCOME_DEFEAT, null))
			return {
				"branchId": branch_id,
				"label": str(branch.get("label", "")),
				"detail": str(branch.get("detail", "")),
				"isCombat": true,
				"deltas": [],
				"reputation": 0,
				"karma": 0,
				"flags": [],
				"unlockRoute": {},
				"recurrence": false,
				"victory": _outcome_preview(victory),
				"defeat": _outcome_preview(defeat),
			}
		branch = outcome_of(branch, key)
	return _outcome_preview(branch)


## 结算用的一套后果（分支本身或战斗的某个结局）。
static func _outcome_preview(spec: Dictionary) -> Dictionary:
	var deltas: Array = []
	var changes: Dictionary = _dict_of(spec.get("changes", null))
	var dimensions: Array = changes.keys()
	dimensions.sort()
	for dimension in dimensions:
		var delta: int = int(changes[dimension])
		if delta == 0:
			continue
		deltas.append({"dimension": str(dimension), "delta": delta})
	return {
		"branchId": str(spec.get("branchId", "")),
		"label": str(spec.get("label", "")),
		"detail": str(spec.get("detail", "")),
		"deltas": deltas,
		"reputation": int(spec.get("reputation", 0)),
		"karma": int(spec.get("karma", 0)),
		"flags": spec.get("flags", []),
		"unlockRoute": _dict_of(spec.get("unlockRoute", null)),
		"recurrence": bool(spec.get("recurrence", false)),
		"resolved": bool(spec.get("resolved", true)),
	}


## 一行摆出这套后果的全部影响：城市六维、声誉、善恶、解锁的航线、会不会复发。
## 与交付算的是同一份数据，所以对得上。way_label 把航线的 kind 翻成中文。
static func effect_label(preview: Dictionary) -> String:
	var parts: Array = []
	for entry in preview.get("deltas", []):
		parts.append("%s %s" % [
			_dimension_label(str(entry.get("dimension", ""))), _signed(int(entry.get("delta", 0)))
		])
	if parts.is_empty():
		parts.append("城市无变化")
	var reputation: int = int(preview.get("reputation", 0))
	if reputation != 0:
		parts.append("声誉 %s" % _signed(reputation))
	var karma: int = int(preview.get("karma", 0))
	if karma != 0:
		parts.append("善恶 %s" % _signed(karma))
	var unlock: Dictionary = preview.get("unlockRoute", {})
	if not unlock.is_empty():
		parts.append("解锁%s" % WorldSim.route_kind_label(str(unlock.get("kind", ""))))
	if bool(preview.get("recurrence", false)):
		parts.append("病根未除，日后可能再犯")
	if not bool(preview.get("resolved", true)):
		parts.append("事没了结")
	return " · ".join(PackedStringArray(parts))


# --- 内容查表 ---

static func find_branch(config: Dictionary, branch_id: String) -> Dictionary:
	for branch in config.get("branches", []):
		if str(branch.get("branchId", "")) == branch_id:
			return branch
	return {}


## 配置里唯一带战斗的那个分支（EV-02 的讨伐）。
static func _combat_branch(config: Dictionary) -> Dictionary:
	for branch in config.get("branches", []):
		if bool(branch.get("isCombat", false)):
			return branch
	return {}


static func outcome_of(branch: Dictionary, outcome_key: String) -> Dictionary:
	return _dict_of(_dict_of(branch.get("outcomes", null)).get(outcome_key, null))


## 反查一套后果属于哪个结局名（改动 → 改动数据里不带键名，所以按值找回键）。
static func _outcome_key_of(branch: Dictionary, outcome: Dictionary) -> String:
	if outcome.is_empty():
		return ""
	var outcomes: Dictionary = _dict_of(branch.get("outcomes", null))
	for key in outcomes:
		if outcomes[key] == outcome:
			return str(key)
	return ""


# --- 内部 ---

## 一组维度增量 → StateChange 数组。零额度的项不提交：StateChange 明确拒绝
## delta == 0，那是"没有变更"而不是"变更了 0 点"。
func _changes_of(
	spec: Dictionary, event: CityEvent, tag: String, month: int
) -> Array:
	var out: Array = []
	var changes: Dictionary = _dict_of(spec.get("changes", null))
	var dimensions: Array = changes.keys()
	dimensions.sort()
	for dimension in dimensions:
		var delta: int = int(changes[dimension])
		if delta == 0:
			continue
		out.append(StateChange.make(
			"event-%s-%s-%s" % [event.event_id, tag, str(dimension)],
			event.city_id,
			str(dimension),
			delta,
			StateChange.SOURCE_EVENT,
			event.event_id,
			month
		))
	return out


func _write_flags(event: CityEvent, spec: Dictionary) -> Array:
	var written: Array = []
	for raw in spec.get("flags", []):
		var flag: String = "%s%s.%s.%s" % [
			FLAG_PREFIX, event.city_id, event.template_id, str(raw)
		]
		world.world_flags[flag] = true
		written.append(flag)
	return written


## 分支给的"解锁一条航线"。本模块只描述它，不去建——建立航线的判定与副作用
## 都在 WorldSim，依赖方向不能反过来（同 QuestSystem 只产出变更请求的理由）。
func _route_unlock_of(spec: Dictionary, event: CityEvent) -> Dictionary:
	var unlock: Dictionary = _dict_of(spec.get("unlockRoute", null))
	if unlock.is_empty():
		return {}
	var other: String = str(unlock.get("otherCity", ""))
	if other.is_empty():
		return {}
	return {
		"kind": str(unlock.get("kind", TradeRoute.KIND_LEGENDARY)),
		"cityA": event.city_id,
		"cityB": other,
		"note": str(unlock.get("note", "")),
	}


static func _dimension_label(dimension: String) -> String:
	return str(City.DIMENSION_LABELS.get(dimension, dimension))


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


## 显式判型的取字典。表里写 null 的地方不少（"这场事件没有每月代价"），
## 而 get 的缺省值只在键不存在时生效——不判型就会拿到 null 而不是空字典。
static func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _fail(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"errorCode": error_code,
		"error": message,
	}
