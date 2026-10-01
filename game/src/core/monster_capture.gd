class_name MonsterCapture
extends RefCounted

## 怪物捕捉规则层（M34 / M-F / D-151）。
##
## 在战斗中对**残血野兽**掷出收容笼（低血投掷 + 等级上限）。四道拒收红线：
## 生灵/对话体（isNpc 或 category==humanoid）、有声名（isVariant 或名字包书名号）、
## 神性（divine）拒收；TL 高于 captureMaxThreatLevel 超上限。失败恒吃两条代价：
## deviceLost（笼毁）+ enrage（兽被激怒，本回合遭一次缩放反扑）。
##
## 口径与 MonsterVariant 一致：纯规则、不落盘、可无头测试。只读 balance.monsters
## 段与传入的对手 dict / 随机源，不碰 WorldState；机械后果（扣笼、入包、落标记、
## 反扑打点）由 main 调用方就地结清。

const BP_FULL: int = 10000

## 拒收红线对应的理由文案。
const REASON_STILL_BREATHING: String = "它还有气力，笼不让收躁动的东西"
const REASON_THREAT_CAP: String = "它太凶，笼子装不下"


## 判断一只单位能不能被捕捉。返回空串=可收；否则返回拒收理由。
## 必须传齐字段：threatLevel、hp/maxHp、isNpc、isVariant、divine、category。
static func is_capturable(unit: Dictionary, rules: Dictionary) -> String:
	if unit.is_empty():
		return "没有这个目标"
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	# 生灵/对话体不收
	if bool(unit.get("isNpc", false)) \
		or str(unit.get("category", "")) == "humanoid":
		return "生灵有言语，收不进笼"
	# 有声名的（变体《书名号》）不收
	if bool(unit.get("isVariant", false)) \
		or str(unit.get("name", "")).contains(MonsterVariant.TITLE_PREFIX):
		return "有声名的东西收不得"
	# 神性不收
	if bool(unit.get("divine", false)):
		return "神性不容纳"
	# 等级上限
	if int(unit.get("threatLevel", 0)) \
		> int(capture_rules.get("captureMaxThreatLevel", 10)):
		return REASON_THREAT_CAP
	return ""


## 低血够格：当前 HP 占比不超过 lowHpRatioThreshold 才值得掷（否则目标界面置灰）。
static func low_hp_eligible(unit: Dictionary, rules: Dictionary) -> bool:
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	var max_hp: int = maxi(1, int(unit.get("maxHp", 1)))
	var ratio: float = float(int(unit.get("hp", 0))) / float(max_hp)
	return ratio <= float(capture_rules.get("lowHpRatioThreshold", 0.5))


## 低血投掷成功率（基点 0–10000）。缺口越多越容易：baseBp + (1 − hp/maxHp) × perMissingRatioBp，
## 钳至 capBp；TL 每高出档基再多扣 perThreatPenaltyBp。
static func chance_bp(unit: Dictionary, rules: Dictionary) -> int:
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	var max_hp: int = maxi(1, int(unit.get("maxHp", 1)))
	var ratio: float = clampf(float(int(unit.get("hp", 0))) / float(max_hp), 0.0, 1.0)
	var chance: int = int(capture_rules.get("baseBp", 4500)) \
		+ roundi((1.0 - ratio) * float(capture_rules.get("perMissingRatioBp", 6000)))
	var threat: int = int(unit.get("threatLevel", 0))
	var cap: int = int(capture_rules.get("captureMaxThreatLevel", 10))
	if threat > cap:
		chance -= int(capture_rules.get("perThreatPenaltyBp", 350)) * (threat - cap)
	if chance > int(capture_rules.get("capBp", 9500)):
		chance = int(capture_rules.get("capBp", 9500))
	return clampi(chance, 0, BP_FULL)


## 给定一次掷值判定成败（纯函数，便于无头钉测）。
## 返回 { ok, captured, chanceBp, rollBp, consequences:[...], reason }。
## 失败 consequences 恒 ≥2 条：["deviceLost", "enrage"]。
static func outcome(unit: Dictionary, rules: Dictionary, roll_bp: int) -> Dictionary:
	var chance: int = chance_bp(unit, rules)
	var captured: bool = roll_bp < chance
	return {
		"ok": true,
		"captured": captured,
		"chanceBp": chance,
		"rollBp": maxi(0, roll_bp),
		"consequences": [] if captured else ["deviceLost", "enrage"],
		"reason": "" if captured else REASON_STILL_BREATHING,
	}


## 用随机源掷一次捕捉。
static func attempt(unit: Dictionary, rules: Dictionary, rng: DeterministicRNG) -> Dictionary:
	var source: DeterministicRNG = rng if rng != null else DeterministicRNG.new(20261001)
	return outcome(unit, rules, source.next_int(BP_FULL))


## 收容成功后的容器物件（balance.monsters.capture.containedTemplateId），记录被收躯体。
## 返回可直接交付 CharacterCreation.add_item 的实例字典。
static func contained_item(unit: Dictionary, rules: Dictionary, instance_id: String) -> Dictionary:
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	return {
		"templateId": str(capture_rules.get("containedTemplateId", "creature_caged")),
		"instanceId": instance_id,
		"modifiers": {
			"kind": "captured_monster",
			"monsterId": str(unit.get("monsterId", "")),
			"displayName": str(unit.get("displayName", str(unit.get("name", "")))),
			"variant": bool(unit.get("isVariant", false)),
			"threatLevel": int(unit.get("threatLevel", 0)),
		},
	}


## 收容装置模板 id（balance.monsters.capture.consumeTemplateId）。
static func device_template(rules: Dictionary) -> String:
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	return str(capture_rules.get("consumeTemplateId", "consumable_capture_cage"))


## 收容装置的抛掷范围（格）。
static func throw_range(rules: Dictionary) -> int:
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	return maxi(1, int(capture_rules.get("captureThrowRange", 2)))


## 收容装置的行动点消耗。
static func ap_cost(rules: Dictionary) -> int:
	var capture_rules: Dictionary = rules.get("capture", {}) if rules is Dictionary else {}
	return maxi(1, int(capture_rules.get("captureApCost", 3)))