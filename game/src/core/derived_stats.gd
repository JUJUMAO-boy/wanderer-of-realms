class_name DerivedStats
extends RefCounted

## 派生值与战斗判定公式（《数值框架》4.1、4.2、6.1–6.5 节）。
##
## 存在理由是一条存档一致性约束：《技术设计文档》3.3 / 3.6 节规定派生值
## **一律不落盘**，每次由属性、装备与部位状态重算。落盘会让属性变更后派生值
## 不同步，是存档不一致的常见来源。所以这里是一个纯计算模块，没有任何缓存。
##
## 概率一律用**基点**表示（1% = 100 基点）。上游把 PER×0.4、DEX×0.2 这类
## 系数写成了不定量纲的乘子，按百分点解读才是合理量级（PER 20 → +8 个百分点）；
## 若按百分比分数解读，PER 20 只有 +0.08%，命中率会几乎恒定。
##
## 内部用浮点做连乘、最后取整。这里只用 +−×÷，IEEE 754 对这四个运算是确定性的；
## 项目规避的是 log/cos/exp 那类跨平台实现有差异的超越函数。

## 瞄准部位。躯干是默认，无命中惩罚也无伤害修正。
const AIM_HEAD: String = "head"
const AIM_TORSO: String = "torso"
const AIM_LIMB: String = "left_arm"

const PARTS_HEAD: Array = ["head"]
const PARTS_TORSO: Array = ["torso"]
const PARTS_LIMBS: Array = ["left_arm", "right_arm", "left_leg", "right_leg"]
const PARTS_ARM: Array = ["left_arm", "right_arm"]
const PARTS_LEG: Array = ["left_leg", "right_leg"]

## 百分比的定点刻度：100% = 10000 基点
const BP_FULL: int = 10000

var _d: Dictionary = {}
var _c: Dictionary = {}


func _init(derived: Dictionary = {}, combat: Dictionary = {}) -> void:
	_d = derived
	_c = combat


# --- 属性派生 ---

## 实力等级 PL（4.2 节，原文标注 [待 playtest]）。
## 七维总和每高出基准 70 十点算一级，再叠加前五项技能熟练度的均值。
func power_level(attributes: Dictionary, skills: Dictionary) -> int:
	var total: int = 0
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		total += int(attributes.get(attr, 0))
	var from_attributes: int = _round_div(
		total - _geti(_d, "powerLevelAttributeSumBase", 70),
		maxi(1, _geti(_d, "powerLevelAttributeDivisor", 10))
	)
	var levels: Array = []
	for skill_id in skills:
		levels.append(int(skills[skill_id]))
	levels.sort()
	levels.reverse()
	var count: int = mini(_geti(_d, "powerLevelSkillCount", 5), levels.size())
	var sum_top: int = 0
	for i in range(count):
		sum_top += int(levels[i])
	var average: int = 0 if count == 0 else sum_top / count
	var from_skills: int = _round_div(average, maxi(1, _geti(_d, "powerLevelSkillDivisor", 10)))
	return from_attributes + from_skills


func max_hp(attributes: Dictionary, power_level_value: int) -> int:
	return _geti(_d, "hpBase", 30) \
		+ _attr(attributes, PlayerAvatar.ATTR_CONSTITUTION) * _geti(_d, "hpPerConstitution", 8) \
		+ power_level_value * _geti(_d, "hpPerPowerLevel", 4)


func max_mp(attributes: Dictionary) -> int:
	return _geti(_d, "mpBase", 10) \
		+ _attr(attributes, PlayerAvatar.ATTR_INTELLIGENCE) * _geti(_d, "mpPerIntelligence", 4) \
		+ _attr(attributes, PlayerAvatar.ATTR_SOUL) * _geti(_d, "mpPerSoul", 4)


func max_sp(attributes: Dictionary) -> int:
	return _geti(_d, "spBase", 20) \
		+ _attr(attributes, PlayerAvatar.ATTR_CONSTITUTION) * _geti(_d, "spPerConstitution", 3) \
		+ _attr(attributes, PlayerAvatar.ATTR_STRENGTH) * _geti(_d, "spPerStrength", 2)


## 每回合行动点：4 + DEX/20 向下取整（6.1 节）。
func action_points(attributes: Dictionary) -> int:
	var per: int = maxi(1, _geti(_c, "dexPerAp", 20))
	@warning_ignore("integer_division")
	var bonus: int = _attr(attributes, PlayerAvatar.ATTR_DEXTERITY) / per
	return _geti(_c, "apBase", 4) + bonus


## 基础时间单位：100 − DEX×0.8（6.1 节）。越小越先动。
func time_units(attributes: Dictionary) -> int:
	var dex: int = _attr(attributes, PlayerAvatar.ATTR_DEXTERITY)
	var raw: float = float(_geti(_c, "tuBase", 100)) - dex * _getf(_c, "tuPerDex", 0.8)
	return maxi(1, roundi(raw))


# --- 负重 ---

## 负重上限（D-66）。四条来源相加：
##   基础 + 力量×每点 + 负重技能熟练度×每点 + 装备 carryBonus（Equipment 汇总）+ 天赋 carryBonus
## 当前负重由 Equipment.carried_weight 算出；上限在这里算，因为它是派生值，
## 由属性、技能与装备实时重算，不落盘（《技术设计文档》3.3 节）。
func encumbrance_limit(
	attributes: Dictionary,
	skill_level: int,
	equip_carry_bonus: int = 0,
	talent_carry_bonus: int = 0
) -> int:
	return _geti(_d, "encumbranceBase", 20) \
		+ _attr(attributes, PlayerAvatar.ATTR_STRENGTH) * _geti(_d, "encumbrancePerStrength", 3) \
		+ maxi(0, skill_level) * _geti(_d, "encumbrancePerSkillLevel", 1) \
		+ maxi(0, equip_carry_bonus) + maxi(0, talent_carry_bonus)


## 超重的渐进惩罚。不到上限无任何惩罚；超出重量按「超出量 / 上限」的比例放大到
## 各档上限（AP 最多 −N、移动最多 +N、命中最多 −N 基点、TU 最多 +N），所以超得
## 越多越明显，但不硬封锁——AP 与移动永远留着最低值。
## 返回 { over, ratio, apPenalty, movePenalty, hitPenaltyBp, tuPenalty }。
func encumbrance_penalty(current_weight: int, limit: int) -> Dictionary:
	var over: int = maxi(0, current_weight - limit)
	if over == 0:
		return {
			"over": 0, "ratio": 0.0,
			"apPenalty": 0, "movePenalty": 0, "hitPenaltyBp": 0, "tuPenalty": 0,
		}
	# 比例封顶在 1.0：满超载即达各档上限，再超也不涨（渐进但不无限加重）。
	var ratio: float = clampf(float(over) / float(maxi(1, limit)), 0.0, 1.0)
	return {
		"over": over,
		"ratio": ratio,
		"apPenalty": roundi(ratio * float(_geti(_d, "encumbranceApPenaltyMax", 2))),
		"movePenalty": roundi(ratio * float(_geti(_d, "encumbranceMovePenaltyMax", 3))),
		"hitPenaltyBp": roundi(ratio * float(_geti(_d, "encumbranceHitPenaltyMaxBp", 1500))),
		"tuPenalty": roundi(ratio * float(_geti(_d, "encumbranceTuPenaltyMax", 25))),
	}


# --- 命中与暴击 ---

## 技能基础命中 = 50% + 熟练度×0.5%（5.2 节，上限 95% 由钳制负责，不在这里夹）。
func base_hit_bp(skill_level: int) -> int:
	return _geti(_c, "hitBaseBp", 5000) + skill_level * _geti(_c, "hitPerSkillBp", 50)


## 目标闪避 = DEX×0.3 + 装备闪避 + 格挡（6.2 节）。
func dodge_bp(target_attributes: Dictionary, equip_dodge_bp: int = 0, block_bp: int = 0) -> int:
	return _attr(target_attributes, PlayerAvatar.ATTR_DEXTERITY) * _geti(_c, "dodgePerDexBp", 30) \
		+ equip_dodge_bp + block_bp


## 瞄准修正：头部 −20%、躯干 0、四肢 −10%（6.4 节）。返回要从命中里扣掉的基点数。
func aim_hit_penalty_bp(aim_part: String) -> int:
	if PARTS_HEAD.has(aim_part):
		return _geti(_c, "aimHeadHitPenaltyBp", 2000)
	if PARTS_LIMBS.has(aim_part):
		return _geti(_c, "aimLimbHitPenaltyBp", 1000)
	return _geti(_c, "aimTorsoHitPenaltyBp", 0)


## 瞄准的伤害修正（6.4 节）：头部 ×1.5、躯干 ×1.0、四肢 ×0.7。
func aim_damage_factor(aim_part: String) -> float:
	if PARTS_HEAD.has(aim_part):
		return _getf(_c, "aimHeadDamageFactor", 1.5)
	if PARTS_LIMBS.has(aim_part):
		return _getf(_c, "aimLimbDamageFactor", 0.7)
	return _getf(_c, "aimTorsoDamageFactor", 1.0)


## 命中率（6.2 节）：
##   技能基础命中 + PER×0.4 + DEX×0.2 − 目标闪避 − 瞄准惩罚，钳制在 5%–95%。
## 手臂受伤额外扣命中（6.4 节只写了「手→降命中」，幅度由 combat 段给出）。
func hit_chance_bp(
	actor_attributes: Dictionary,
	skill_level: int,
	target_attributes: Dictionary,
	aim_part: String = AIM_TORSO,
	actor_injury: Dictionary = {},
	equip_dodge_bp: int = 0,
	block_bp: int = 0
) -> int:
	var chance: int = base_hit_bp(skill_level)
	chance += _attr(actor_attributes, PlayerAvatar.ATTR_PERCEPTION) * _geti(_c, "hitPerPerceptionBp", 40)
	chance += _attr(actor_attributes, PlayerAvatar.ATTR_DEXTERITY) * _geti(_c, "hitPerDexBp", 20)
	chance -= dodge_bp(target_attributes, equip_dodge_bp, block_bp)
	chance -= aim_hit_penalty_bp(aim_part)
	chance -= arm_hit_penalty_bp(actor_injury)
	return clampi(chance, _geti(_c, "hitMinBp", 500), _geti(_c, "hitMaxBp", 9500))


## 暴击率 = 5% + DEX×0.1% + 技能与装备的暴击修正（6.3 节）。
func crit_chance_bp(attributes: Dictionary, bonus_bp: int = 0) -> int:
	var chance: int = _geti(_c, "critBaseBp", 500) \
		+ _attr(attributes, PlayerAvatar.ATTR_DEXTERITY) * _geti(_c, "critPerDexBp", 10) + bonus_bp
	return clampi(chance, 0, BP_FULL)


## 暴击加成 = 50% + 装备加成（6.3 节）。伤害公式里以 (1 + 该值) 参与。
func crit_damage_bonus_bp(equip_bonus_bp: int = 0) -> int:
	return _geti(_c, "critDamageBaseBp", 5000) + equip_bonus_bp


# --- 伤害 ---

## 技能伤害系数 = 0.5 + 熟练度×0.01（5.2 节）。
func skill_power(skill_level: int) -> float:
	return _getf(_c, "skillPowerBase", 0.5) + skill_level * _getf(_c, "skillPowerPerLevel", 0.01)


## 物理伤害（6.3 节，并按《技能库》1.1 节把技能倍率计入「基础」）：
##   基础 = 武器基础伤害 × 技能倍率 + STR×0.6
##   最终 = 基础 × 技能伤害系数 × 部位修正 × (1 + 暴击加成) − 护甲×(1 − 破甲率)
##
## 伤害下限取 combat.minDamage，原文未定义：加算减法在低阶直观，但若允许负值，
## 短剑砍重甲会变成给他回血。这一条是补充定义，已记入技术设计文档 9.5 节。
func physical_damage(
	attacker_attributes: Dictionary,
	weapon_attack: int,
	skill_level: int,
	skill_multiplier: float,
	target_armor: int,
	armor_pierce: float = 0.0,
	aim_part: String = AIM_TORSO,
	is_crit: bool = false,
	equip_crit_bonus_bp: int = 0
) -> int:
	var strength: int = _attr(attacker_attributes, PlayerAvatar.ATTR_STRENGTH)
	var base: float = float(weapon_attack) * skill_multiplier \
		+ strength * _getf(_c, "strengthDamageFactor", 0.6)
	return _finish_damage(base, skill_level, target_armor, armor_pierce, aim_part,
		is_crit, equip_crit_bonus_bp, 1.0)


## 魔法伤害（6.3 节）：
##   基础 = 法术基础伤害 + INT×0.5 + SOU×0.2（灵魂系额外 + SOU×0.3）
##   最终 = 基础 × 元素克制倍率 × 技能伤害系数 − 魔抗
func magic_damage(
	attacker_attributes: Dictionary,
	spell_base_damage: int,
	skill_level: int,
	target_magic_resist: int,
	damage_type: String,
	element_milli: int = 1000,
	is_crit: bool = false,
	equip_crit_bonus_bp: int = 0
) -> int:
	var intelligence: int = _attr(attacker_attributes, PlayerAvatar.ATTR_INTELLIGENCE)
	var soul: int = _attr(attacker_attributes, PlayerAvatar.ATTR_SOUL)
	var base: float = float(spell_base_damage) \
		+ intelligence * _getf(_c, "intelligenceDamageFactor", 0.5) \
		+ soul * _getf(_c, "soulDamageFactor", 0.2)
	if damage_type == "soul":
		base += soul * _getf(_c, "soulDamageExtraFactor", 0.3)
	return _finish_damage(base, skill_level, target_magic_resist, 0.0,
		AIM_TORSO, is_crit, equip_crit_bonus_bp, float(element_milli) / 1000.0)


## 元素克制倍率（千分比，1000 = 无克制）。《数值框架》6.5 节：
##   水>火>风>土>水 四元素循环：克制 ×elementCounterFactorMilli，被克 ×elementCounteredFactorMilli
##   光<->暗互克 ×holyDarkFactorMilli；魂系按 target_kind ×soulVsUndead/Holy/Living
## target_element 缺省 "physical"（无元素亲和 → 无克制 1000），target_kind 缺省 "living"。
## 之所以是独立函数而不是写死乘区，是因为克制关系需要目标侧信息（元素亲和 / 生物类别）
## 才能判定，放这里既保持"公式全在 DerivedStats"的边界，也方便测试各档倍率。
func element_counter_milli(
	attack_type: String,
	target_element: String = "physical",
	target_kind: String = "living"
) -> int:
	var cycle: Array = _c.get("elementCycle", ["water", "fire", "wind", "earth"])
	var idx: int = cycle.find(attack_type)
	if idx != -1:
		# 前一位是我克制它（attack 克制 cycle[idx-1]），后一位是它克制我
		var countered_by: String = str(cycle[(idx + cycle.size() - 1) % cycle.size()])
		if target_element == countered_by:
			return _geti(_c, "elementCounteredFactorMilli", 750)
		var counters: String = str(cycle[(idx + 1) % cycle.size()])
		if target_element == counters:
			return _geti(_c, "elementCounterFactorMilli", 1500)
		return 1000
	if attack_type == "holy":
		return _geti(_c, "holyDarkFactorMilli", 1500) if target_element == "dark" else 1000
	if attack_type == "dark":
		return _geti(_c, "holyDarkFactorMilli", 1500) if target_element == "holy" else 1000
	if attack_type == "soul":
		match target_kind:
			"undead": return _geti(_c, "soulVsUndeadMilli", 1500)
			"holy": return _geti(_c, "soulVsHolyMilli", 500)
			_: return _geti(_c, "soulVsLivingMilli", 1000)
	return 1000


## 专长被动伤害乘区（千分比）。《技能库》4.5.1 剑/斧/弓专精与 4.5.2 火系亲和都是
## "已学（熟练度 > 0）即生效"的 +10%。按技能树/命分类别匹配，未学返回 1000（无加成）。
func passive_damage_factor_milli(skills: Dictionary, skill: Dictionary) -> int:
	var tree: String = str(skill.get("tree", ""))
	var mapping: Dictionary = {
		"sword": "passive_sword_mastery",
		"axe": "passive_axe_mastery",
		"bow": "passive_bow_mastery",
	}
	if mapping.has(tree) and _learned(skills, str(mapping[tree])):
		return _geti(_c, "masteryFactorMilli", 1100)
	if str(skill.get("category", "")) == "spell" \
		and str(skill.get("damageType", "")) == "fire" \
		and _learned(skills, "passive_fire_affinity"):
		return _geti(_c, "masteryFactorMilli", 1100)
	return 1000


## 专长被动的命中加成（基点）。弓术专精 "+10% 伤害、+5% 命中"里命中那半落到这里；
## 其余专长没有命中项。未学返回 0。
func passive_hit_bonus_bp(skills: Dictionary, skill: Dictionary) -> int:
	if str(skill.get("tree", "")) == "bow" and _learned(skills, "passive_bow_mastery"):
		return _geti(_c, "masteryHitBonusBp", 500)
	return 0


func _learned(skills: Dictionary, id: String) -> bool:
	return int(skills.get(id, 0)) > 0


func _finish_damage(
	base: float,
	skill_level: int,
	target_armor: int,
	armor_pierce: float,
	aim_part: String,
	is_crit: bool,
	equip_crit_bonus_bp: int,
	element_factor: float
) -> int:
	var value: float = base * skill_power(skill_level) * aim_damage_factor(aim_part)
	if is_crit:
		value *= 1.0 + float(crit_damage_bonus_bp(equip_crit_bonus_bp)) / float(BP_FULL)
	value *= element_factor
	# 加算减法：护甲值直接减伤，不与魔抗叠乘区（《技能库》13 节末注）
	var reduction: float = float(target_armor) * (1.0 - clampf(armor_pierce, 0.0, 1.0))
	var final: int = roundi(value - reduction)
	return maxi(_geti(_c, "minDamage", 1), final)


# --- 部位伤 ---

## 手臂受伤扣命中：每级 severity 扣 armHitPenaltyBpPerSeverity 基点，取两臂较重者。
## （6.4 节只写「手→降命中」，幅度未定义，此处补出初值。）
func arm_hit_penalty_bp(body_parts: Dictionary) -> int:
	return _max_severity(body_parts, PARTS_ARM) * _geti(_c, "armHitPenaltyBpPerSeverity", 1000)


## 腿部受伤让移动变贵：每级 severity 多花 legMoveCostPerSeverity 点 AP，取两腿较重者。
## （6.4 节只写「腿→降移速」，幅度未定义。）
func move_cost(body_parts: Dictionary) -> int:
	return 1 + _max_severity(body_parts, PARTS_LEG) * _geti(_c, "legMoveCostPerSeverity", 1)


func max_injury_severity() -> int:
	return maxi(1, _geti(_c, "maxInjurySeverity", 3))


## 头部被击中时的眩晕概率（6.4 节写「概率眩晕」但未给数值）。
func stun_chance_per_mille() -> int:
	return clampi(_geti(_c, "stunChancePerMille", 200), 0, 1000)


## 伤势自然愈合：**未包扎的伤不会自己好**（6.4 节：「残废状态持续到包扎或治疗」）。
## 包扎后每经过 healDaysPerSeverity 天降一级。返回新的部位状态。
func heal_step(part_state: Dictionary, days: int) -> Dictionary:
	var out: Dictionary = part_state.duplicate()
	if not bool(out.get("treated", false)):
		return out
	var per: int = maxi(1, _geti(_c, "healDaysPerSeverity", 3))
	var steps: int = days / per
	if steps <= 0:
		return out
	var severity: int = maxi(0, int(out.get("severity", 0)) - steps)
	out["severity"] = severity
	if severity == 0:
		out["injured"] = false
		out["treated"] = false
	return out


# --- 内部 ---

func _max_severity(body_parts: Dictionary, parts: Array) -> int:
	var worst: int = 0
	for part in parts:
		var state: Dictionary = body_parts.get(part, {})
		if not bool(state.get("injured", false)):
			continue
		worst = maxi(worst, int(state.get("severity", 0)))
	return worst


func _attr(attributes: Dictionary, attribute: String) -> int:
	return int(attributes.get(attribute, 0))


func _geti(cfg: Dictionary, key: String, fallback: int) -> int:
	if not cfg.has(key):
		return fallback
	return int(cfg[key])


func _getf(cfg: Dictionary, key: String, fallback: float) -> float:
	if not cfg.has(key):
		return fallback
	return float(cfg[key])


## 四舍五入的整数除法（避开浮点，也避开 GDScript 整数除法朝零截断）。
static func _round_div(numerator: int, denominator: int) -> int:
	if denominator == 0:
		return 0
	var negative: bool = (numerator < 0) != (denominator < 0)
	var abs_num: int = absi(numerator)
	var abs_den: int = absi(denominator)
	var quotient: int = (abs_num * 2 + abs_den) / (abs_den * 2)
	return -quotient if negative else quotient
