class_name DungeonModifiers
extends RefCounted

## 副本修正词条规则层（M-D / D-138）。
##
## 背景：M-C（大地图可见遗构）在每座遗构上派生了 0–2 条「修正词条」
## （WorldSeen.WORD_POOL），但在 M-D 之前它们只是文案——玩家在地图上读到
## "加了锁的""吵醒过的东西"，走进副本却和没这回事一样。本层把词条从纯文本
## 变成**每层叠深的真实规则**：敌群规模、敌人强度、宝箱数量、掉落稀有度都
## 受词条影响，且深度越深影响越大。
##
## 口径与 CriminalState / StealGate 一致：
##   1. **纯规则、不落盘、可无头测试**。只读 balance.dungeon.modifiers 段
##      与词条 id，不碰 WorldState / ContentLoader。
##   2. **无副作用**。apply 只返回倍率字典，由调用方（main）把倍率并入
##      Dungeon.layout / 怪物生成 / 掉落抽取。

## 缺省叠深系数：每层把词条效果放大 10%。20 层封顶到 3×，不会把数值炸穿。
const DEFAULT_DEPTH_SCALE: float = 0.1
## 叠深上限：词条效果最多放大到这么多倍（线性 clamp）。
const MAX_DEPTH_MULT: float = 3.0


## 把遗构词条数组折算成当前层的一组倍率。
##   words  —— WorldSeen 派生的词条数组：[{id, label, desc}, ...]
##   depth  —— 当前层深（0 起）
##   rules  —— balance.dungeon 段（读 modifiers 子段）
## 返回：
##   { enemyCountMult, enemyStrengthMult, treasureCountMult,
##     lootRarityBias, monsterCategory }
## 无词条或 rules 无 modifiers 段时，全部退到 1× / 0 偏置 / 空类别。
static func apply(words: Array, depth: int, rules: Dictionary) -> Dictionary:
	var mod_rules: Dictionary = rules.get("modifiers", {}) if rules is Dictionary else {}
	var depth_scale: float = float(mod_rules.get("depthScale", DEFAULT_DEPTH_SCALE))
	var depth_mult: float = clampf(
		1.0 + float(maxi(0, depth)) * depth_scale, 1.0, MAX_DEPTH_MULT
	)

	var enemy_count: float = 1.0
	var enemy_str: float = 1.0
	var treasure_count: float = 1.0
	var rarity_bias: float = 0.0
	var monster_category: String = ""

	for word in words:
		if not (word is Dictionary):
			continue
		var wid: String = str((word as Dictionary).get("id", ""))
		if wid.is_empty():
			continue
		var entry: Dictionary = mod_rules.get(wid, {})
		if entry.is_empty():
			continue
		# 每条词条的"强度系数"按深度叠深：depth_mult 把 1× 的效果放大到
		# 最多 MAX_DEPTH_MULT 倍。对倍率类字段是乘法叠加，对偏置类是加法叠加。
		enemy_count *= _scaled_mult(entry, "enemyCountMult", depth_mult)
		enemy_str *= _scaled_mult(entry, "enemyStrengthMult", depth_mult)
		treasure_count *= _scaled_mult(entry, "treasureCountMult", depth_mult)
		rarity_bias += _scaled_bias(entry, "lootRarityBias", depth_mult)
		# 怪物类别偏好：取第一个非空的（词条之间不叠加类别）
		if monster_category.is_empty():
			monster_category = str(entry.get("monsterCategory", ""))

	return {
		"enemyCountMult": enemy_count,
		"enemyStrengthMult": enemy_str,
		"treasureCountMult": treasure_count,
		"lootRarityBias": clampf(rarity_bias, -0.9, 0.9),
		"monsterCategory": monster_category,
	}


## 倍率字段：词条原值 × 深度叠深系数。原值缺省 1.0（不影响）。
static func _scaled_mult(entry: Dictionary, field: String, depth_mult: float) -> float:
	var base: float = float(entry.get(field, 1.0))
	if base == 1.0:
		return 1.0
	# 把"偏离 1 的幅度"按 depth_mult 放大：base=0.6、depth_mult=2 → 0.2（偏离 -0.4 放大到 -0.8）
	return 1.0 + (base - 1.0) * depth_mult


## 偏置字段（稀有度）：原值 × 深度叠深系数。原值缺省 0.0（不偏置）。
static func _scaled_bias(entry: Dictionary, field: String, depth_mult: float) -> float:
	var base: float = float(entry.get(field, 0.0))
	return base * depth_mult
