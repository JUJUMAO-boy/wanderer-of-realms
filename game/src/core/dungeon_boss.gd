class_name DungeonBoss
extends RefCounted

## 副本 BOSS 规则层（M-D / D-139）。
##
## 背景：M21 的副本有 20 层深，但最底层只是"再往下已经到头"的死胡同——
## 玩家清完怪捡完宝箱就只能离开，没有终点感。本层给副本一个**终点 BOSS**：
## 最下层沉睡着一头《书名号》巨兽，进去先公告、给撤退机会，击杀掉宝石/尸体/
## 全装备三件套。
##
## 口径与 DungeonModifiers 一致：纯规则、不落盘、可无头测试。BOSS 不是新表，
## 而是从 monsters.json 抽一只高 TL 怪放大数值、名字包书名号——同一只怪加
## 《》就是 BOSS（D-139）。

## BOSS 名字的书名号前缀/后缀。
const TITLE_PREFIX: String = "《"
const TITLE_SUFFIX: String = "》"


## 这一层是不是 BOSS 层：最底层（depth == maxDepth - 1）。
static func is_boss_floor(depth: int, max_depth: int) -> bool:
	var md: int = maxi(1, max_depth)
	return maxi(0, depth) == md - 1


## 构造一只 BOSS 对手（单只）。
##   rules     —— balance.dungeon 段（读 boss 子段）
##   depth     —— 当前层深（用于 BOSS 名后缀，让同种子不同深度的 BOSS 可区分）
##   rng       —— 随机源（从 boss.templates 里选基底）
##   modifiers —— DungeonModifiers.apply 的产出（叠 enemyStrengthMult）
## 返回：{ title, opponents:[unit] }，结构与 main._dungeon_monster_spec 对齐，
##       供 EncounterSystem.units_of 消费。templates 为空或找不到怪时返回 {}。
static func boss_spec(
	rules: Dictionary, depth: int, rng: DeterministicRNG, modifiers: Dictionary
) -> Dictionary:
	var boss_rules: Dictionary = rules.get("boss", {}) if rules is Dictionary else {}
	var templates: Array = boss_rules.get("templates", [])
	if templates.is_empty() or rng == null:
		return {}
	var stat_mult: Dictionary = boss_rules.get("statMult", {})

	# 从 monsters.json 找到 templates 里指定的基底怪（第一个命中的）。
	var base: Dictionary = {}
	for tpl in templates:
		var mid: String = str(tpl)
		base = _find_monster(mid)
		if not base.is_empty():
			break
	if base.is_empty():
		# 兜底：从 templates 里取第一个，找不到就退空
		return {}

	var str_mult: float = float(modifiers.get("enemyStrengthMult", 1.0)) if modifiers is Dictionary else 1.0
	var hp_mult: float = float(stat_mult.get("hp", 1.0)) * str_mult
	var atk_mult: float = float(stat_mult.get("attack", 1.0)) * str_mult
	var arm_mult: float = float(stat_mult.get("armor", 1.0)) * str_mult
	var mr_mult: float = float(stat_mult.get("magicResist", 1.0)) * str_mult

	var base_name: String = str(base.get("displayName", ""))
	var boss_name: String = "%s%s%s" % [TITLE_PREFIX, base_name, TITLE_SUFFIX]
	var base_tl: int = int(base.get("threatLevel", 1))

	var opponent: Dictionary = {
		"unitId": "dungeon-boss-d%d" % depth,
		"name": boss_name,
		"displayName": boss_name,
		"category": str(base.get("category", "")),
		"threatLevel": base_tl + 2,  # BOSS 比同层怪高一档，掉落更好
		"attributes": (base.get("attributes", {}) as Dictionary).duplicate(),
		"hp": maxi(1, roundi(float(int(base.get("hp", 1))) * hp_mult)),
		"armor": maxi(0, roundi(float(int(base.get("armor", 0))) * arm_mult)),
		"magicResist": maxi(0, roundi(float(int(base.get("magicResist", 0))) * mr_mult)),
		"attack": maxi(1, roundi(float(int(base.get("attack", 1))) * atk_mult)),
		"attackRange": int(base.get("attackRange", 1)),
		"parleyable": false,
		"isNpc": false,
		"npcId": "",
	}
	return {"title": boss_name, "opponents": [opponent]}


## BOSS 击杀必掉的三件套：宝石、尸体材料、一件保底稀有以上装备。
## 返回 templateId 数组（顺序：宝石、尸体、装备），供 main 直接入包。
static func boss_loot(
	rules: Dictionary, rng: DeterministicRNG, modifiers: Dictionary
) -> Array:
	var boss_rules: Dictionary = rules.get("boss", {}) if rules is Dictionary else {}
	var out: Array = []

	var gem: String = str(boss_rules.get("gemTemplateId", ""))
	if not gem.is_empty():
		out.append(gem)
	var corpse: String = str(boss_rules.get("corpseTemplateId", ""))
	if not corpse.is_empty():
		out.append(corpse)

	# 一件保底稀有以上装备：从 weapon/armor 里按 rarity >= floor 抽。
	var floor: String = str(boss_rules.get("equipmentRarityFloor", "rare"))
	var rarity_bias: float = float(modifiers.get("lootRarityBias", 0.0)) if modifiers is Dictionary else 0.0
	var equip: String = _pick_equipment(floor, rarity_bias, rng)
	if not equip.is_empty():
		out.append(equip)
	return out


## 从 monsters.json 里找指定 monsterId 的条目。
static func _find_monster(monster_id: String) -> Dictionary:
	for m in ContentLoader.get_monsters():
		if not (m is Dictionary):
			continue
		if str((m as Dictionary).get("monsterId", "")) == monster_id:
			return (m as Dictionary).duplicate()
	return {}


## 按稀有度门槛从 weapon/armor 里抽一件装备。rarity_bias 把门槛往上抬（最高 epic）。
static func _pick_equipment(
	rarity_floor: String, rarity_bias: float, rng: DeterministicRNG
) -> String:
	if rng == null:
		return ""
	var order: Array = ["common", "fine", "rare", "epic", "legendary", "dragonforged"]
	var floor_idx: int = order.find(rarity_floor)
	if floor_idx < 0:
		floor_idx = order.find("rare")
	# 偏置把稀有度门槛往上抬（最多两档），让词条深的副本掉更好的装备。
	var bias_shift: int = clampi(roundi(rarity_bias * 2.0), 0, 2)
	var target_idx: int = mini(order.size() - 1, floor_idx + bias_shift)
	var target_rarity: String = str(order[target_idx])

	var pool: Array = []
	var fallback: Array = []
	for item in ContentLoader.get_items():
		if not (item is Dictionary):
			continue
		var tpl: Dictionary = item as Dictionary
		var cat: String = str(tpl.get("category", ""))
		if cat != "weapon" and cat != "armor":
			continue
		var rid: String = str(tpl.get("rarity", "common"))
		if rid == target_rarity:
			pool.append(tpl)
		elif order.find(rid) >= floor_idx:
			fallback.append(tpl)
	var chosen: Dictionary = {}
	if not pool.is_empty():
		chosen = pool[rng.next_int(pool.size())]
	elif not fallback.is_empty():
		chosen = fallback[rng.next_int(fallback.size())]
	if chosen.is_empty():
		return ""
	return str(chosen.get("templateId", ""))
