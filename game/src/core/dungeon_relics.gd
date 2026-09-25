class_name DungeonRelics
extends RefCounted

## 副本专属遗物规则层（M32 副本纵深·C / D-145）。
##
## 背景：副本宝箱此前只在 weapon/armor/consumable 里抽，没有任何"只有下本能
## 搞到"的独有收益。本层新增 `relic` 类别装备模板（items.json），并给出抽法：
## 普通楼层宝箱在深处有小概率抽成遗物，隐藏暗室 treasure 房**必掉**一件。
##
## 口径与 DungeonBoss 一致：纯规则、可无头钉测；模板读 ContentLoader.get_items()
## 中 `category=="relic"` 的条目。数值全走 balance.dungeon.relics 段（D-145：
## 遗物只出副本——宝箱/暗室/BOSS 口，别处没有，保"下本的独有收益"）。

## 遗物类别标识（与 items.json 里的 category 对齐）。
const CATEGORY: String = "relic"


## 取出全部遗物模板（category=="relic"）。
static func templates() -> Array:
	var out: Array = []
	for item in ContentLoader.get_items():
		if not (item is Dictionary):
			continue
		if str((item as Dictionary).get("category", "")) == CATEGORY:
			out.append(item)
	return out


## 普通楼层宝箱的遗物抽签：按 depth 分档取 chanceBp（浅层低、深处高），叠词条
## lootRarityBias 抬高；命中在遗物池抽一件 templateId，未命中回 ""。
static func roll_for(depth: int, rng: DeterministicRNG, modifiers: Dictionary) -> String:
	if rng == null:
		return ""
	var pool: Array = templates()
	if pool.is_empty():
		return ""
	var rules: Dictionary = ContentLoader.get_balance_section("dungeon")
	var relics_cfg: Dictionary = rules.get("relics", {}) if rules is Dictionary else {}
	var tier_depth: Array = relics_cfg.get("tierDepth", [6, 12])
	var chances: Array = relics_cfg.get("chanceBp", [300, 700, 1500])
	var tier: int = 0
	var d: int = maxi(0, depth)
	if d >= int(tier_depth[tier_depth.size() - 1]):
		tier = tier_depth.size()  # 最深处走最后一档的更高值
	elif d >= int(tier_depth[0]):
		tier = 1
	var chance: int = int(chances[clampi(mini(tier, chances.size() - 1), 0, chances.size() - 1)])
	var bias: float = float(modifiers.get("lootRarityBias", 0.0)) if modifiers is Dictionary else 0.0
	# 词条偏置把命中概率往上抬（每 +0.1 偏置 ≈ +100 基点）。
	chance += clampi(roundi(bias * 1000.0), 0, 4000)
	if rng.next_int(10000) >= chance:
		return ""
	return str(pool[rng.next_int(pool.size())].get("templateId", ""))


## 隐藏暗室 treasure 房使用的必掉抽签：不判概率，在遗物池里确定抽一件。
## 偏置越高越可能抽到靠后的（更高档）遗物。
static func guaranteed(rng: DeterministicRNG, modifiers: Dictionary = {}) -> String:
	if rng == null:
		return ""
	var pool: Array = templates()
	if pool.is_empty():
		return ""
	var bias: float = float(modifiers.get("lootRarityBias", 0.0)) if modifiers is Dictionary else 0.0
	var rank: int = clampi(roundi(bias * 2.0), 0, maxi(0, pool.size() - 1)) \
		if pool.size() > 0 else 0
	# 从靠后的（更高档）截取窗口，保底仍覆盖池底。
	var start: int = mini(rank, pool.size() - 1)
	var local: Array = pool.slice(start)
	var picked: Dictionary = local[rng.next_int(local.size())]
	return str(picked.get("templateId", ""))