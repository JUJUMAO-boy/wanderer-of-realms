class_name Combat
extends RefCounted

## 网格回合战斗（M5，接口 I-19 ~ I-22）。
##
## 三条边界约束（《技术设计文档》第 2.3 与 10.1 节）：
##   1. **战斗不产生世界后果**。`resolve` 只返回 CombatOutcome，把结果转成城市
##      变更与标记是调用方的事。这里产出的 worldFlags 只是"标记"，不是 StateChange。
##   2. 所有随机走注入的 DeterministicRNG，回合顺序与平手判定都有确定规则，
##      同一场战斗重放必须得到同一结果。
##   3. 命中/伤害/部位等公式全部委托给 DerivedStats，本模块不复制一份公式。
##
## 回合结构取「回合制 + 先攻排序」：文档在这里是断的——只给了每回合 AP
## （4 + DEX/20）与基础 TU（100 − DEX×0.8），没有定义一轮等于多少 TU、
## 每个动作扣多少 TU。补出的规则是：
##   - 开战按 TU 升序排定行动顺序，TU 相同时按 unitId（平手规则文档未定义）。
##   - 每轮每个单位行动一次，AP 用尽或主动结束即换人；眩晕者跳过该轮。
##   - 敏捷高者既先手、每轮又能多出手，因此同等时间内出手次数更多（M5.1 验收）。
##
## 文档未定义、由实现补出的项（均记入技术设计文档 9.5 节）：
##   HP 归零一律报"倒地"而非死亡，补刀才致死；伤势分 3 级；头部命中后的眩晕概率；
##   四种倒地处理各自产出的世界标记字符串；掉落表不新增内容文件，直接按抽到的
##   稀有度去 items.json 里反查同档物品。

const ACTION_MOVE: String = "move"
const ACTION_ATTACK: String = "attack"
const ACTION_SKILL: String = "skill"
const ACTION_END_TURN: String = "end_turn"
const ACTION_DOWNED_CHOICE: String = "downed_choice"

const SIDE_PLAYER: String = "player"
const SIDE_ENEMY: String = "enemy"

## 倒地后的四种处理（《游戏设计文档》第 7 章）
const DOWNED_SEARCH: String = "search"
const DOWNED_CAPTURE: String = "capture"
const DOWNED_RELEASE: String = "release"
const DOWNED_FINISH: String = "finish"
const ALL_DOWNED_CHOICES: Array = [DOWNED_SEARCH, DOWNED_CAPTURE, DOWNED_RELEASE, DOWNED_FINISH]

const RESULT_ONGOING: String = "ongoing"
const RESULT_PLAYER: String = "player"
const RESULT_ENEMY: String = "enemy"

## 稀有度档位，低到高（《数值框架》8 节）
const RARITY_ORDER: Array = ["common", "fine", "rare", "epic", "legendary", "dragonforged"]

## TL 分档的稀有度权重（《数值框架》14.2 节的表，按千分位换算）
const THREAT_BANDS: Array = [
	{"maxThreat": 5, "weights": [850, 120, 30, 0, 0, 0]},
	{"maxThreat": 10, "weights": [600, 250, 120, 30, 0, 0]},
	{"maxThreat": 20, "weights": [300, 350, 250, 80, 20, 0]},
	{"maxThreat": 35, "weights": [100, 300, 350, 180, 50, 20]},
	{"maxThreat": 9999, "weights": [0, 100, 300, 350, 180, 70]},
]

var session_id: String = ""
var round: int = 0
var turn_index: int = 0
var finished: bool = false
var winner: String = RESULT_ONGOING
var units: Array = []
var obstacles: Dictionary = {}   ## "x,y" -> true
var log: Array = []
var loot: Array = []
var world_flags: Dictionary = {}
## 战斗中"谁磨了谁的装备"的统计（D-62）。战斗模块自己不碰装备实例——它只数数，
## 主场景打完据此对玩家佩戴的实例扣耐久。各条事件只是"这一击是玩家打出的、
## 打的哪种目标"，落下我们做纯计数，避免战斗层去改玩家背包里的东西。
var wear_player_attacks: int = 0
var wear_player_taken: int = 0

var _derived: DerivedStats = null
var _combat_cfg: Dictionary = {}
var _skills: Dictionary = {}     ## skillId -> 技能配置
var _items: Array = []
var _rng: DeterministicRNG = null


func _init(
	derived: DerivedStats = null,
	combat_cfg: Dictionary = {},
	skills: Array = [],
	items: Array = [],
	rng: DeterministicRNG = null
) -> void:
	_derived = derived if derived != null else DerivedStats.new()
	_combat_cfg = combat_cfg
	for skill in skills:
		_skills[str(skill.get("skillId", ""))] = skill
	_items = items
	_rng = rng if rng != null else DeterministicRNG.new(20260915)


# --- 开始 ---

## 开始一场战斗。encounter 结构：
##   { units: [单元规格...], obstacles: [[x,y]...], sessionId: 可选 }
## 单元规格：{ unitId, side, name, attributes, skills, weaponTemplateId,
##            armor, magicResist, luck, position: [x,y], threatLevel,
##            hp / maxHp / mp / bodyParts 可选（缺省由属性推算） }
func start(encounter: Dictionary) -> Dictionary:
	units.clear()
	obstacles.clear()
	log.clear()
	loot.clear()
	world_flags.clear()
	wear_player_attacks = 0
	wear_player_taken = 0
	finished = false
	winner = RESULT_ONGOING
	round = 1
	turn_index = 0

	session_id = str(encounter.get("sessionId", "combat-0001"))
	for pair in encounter.get("obstacles", []):
		var point: Array = pair
		obstacles["%d,%d" % [int(point[0]), int(point[1])]] = true

	for spec in encounter.get("units", []):
		var unit: Dictionary = _build_unit(spec)
		if unit.is_empty():
			return {"ok": false, "error": "INVALID_ARGUMENT", "reason": "单元规格不完整"}
		units.append(unit)

	if units.is_empty():
		return {"ok": false, "error": "INVALID_ARGUMENT", "reason": "没有参战单位"}

	_order_by_initiative()
	_find_next()
	_check_finished()
	return {"ok": true, "sessionId": session_id, "state": get_state()}


func get_state() -> Dictionary:
	var rows: Array = []
	for unit in units:
		rows.append({
			"unitId": str(unit["unitId"]),
			"name": str(unit["name"]),
			"side": str(unit["side"]),
			"hp": int(unit["hp"]),
			"maxHp": int(unit["maxHp"]),
			"ap": int(unit["ap"]),
			"tu": int(unit["tu"]),
			"position": unit["position"],
			"downed": bool(unit["downed"]),
			"dead": bool(unit["dead"]),
			"stunnedTurns": int(unit["stunnedTurns"]),
			"bodyParts": unit["bodyParts"].duplicate(true),
		})
	return {
		"sessionId": session_id,
		"round": round,
		"turnIndex": turn_index,
		"currentUnitId": current_unit_id(),
		"order": _order_ids(),
		"units": rows,
		"finished": finished,
		"winner": winner,
		"log": log.duplicate(true),
	}


## 当前该行动的单位 ID。战斗已结束时返回空串。
func current_unit_id() -> String:
	if finished or units.is_empty():
		return ""
	return str(units[turn_index]["unitId"])


## 当前单位还能行动吗（有 AP 且未倒地）。界面用它决定是等输入还是自动换人。
func can_act(unit_id: String) -> bool:
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty():
		return false
	if bool(unit["downed"]) or bool(unit["dead"]):
		return false
	return int(unit["ap"]) > 0


# --- 行动 ---

## 提交一个动作。action 结构：
##   { actionType, actorId, targetId(可选), moveTo: [x,y](可选),
##     skillId(可选), aimPart(可选，缺省躯干), downedChoice(可选) }
func submit_action(action: Dictionary) -> Dictionary:
	if finished:
		return {"ok": false, "error": "CONFLICT", "reason": "战斗已结束"}

	var actor: Dictionary = unit_by_id(str(action.get("actorId", "")))
	if actor.is_empty():
		return {"ok": false, "error": "NOT_FOUND", "reason": "参战单位不存在"}
	if str(actor["unitId"]) != current_unit_id():
		return {"ok": false, "error": "CONFLICT", "reason": "还没轮到这个单位行动"}
	if bool(actor["downed"]) or bool(actor["dead"]):
		return {"ok": false, "error": "CONFLICT", "reason": "倒地或阵亡的单位不能行动"}

	match str(action.get("actionType", "")):
		ACTION_MOVE:
			return _do_move(actor, action)
		ACTION_ATTACK:
			return _do_attack(actor, action, "")
		ACTION_SKILL:
			return _do_attack(actor, action, str(action.get("skillId", "")))
		ACTION_DOWNED_CHOICE:
			return _do_downed_choice(actor, action)
		ACTION_END_TURN:
			_spend_all(actor)
			_end_turn()
			return {"ok": true, "state": get_state(), "log": []}
		_:
			return {"ok": false, "error": "INVALID_ARGUMENT", "reason": "未知动作"}


## 结束战斗并产出结果。战斗不产生世界后果，城市影响由调用方决定。
func resolve() -> Dictionary:
	_check_finished()
	var participants: Array = []
	var casualties: Array = []
	for unit in units:
		var row: Dictionary = {
			"unitId": str(unit["unitId"]),
			"name": str(unit["name"]),
			"side": str(unit["side"]),
			"hp": int(unit["hp"]),
			"maxHp": int(unit["maxHp"]),
			"downed": bool(unit["downed"]),
			"dead": bool(unit["dead"]),
			"captured": bool(unit.get("captured", false)),
			"released": bool(unit.get("released", false)),
			"searched": bool(unit.get("searched", false)),
			"bodyParts": unit["bodyParts"].duplicate(true),
		}
		participants.append(row)
		if bool(unit["downed"]) or bool(unit["dead"]):
			casualties.append(row)
	return {
		"sessionId": session_id,
		"winner": winner,
		"rounds": round,
		"participantStates": participants,
		"casualties": casualties,
		"loot": loot.duplicate(true),
		"worldFlags": world_flags.duplicate(),
		"wearPlayerAttacks": wear_player_attacks,
		"wearPlayerTaken": wear_player_taken,
	}


## 技能定义查询。界面要用它显示名称、AP 与射程，因此公开；
## 技能表在构造时就注入好了，这里只是查一次。
func skill_def(skill_id: String) -> Dictionary:
	return _skills.get(skill_id, {})


## 从一单位的超重惩罚里取整数项。敌人没有 encumbrance（缺省为 0），
## 超重惩罚只作用于带着 `encumbrance` 的玩家单位。
func _enc_int(encumbrance: Dictionary, key: String) -> int:
	return maxi(0, int(encumbrance.get(key, 0)))


## 某单位移动一格要花多少 AP（含腿伤与超重惩罚）。界面与实际扣费共用这一处计算。
func unit_move_cost(unit: Dictionary) -> int:
	return _derived.move_cost(unit["bodyParts"]) \
		+ _enc_int(unit.get("encumbrance", {}), "movePenalty")


func unit_by_id(unit_id: String) -> Dictionary:
	for unit in units:
		if str(unit["unitId"]) == unit_id:
			return unit
	return {}


## 从规格装配一个参战单位。HP/MP 缺省由属性与装备推算——派生值不落盘，
## 战场上的当前值（hp/ap/tu）才是这一场里唯一的真值。
func _build_unit(spec: Dictionary) -> Dictionary:
	var unit_id: String = str(spec.get("unitId", ""))
	if unit_id.is_empty():
		return {}
	var attributes: Dictionary = _fill_attributes(spec.get("attributes", {}))
	var power: int = _derived.power_level(attributes, spec.get("skills", {}))
	var max_hp: int = maxi(1, int(spec.get("maxHp", _derived.max_hp(attributes, power))))
	var max_mp: int = maxi(1, _derived.max_mp(attributes))
	var position: Array = spec.get("position", [0, 0])
	var body_parts: Dictionary = spec.get("bodyParts", {})
	if body_parts.is_empty():
		body_parts = PlayerAvatar.new().body_parts
	var encumbrance: Dictionary = spec.get("encumbrance", {})
	if not (encumbrance is Dictionary):
		encumbrance = {}
	return {
		"unitId": unit_id,
		"name": str(spec.get("name", unit_id)),
		"side": str(spec.get("side", SIDE_ENEMY)),
		"attributes": attributes,
		"skills": spec.get("skills", {}),
		"powerLevel": power,
		"weapon": _weapon_of(spec),
		"armor": int(spec.get("armor", 0)),
		"magicResist": int(spec.get("magicResist", 0)),
		"hp": int(spec.get("hp", max_hp)),
		"maxHp": max_hp,
		"mp": int(spec.get("mp", max_mp)),
		"maxMp": max_mp,
		"ap": 0,
		# 超重者更笨重：TU 变大、行动序拖后（D-66）。敌人没有 encumbrance，缺省为 0
		"tu": _derived.time_units(attributes) + _enc_int(encumbrance, "tuPenalty"),
		"position": Vector2i(int(position[0]), int(position[1])),
		"bodyParts": body_parts.duplicate(true),
		"encumbrance": encumbrance,
		"downed": false,
		"dead": false,
		"stunnedTurns": 0,
		"cooldowns": {},
		"threatLevel": int(spec.get("threatLevel", 1)),
		"luck": int(spec.get("luck", 0)),
	}


## 让 AI 替一个单位行动一次（就近攻击，够不着就走近）。返回是否真的动了手。
## 敌人的行动逻辑文档未定义，这里只是一个够用的默认策略，供主循环调用。
func auto_action(unit_id: String) -> Dictionary:
	var actor: Dictionary = unit_by_id(unit_id)
	if actor.is_empty() or str(actor["unitId"]) != current_unit_id():
		return {"ok": false, "error": "CONFLICT", "reason": "还没轮到这个单位行动"}
	if int(actor["ap"]) <= 0:
		_end_turn()
		return {"ok": true, "state": get_state(), "log": []}

	var target: Dictionary = _nearest_opponent(actor)
	if target.is_empty():
		# 对手全倒了：把未定的倒地者按「放走」处理，否则自动驱动的战斗会永远空转
		var other_side: String = SIDE_PLAYER if str(actor["side"]) == SIDE_ENEMY else SIDE_ENEMY
		_abandon_pending(other_side)
		_spend_all(actor)
		_end_turn()
		return {"ok": true, "state": get_state(), "log": []}

	var reach: int = maxi(1, int(actor["weapon"].get("attackRange", 1)))
	var distance: int = _manhattan(actor["position"], target["position"])
	if distance > reach:
		var step: Vector2i = _step_toward(actor["position"], target["position"])
		if step == actor["position"]:
			_spend_all(actor)
			_end_turn()
			return {"ok": true, "state": get_state(), "log": []}
		return _do_move(actor, {"moveTo": [step.x, step.y]})
	return _do_attack(actor, {"targetId": str(target["unitId"])}, "")


# --- 内部：回合推进 ---

## 先攻顺序：TU 升序（越小越先动），平手按 unitId。
func _order_by_initiative() -> void:
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["tu"]) != int(b["tu"]):
			return int(a["tu"]) < int(b["tu"])
		return str(a["unitId"]) < str(b["unitId"]))


func _order_ids() -> Array:
	var out: Array = []
	for unit in units:
		out.append(str(unit["unitId"]))
	return out


## 把行动权交给下一位能行动的单位，AP 补满；倒地/阵亡跳过，眩晕者消耗一层并跳过。
## 扫描上限是一整轮：整轮无人能行动时不推进指针也不报错，交给 _check_finished 判定。
func _find_next() -> void:
	var scanned: int = 0
	while scanned < units.size():
		var unit: Dictionary = units[turn_index]
		if not bool(unit["dead"]) and not bool(unit["downed"]):
			if int(unit["stunnedTurns"]) > 0:
				unit["stunnedTurns"] = int(unit["stunnedTurns"]) - 1
				_push_log("  %s 处于眩晕，跳过本轮" % str(unit["name"]))
			else:
				# 超重扣本轮行动点，但至少留 1 点能动作（渐进惩罚、不硬封锁，D-66）
				var ap_penalty: int = _enc_int(unit.get("encumbrance", {}), "apPenalty")
				unit["ap"] = maxi(1, _derived.action_points(unit["attributes"]) - ap_penalty)
				return
		turn_index += 1
		scanned += 1
		if turn_index >= units.size():
			turn_index = 0
			round += 1


func _end_turn() -> void:
	turn_index += 1
	if turn_index >= units.size():
		turn_index = 0
		round += 1
	_find_next()
	_check_finished()


func _spend(actor: Dictionary, cost: int) -> void:
	actor["ap"] = maxi(0, int(actor["ap"]) - cost)


func _spend_all(actor: Dictionary) -> void:
	actor["ap"] = 0


## 出手后的收尾：AP 用尽就自动换人。
func _after_action(actor: Dictionary) -> void:
	_check_finished()
	if finished:
		return
	if int(actor["ap"]) <= 0:
		_end_turn()


# --- 内部：动作实现 ---

func _do_move(actor: Dictionary, action: Dictionary) -> Dictionary:
	var raw: Array = action.get("moveTo", [])
	if raw.size() < 2:
		return {"ok": false, "error": "INVALID_ARGUMENT", "reason": "缺少目标坐标"}
	var target := Vector2i(int(raw[0]), int(raw[1]))
	var distance: int = _manhattan(actor["position"], target)
	if distance <= 0:
		return {"ok": false, "error": "INVALID_ARGUMENT", "reason": "原地不动不需要消耗行动点"}
	if obstacles.has("%d,%d" % [target.x, target.y]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "目标格被阻挡"}
	# 腿部受伤让每格更贵（6.4 节「腿→降移速」），超重再叠一层（D-66）。
	# 用 unit_move_cost 而不是裸 _derived.move_cost，否则超重者的移动惩罚不生效。
	var cost: int = distance * unit_move_cost(actor)
	if cost > int(actor["ap"]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "行动点不足：需要 %d，剩余 %d" % [
			cost, int(actor["ap"])
		]}
	actor["position"] = target
	_spend(actor, cost)
	var entry: String = "%s 移动到 (%d, %d)，消耗 %d AP" % [
		str(actor["name"]), target.x, target.y, cost
	]
	_push_log(entry)
	# 走完最后一步同样要换人。漏掉这一步的症状是：用移动花光 AP 后行动权不交出去，
	# 界面还列着已经点不动的动作，玩家得手动按一次结束回合——而出手后是自动换人的。
	_after_action(actor)
	# 返回值里带的是这一条动作日志，不是 log 的末行：_after_action 可能又追加了
	# 「眩晕跳过本轮」或「战斗结束」之类的内容。
	return {"ok": true, "state": get_state(), "log": [entry]}


func _do_attack(actor: Dictionary, action: Dictionary, skill_id: String) -> Dictionary:
	var target: Dictionary = unit_by_id(str(action.get("targetId", "")))
	if target.is_empty():
		return {"ok": false, "error": "NOT_FOUND", "reason": "目标不存在"}
	if bool(target["dead"]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "目标已阵亡"}
	if str(target["side"]) == str(actor["side"]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "不能攻击同侧单位"}

	var aim_part: String = str(action.get("aimPart", DerivedStats.AIM_TORSO))
	var skill: Dictionary = _skills.get(skill_id, {})
	var is_basic: bool = skill_id.is_empty()
	if not is_basic and skill.is_empty():
		return {"ok": false, "error": "NOT_FOUND", "reason": "技能不存在：" + skill_id}

	var ap_cost: int = 2 if is_basic else int(skill.get("apCost", 2))
	if ap_cost > int(actor["ap"]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "行动点不足：需要 %d，剩余 %d" % [
			ap_cost, int(actor["ap"])
		]}
	var cooldown: int = int(actor["cooldowns"].get(skill_id, 0))
	if not is_basic and cooldown > 0:
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "技能还在冷却：剩 %d 轮" % cooldown}

	var attack_range: int = int(actor["weapon"].get("attackRange", 1))
	if not is_basic and int(skill.get("attackRange", 0)) > 0:
		attack_range = int(skill["attackRange"])
	var distance: int = _manhattan(actor["position"], target["position"])
	if distance > attack_range:
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "距离 %d 超出攻击距离 %d" % [
			distance, attack_range
		]}

	_spend(actor, ap_cost)
	if not is_basic and int(skill.get("cooldown", 0)) > 0:
		actor["cooldowns"][skill_id] = int(skill.get("cooldown", 0))

	var skill_level: int = int(actor["skills"].get(skill_id, 0)) if not is_basic else 0
	var label: String = "普通攻击" if is_basic else str(skill.get("displayName", skill_id))

	var hit_bp: int = _derived.hit_chance_bp(
		actor["attributes"], skill_level, target["attributes"],
		aim_part, actor["bodyParts"], 0, 0
	)
	if not is_basic:
		hit_bp += int(skill.get("hitBonus", 0)) * 100
	# 超重拖累身手：闪避不开、瞄不准，直接扣命中（渐进惩罚，D-66）
	hit_bp -= _enc_int(actor.get("encumbrance", {}), "hitPenaltyBp")
	# 越级惩罚在派生值的钳制之后扣：它要能把命中率压到常规下限（5%）以下，
	# 否则"打不过的东西"依旧能靠 5% 一点点磨死（13.2 节明确要挡住这种解法）
	hit_bp -= level_gap_hit_penalty_bp(int(actor["threatLevel"]), int(target["threatLevel"]))
	hit_bp = clampi(hit_bp, 0, DerivedStats.BP_FULL)
	if not _roll(hit_bp, DerivedStats.BP_FULL):
		var entry: String = "%s 用%s攻击 %s，未命中（命中率 %.1f%%）" % [
			str(actor["name"]), label, str(target["name"]), float(hit_bp) / 100.0
		]
		_push_log(entry)
		_after_action(actor)
		return {"ok": true, "state": get_state(), "log": [entry]}

	var crit_bonus: int = int(skill.get("critBonus", 0)) * 100 if not is_basic else 0
	var is_crit: bool = _roll(_derived.crit_chance_bp(actor["attributes"], crit_bonus), DerivedStats.BP_FULL)
	var damage: int = _compute_damage(actor, target, skill, skill_level, aim_part, is_crit)
	damage = apply_level_gap_to_damage(
		damage, int(actor["threatLevel"]), int(target["threatLevel"])
	)

	var before: int = int(target["hp"])
	target["hp"] = before - damage
	_apply_body_damage(target, aim_part, damage)

	# 磨损只在 **命中** 时计（D-62）：打偏不磨武器、闪过的攻击不磨护甲。
	if str(actor["side"]) == SIDE_PLAYER:
		wear_player_attacks += 1
	if str(target["side"]) == SIDE_PLAYER:
		wear_player_taken += 1

	var entry: String = "%s 用%s命中 %s 的%s，造成 %d 点伤害%s（HP %d → %d）" % [
		str(actor["name"]), label, str(target["name"]), _part_label(aim_part),
		damage, "，暴击" if is_crit else "", before, maxi(0, int(target["hp"])),
	]
	_push_log(entry)

	if aim_part == DerivedStats.AIM_HEAD and _roll(_derived.stun_chance_per_mille(), 1000):
		target["stunnedTurns"] = 1
		_push_log("  %s 头部受创，陷入眩晕" % str(target["name"]))

	if int(target["hp"]) <= 0:
		_fall(target)

	_after_action(actor)
	return {"ok": true, "state": get_state(), "log": [entry]}


# --- 越级惩罚（《数值框架》13.2）---

## TL 差超过阈值时，每多差一级算几级"越级"。低打高才有——反过来不惩罚。
func level_gap(attacker_tl: int, target_tl: int) -> int:
	return maxi(0, target_tl - attacker_tl - _cfg("levelGapThreshold", 5))


## 越级带来的命中扣减（基点）。公开出来是为了让"差几级扣多少"能被直接断言。
func level_gap_hit_penalty_bp(attacker_tl: int, target_tl: int) -> int:
	return level_gap(attacker_tl, target_tl) * _cfg("levelGapHitPenaltyBp", 300)


## 越级带来的伤害系数。原文只说"逐步下降"，这里按每级线性扣减，
## 并留一个下限——留着下限是因为"完全打不动"与"打得很吃力"是两件事，
## 后者才是玩家愿意整备之后再来一次的理由。
func level_gap_damage_ratio(attacker_tl: int, target_tl: int) -> float:
	var ratio: float = 1.0 - float(level_gap(attacker_tl, target_tl)) \
		* _cfg_float("levelGapDamageRatio", 0.08)
	return clampf(ratio, _cfg_float("levelGapDamageFloorRatio", 0.25), 1.0)


func apply_level_gap_to_damage(damage: int, attacker_tl: int, target_tl: int) -> int:
	var ratio: float = level_gap_damage_ratio(attacker_tl, target_tl)
	if ratio >= 1.0:
		return damage
	return maxi(1, roundi(float(damage) * ratio))


## 伤害走哪条公式由技能分类决定：法术走魔法公式，武器技能与技艺走物理公式。
## 技艺（technique）在技能库里没有倍率列，按 1.0 处理——它靠效果而不是倍率生效。
func _compute_damage(
	actor: Dictionary, target: Dictionary, skill: Dictionary,
	skill_level: int, aim_part: String, is_crit: bool
) -> int:
	var damage_type: String = str(skill.get("damageType", "physical"))
	var category: String = str(skill.get("category", "weapon"))
	var is_spell: bool = category == "spell" or (
		damage_type != "physical" and damage_type != "none"
	)
	if is_spell:
		return _derived.magic_damage(
			actor["attributes"], int(skill.get("baseDamage", 0)), skill_level,
			int(target["magicResist"]), damage_type, 1000, is_crit
		)
	var multiplier: float = float(skill.get("multiplier", 0.0))
	if multiplier <= 0.0:
		multiplier = 1.0
	return _derived.physical_damage(
		actor["attributes"], int(actor["weapon"].get("attack", 0)), skill_level,
		multiplier, int(target["armor"]),
		float(skill.get("armorPierce", 0.0)) + float(actor["weapon"].get("armorPierce", 0.0)),
		aim_part, is_crit
	)


## 命中头部/四肢时给对方留下伤势（6.4 节）。
func _apply_body_damage(target: Dictionary, aim_part: String, damage: int) -> void:
	if damage <= 0:
		return
	if not DerivedStats.PARTS_HEAD.has(aim_part) and not DerivedStats.PARTS_LIMBS.has(aim_part):
		return
	var state: Dictionary = target["bodyParts"].get(aim_part, {"injured": false, "severity": 0})
	target["bodyParts"][aim_part] = {
		"injured": true,
		"severity": mini(_derived.max_injury_severity(), int(state.get("severity", 0)) + 1),
		"treated": false,
	}


## HP 归零 → 倒地而非死亡，生死交给倒地处理选择（《游戏设计文档》第 7 章：
## 「多数战斗可被打倒而非杀死」；该节没有给"多数"的比例与判定条件，
## 这里统一取"归零即倒地"，是补充定义）。
func _fall(target: Dictionary) -> void:
	target["hp"] = 0
	target["downed"] = true
	target["ap"] = 0
	_push_log("  %s 倒下了" % str(target["name"]))


func _do_downed_choice(actor: Dictionary, action: Dictionary) -> Dictionary:
	var target: Dictionary = unit_by_id(str(action.get("targetId", "")))
	if target.is_empty():
		return {"ok": false, "error": "NOT_FOUND", "reason": "目标不存在"}
	if not bool(target["downed"]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "目标没有倒地"}
	if str(target["side"]) == str(actor["side"]):
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "不能对自己人做倒地处理"}

	var choice: String = str(action.get("downedChoice", ""))
	if not ALL_DOWNED_CHOICES.has(choice):
		return {"ok": false, "error": "INVALID_ARGUMENT", "reason": "未知的倒地处理"}
	if int(actor["ap"]) < 1:
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "行动点不足：处理倒地者需要 1 AP"}
	_spend(actor, 1)

	# 四种处理各自产出一枚世界标记，供任务与城市事件读取。标记字符串文档未定义。
	# handled 让"这具身体的下场已经定了"可判定——否则战斗会在打倒人之后
	# 立刻结束，玩家来不及做 M5.4 要求的那个选择。
	var unit_id: String = str(target["unitId"])
	target["handled"] = true
	world_flags["combat.%s.%s" % [choice, unit_id]] = true
	var entry: String = ""
	match choice:
		DOWNED_SEARCH:
			var dropped: Array = _roll_loot(target)
			loot.append_array(dropped)
			target["searched"] = true
			entry = "%s 搜了 %s 的身，得到 %d 件物品" % [
				str(actor["name"]), str(target["name"]), dropped.size()
			]
		DOWNED_CAPTURE:
			target["captured"] = true
			target["capturedBy"] = str(actor["unitId"])
			entry = "%s 俘虏了 %s" % [str(actor["name"]), str(target["name"])]
		DOWNED_RELEASE:
			target["released"] = true
			entry = "%s 放走了 %s" % [str(actor["name"]), str(target["name"])]
		DOWNED_FINISH:
			target["dead"] = true
			entry = "%s 补刀了 %s" % [str(actor["name"]), str(target["name"])]
	_push_log(entry)

	_after_action(actor)
	return {"ok": true, "state": get_state(), "log": [entry]}


# --- 内部：结束判定与掉落 ---

## 结束判定。一方没有站立单位时**不立刻结束**：若那一方还有倒在地上、下场未定
## 的人，战斗继续——这是 M5.4「对倒地者选择搜身/俘虏/放走/补刀」能成立的前提。
## 否则打倒的瞬间战斗就结束了，玩家根本没有选择的时机。
func _check_finished() -> void:
	if finished:
		return
	var player_up: int = 0
	var enemy_up: int = 0
	for unit in units:
		if bool(unit["dead"]) or bool(unit["downed"]):
			continue
		if str(unit["side"]) == SIDE_PLAYER:
			player_up += 1
		else:
			enemy_up += 1
	if _pending_downed(SIDE_PLAYER) > 0:
		player_up += 1
	if _pending_downed(SIDE_ENEMY) > 0:
		enemy_up += 1
	if player_up == 0 or enemy_up == 0:
		finished = true
		if enemy_up == 0 and player_up > 0:
			winner = RESULT_PLAYER
		elif player_up == 0 and enemy_up > 0:
			winner = RESULT_ENEMY
		else:
			winner = RESULT_ONGOING
		_push_log("战斗结束：%s" % ("玩家一方胜" if winner == RESULT_PLAYER else "敌方胜"))


## 某侧倒在地上、下场还没定的人数。
func _pending_downed(side: String) -> int:
	var count: int = 0
	for unit in units:
		if str(unit["side"]) != side:
			continue
		if not bool(unit["downed"]) or bool(unit["dead"]):
			continue
		if not bool(unit.get("handled", false)):
			count += 1
	return count


## 把某侧所有下场未定的倒地者按「放走」处理。给 AI 兜底用：
## 对手全倒了之后 AI 没有攻击目标，若不做这一步，自动驱动的战斗会永远空转。
func _abandon_pending(side: String) -> void:
	for unit in units:
		if str(unit["side"]) != side or not bool(unit["downed"]):
			continue
		if bool(unit["dead"]) or bool(unit.get("handled", false)):
			continue
		unit["released"] = true
		unit["handled"] = true
		world_flags["combat.%s.%s" % [DOWNED_RELEASE, str(unit["unitId"])]] = true
		_push_log("  %s 倒在地上无人过问" % str(unit["name"]))


## 掉落结算（M5.5）。原文（《数值框架》14.1–14.2 节）：
##   基础掉落率 = 30% + TL×2%；实际 = 基础 × (1 + 幸运/200)，钳制 5%–100%
##   稀有度按 TL 分档查表，幸运每 +20 让高稀有度概率 +1%（从最低档扣减）
##
## 掉落表本身文档只给了分类（野兽/亡灵/龙类/人形/传奇），没有字段结构与物品清单，
## 因此这里按抽到的稀有度去 items.json 反查同档物品——不新增一份内容表。
func _roll_loot(target: Dictionary) -> Array:
	var tl: int = maxi(0, int(target["threatLevel"]))
	if not _roll(loot_chance_bp(tl, int(target["luck"])), DerivedStats.BP_FULL):
		return []
	var rarity: String = _roll_rarity(tl, int(target["luck"]))
	var template: Dictionary = _pick_item_of_rarity(rarity)
	if template.is_empty():
		return []
	return [{
		"unitId": str(target["unitId"]),
		"templateId": str(template["templateId"]),
		"displayName": str(template.get("displayName", "")),
		"rarity": str(template.get("rarity", rarity)),
		"threatLevel": tl,
	}]


## 掉落概率（基点）。抽成公开函数，让「掉落率随 TL 与幸运变化」这条 M5.5 的
## 验收标准可以被直接断言，而不必靠统计抽样。原文（14.1 节）：
##   基础 = 30% + TL×2%；实际 = 基础 × (1 + 幸运/200)，钳制 5%–100%
func loot_chance_bp(threat_level: int, luck: int) -> int:
	var base_bp: int = _cfg("lootBaseChanceBp", 3000) \
		+ maxi(0, threat_level) * _cfg("lootPerThreatLevelBp", 200)
	var divisor: float = maxf(1.0, float(_cfg("lootLuckDivisor", 200)))
	var chance: int = int(round(float(base_bp) * (1.0 + float(luck) / divisor)))
	return clampi(chance, _cfg("lootChanceMinBp", 500), _cfg("lootChanceMaxBp", 10000))


## 稀有度抽样：先按 TL 取权重表，再按「幸运每 +20 高稀有度 +1%」把权重从最低档
## 搬到最高档（负幸运反向搬，最多搬空最低档）。
func _roll_rarity(threat_level: int, luck: int) -> String:
	var weights: Array = rarity_weights(threat_level, luck)
	var total: int = 0
	for weight in weights:
		total += int(weight)
	if total <= 0:
		return str(RARITY_ORDER[0])
	var roll: int = _rng.next_int(total)
	var cumulative: int = 0
	for i in range(weights.size()):
		cumulative += int(weights[i])
		if roll < cumulative:
			return str(RARITY_ORDER[i])
	return str(RARITY_ORDER[0])


## 某一 TL 与幸运下的稀有度权重表，下标对应 RARITY_ORDER。
## 公开出来是为了让《数值框架》14.2 节的表与幸运偏移规则都能被断言。
func rarity_weights(threat_level: int, luck: int) -> Array:
	var band: Dictionary = THREAT_BANDS[THREAT_BANDS.size() - 1]
	for entry in THREAT_BANDS:
		if threat_level <= int(entry["maxThreat"]):
			band = entry
			break
	var weights: Array = []
	for weight in band["weights"]:
		weights.append(int(weight))
	var step: int = maxi(1, _cfg("luckPerRarityStep", 20))
	var steps: int = int(floor(float(luck) / float(step)))
	var top_index: int = weights.size() - 1
	if steps > 0:
		var shift: int = mini(mini(100, steps), int(weights[0]))
		weights[0] = int(weights[0]) - shift
		weights[top_index] = int(weights[top_index]) + shift
	elif steps < 0:
		var back: int = mini(mini(100, -steps), int(weights[top_index]))
		weights[top_index] = int(weights[top_index]) - back
		weights[0] = int(weights[0]) + back
	return weights


## 按稀有度反查一件物品；该档没有就往下找一档。
func _pick_item_of_rarity(rarity: String) -> Dictionary:
	var index: int = RARITY_ORDER.find(rarity)
	if index < 0:
		index = 0
	for offset in range(index + 1):
		var candidates: Array = []
		var wanted: String = str(RARITY_ORDER[index - offset])
		for item in _items:
			if str(item.get("rarity", "")) == wanted:
				candidates.append(item)
		if not candidates.is_empty():
			return candidates[_rng.next_int(candidates.size())]
	return {}


# --- 内部：杂项 ---

## 参战单位手上的家伙。以模板为底（护甲穿透这类字段只有模板有），但**伤害与射程
## 可以由规格覆盖**——玩家的武器带着强化与词缀，那两项目模板算不出来（D-54）。
## 覆盖项缺省时不生效，于是模拟 NPC 与事件对手照旧只写 weaponTemplateId。
func _weapon_of(spec: Dictionary) -> Dictionary:
	var template_id: String = str(spec.get("weaponTemplateId", ""))
	var fallback: Dictionary = {"attack": 0, "attackRange": 1, "armorPierce": 0.0}
	var weapon: Dictionary = fallback
	if not template_id.is_empty():
		for item in _items:
			if str(item.get("templateId", "")) == template_id:
				weapon = {
					"attack": int(item.get("attack", 0)),
					"attackRange": maxi(1, int(item.get("attackRange", 1))),
					"armorPierce": float(item.get("armorPierce", 0.0)),
				}
				break
	if spec.has("weaponAttack"):
		weapon["attack"] = maxi(0, int(spec["weaponAttack"]))
	if spec.has("weaponRange"):
		weapon["attackRange"] = maxi(1, int(spec["weaponRange"]))
	return weapon


func _nearest_opponent(actor: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = 1 << 30
	for unit in units:
		if str(unit["side"]) == str(actor["side"]):
			continue
		if bool(unit["dead"]) or bool(unit["downed"]):
			continue
		var distance: int = _manhattan(actor["position"], unit["position"])
		if distance < best_distance or (
			distance == best_distance and not best.is_empty()
			and str(unit["unitId"]) < str(best["unitId"])
		):
			best = unit
			best_distance = distance
	return best


## 朝目标走一步：先消掉 x 的差，再消掉 y 的差。绕障规则文档未定义，
## 这里只避开障碍格与站立单位，不做寻路。
##
## 倒地/阵亡者不算阻挡。它们本来就躺在地上，而 _step_toward 是直线走法：
## 若倒地者也占格，同一列上的两个单位会互相卡死——后面的那个永远走不到
## 目标，战斗也就永远打不完。玩家侧本来就能踩上倒地者的格子
## （_do_move 只看 obstacles），这里让 AI 与玩家一致。
func _step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var step := from
	if from.x != to.x:
		step = Vector2i(from.x + signi(to.x - from.x), from.y)
	elif from.y != to.y:
		step = Vector2i(from.x, from.y + signi(to.y - from.y))
	if obstacles.has("%d,%d" % [step.x, step.y]):
		return from
	for unit in units:
		if bool(unit["downed"]) or bool(unit["dead"]):
			continue
		if unit["position"] == step:
			return from
	return step


func _roll(numerator: int, denominator: int) -> bool:
	if denominator <= 0 or numerator <= 0:
		return false
	if numerator >= denominator:
		return true
	return _rng.next_int(denominator) < numerator


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _part_label(part: String) -> String:
	match part:
		"head": return "头部"
		"left_arm": return "左臂"
		"right_arm": return "右臂"
		"left_leg": return "左腿"
		"right_leg": return "右腿"
	return "躯干"


func _cfg(key: String, fallback: int) -> int:
	return int(_combat_cfg.get(key, fallback))


func _cfg_float(key: String, fallback: float) -> float:
	return float(_combat_cfg.get(key, fallback))


func _fill_attributes(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		out[attr] = int(source.get(attr, 10))
	return out


func _push_log(text: String) -> void:
	log.append(text)
	while log.size() > 200:
		log.pop_front()
