class_name MonsterVariant
extends RefCounted

## 怪物变体规则层（M34 / M-F / D-150）。
##
## 背景：变体先例只有 DungeonBoss 一处（副本最下层固定《书名号》×2）。本层把
## 「变体」接进**野外遭遇与副本中层**的生物生成：每只怪出生时有概率摇成《书名号》
## 命名单体——常见的书名号档 ×1.25、较稀有的 ×1.67，以及最稀有的「修正」破格档
## ×2–5。名字包书名号、四维按倍率放大、威胁略抬一档。
##
## 口径与 DungeonModifiers 一致：纯规则、不落盘、可无头测试。只读 balance.monsters
## 段与传入的生物表条目/随机源，不碰 WorldState / ContentLoader；变体倍率可与
## 副本修正词条的 enemyStrengthMult 叠加（extra_mult）。

const TITLE_PREFIX: String = "《"
const TITLE_SUFFIX: String = "》"
const BP_FULL: int = 10000


## 掷一次变体判定。读 balance.monsters.variant 段。
##   base  —— 生物表条目（monsters.json 里的先项，需含 displayName/threatLevel/hp/...）
##   rng   —— 随机源（与遭遇/副本会话同支）
##   rules —— balance.monsters 段（内部读 rules.variant）
## 返回：{ isVariant, id, label, mult, name, threatBump }
## 未命中时 { isVariant:false, mult:1.0, name: base.displayName, threatBump:0 }（不改数值）。
static func roll(base: Dictionary, rng: DeterministicRNG, rules: Dictionary) -> Dictionary:
	var variant_rules: Dictionary = rules.get("variant", {}) if rules is Dictionary else {}
	var base_name: String = str(base.get("displayName", ""))
	if rng == null:
		return {
			"isVariant": false, "id": "", "label": "",
			"mult": 1.0, "name": base_name, "threatBump": 0,
		}
	if rng.next_int(BP_FULL) >= int(variant_rules.get("chanceBp", 0)):
		return {
			"isVariant": false, "id": "", "label": "",
			"mult": 1.0, "name": base_name, "threatBump": 0,
		}

	var tiers: Array = variant_rules.get("tiers", [])
	if tiers.is_empty():
		return {
			"isVariant": false, "id": "", "label": "",
			"mult": 1.0, "name": base_name, "threatBump": 0,
		}
	# 按 weightBp 权重挑一档。
	var tier: Dictionary = _pick_tier(tiers, rng)
	var mult: float = _tier_mult(tier, rng)
	# 「修正」破格档更凶，威胁多抬一档；书名号档不抬（它只是同档更强）。
	var bump: int = 1 if str(tier.get("id", "")) != "fix" else 2
	return {
		"isVariant": true,
		"id": str(tier.get("id", "")),
		"label": str(tier.get("label", "")),
		"mult": mult,
		"name": "%s%s%s" % [TITLE_PREFIX, base_name, TITLE_SUFFIX],
		"threatBump": bump,
	}


## 把生物表条目按变体判定放大成对手规格。
##   base      —— 生物表条目副本
##   roll      —— MonsterVariant.roll 的产出
##   extra_mult—— 额外的倍率叠加（副本修正词条 enemyStrengthMult），非副本传 1.0。
## 未命中变体时，只有 extra_mult ≠ 1 才缩放（供副本原样叠修正词条）；命中时乘 mult。
static func apply(base: Dictionary, roll: Dictionary, extra_mult: float = 1.0) -> Dictionary:
	var mult: float = float(roll.get("mult", 1.0)) if bool(roll.get("isVariant", false)) else 1.0
	var total: float = mult * float(extra_mult)
	var out: Dictionary = (base as Dictionary).duplicate(true)
	out["name"] = str(roll.get("name", str(base.get("displayName", ""))))
	out["displayName"] = str(roll.get("name", str(base.get("displayName", ""))))
	if total != 1.0:
		out["hp"] = maxi(1, roundi(float(int(base.get("hp", 0))) * total))
		out["attack"] = maxi(1, roundi(float(int(base.get("attack", 0))) * total))
		out["armor"] = maxi(0, roundi(float(int(base.get("armor", 0))) * total))
		out["magicResist"] = maxi(0, roundi(float(int(base.get("magicResist", 0))) * total))
	if bool(roll.get("isVariant", false)):
		out["threatLevel"] = int(base.get("threatLevel", 1)) + int(roll.get("threatBump", 0))
		out["isVariant"] = true
	return out


## 按权重抽一档变体。
static func _pick_tier(tiers: Array, rng: DeterministicRNG) -> Dictionary:
	var total: int = 0
	for t in tiers:
		if t is Dictionary:
			total += maxi(1, int((t as Dictionary).get("weightBp", 1)))
	var pick: int = rng.next_int(maxi(1, total))
	var cursor: int = 0
	for t in tiers:
		if not (t is Dictionary):
			continue
		cursor += maxi(1, int((t as Dictionary).get("weightBp", 1)))
		if pick < cursor:
			return (t as Dictionary).duplicate()
	return (tiers[0] as Dictionary).duplicate() if not tiers.is_empty() else {}


## 该档的倍率：有 multMin/multMax 的按区间掷（「修正」档 ×2–5），否则用固定 mult。
static func _tier_mult(tier: Dictionary, rng: DeterministicRNG) -> float:
	if tier.has("mult"):
		return float(tier.get("mult", 1.0))
	var lo: int = roundi(float(tier.get("multMin", 2.0)) * 100.0)
	var hi: int = roundi(float(tier.get("multMax", 5.0)) * 100.0)
	return float(rng.range_int(lo, hi)) / 100.0