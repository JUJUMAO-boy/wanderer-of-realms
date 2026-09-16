class_name CraftingViewModel
extends RefCounted

## 制作台界面的视图模型（M14 表现层）。
##
## 与其它视图模型同一个理由："面板该显示什么"是纯函数，能在无头环境里被验收
## 测试钉住；"怎么画"留给面板。
##
## 它把三件事翻译成人话：
##   1. 配方按生产技能归组，每张配方显示熟练门槛 / 当前熟练 / 材料清单（缺多少）。
##   2. 一行能不能做：can_craft 给 {can, reason}，界面据此置灰并给不可用原因。
##   3. 装备类产物的档位随熟练爬梯，这里把 craft_rarity 的结果直接写进行里，
##      让"造出的剑是哪个档"在动手前就看得见。

const SKILL_LABELS: Dictionary = {
	"forge": "锻造", "alchemy": "炼金", "cooking": "烹饪",
	"enchant": "附魔", "herb": "采药", "mine": "采矿", "lumber": "伐木",
}
const RARITY_LABELS: Dictionary = {
	"common": "普通", "fine": "精良", "rare": "稀有", "epic": "史诗",
	"legendary": "传奇", "dragonforged": "龙魂",
}

## 制作台视图。crafting 是规则层，lookups.itemTemplates 供名称解析，
## cursor 指到那张配方行（界面高亮用）。
static func build(crafting, avatar, lookups: Dictionary, cursor: int = 0) -> Dictionary:
	var rows: Array = []
	var row_index: int = 0
	for recipe in ContentLoader.get_recipes():
		if not (recipe is Dictionary):
			continue
		var state: Dictionary = crafting.can_craft(avatar, str((recipe as Dictionary).get("recipeId", "")))
		var row: Dictionary = _recipe_row(recipe, avatar, crafting, lookups, state)
		rows.append(row)
		if row_index == cursor:
			row["selected"] = true
		row_index += 1

	var gather_rows: Array = []
	for spot in ContentLoader.get_gathers():
		if not (spot is Dictionary):
			continue
		var can: Dictionary = _can_gather(crafting, avatar, str((spot as Dictionary).get("spotId", "")))
		gather_rows.append({
			"spotId": str((spot as Dictionary).get("spotId", "")),
			"displayName": str((spot as Dictionary).get("displayName", "")),
			"skill": str((spot as Dictionary).get("skill", "")),
			"skillLabel": str(SKILL_LABELS.get(str((spot as Dictionary).get("skill", "")), "")),
			"outputText": str((spot as Dictionary).get("effectText", "")),
			"can": bool(can.get("can", false)),
			"reason": str(can.get("reason", "")),
		})

	return {
		"rows": rows,
		"gather": gather_rows,
		"craftRarity": crafting.craft_rarity(0 if avatar == null else int(avatar.skills.get("forge", 0))),
	}


static func _can_gather(crafting, avatar, spot_id: String) -> Dictionary:
	# 采集与制造共用同一套"有化身才有得做"的判定，这里直接探一层。
	if avatar == null or not (avatar is PlayerAvatar):
		return { "can": false, "reason": "没有化身" }
	return { "can": true, "reason": "" }


## 单张配方行：门槛 / 材料 / 产物 / 档位 / 可做与否与原因。
static func _recipe_row(recipe: Dictionary, avatar, crafting, lookups: Dictionary, state: Dictionary) -> Dictionary:
	var recipe_id: String = str(recipe.get("recipeId", ""))
	var skill: String = str(recipe.get("skill", ""))
	var level: int = 0 if avatar == null else int(avatar.skills.get(skill, 0))
	var templates: Dictionary = _lookup(lookups, "itemTemplates")
	var materials: Array = []
	for ing in recipe.get("ingredients", []):
		if not (ing is Dictionary):
			continue
		var item_id: String = str((ing as Dictionary).get("itemId", ""))
		materials.append({
			"itemId": item_id,
			"displayName": str(templates.get(item_id, {}).get("displayName", item_id)),
			"need": int((ing as Dictionary).get("count", 0)),
			"have": _count(avatar, item_id),
			"short": _count(avatar, item_id) < int((ing as Dictionary).get("count", 0)),
		})

	var kind: String = str(recipe.get("kind", ""))
	var output_text: String = ""
	if kind == "enchant":
		output_text = str(recipe.get("effectText", ""))
	else:
		var out: Array = recipe.get("outputs", [])
		if not out.is_empty() and (out[0] is Dictionary):
			var item_id: String = str((out[0] as Dictionary).get("itemId", ""))
			var base: Dictionary = templates.get(item_id, {})
			var rarity: String = crafting.craft_rarity(level) \
				if ContentLoader.ITEM_EQUIP_CATEGORIES.has(str(base.get("category", ""))) \
				else str(base.get("rarity", "common"))
			output_text = "%s ×%d（%s）" % [
				str(base.get("displayName", item_id)),
				int((out[0] as Dictionary).get("count", 1)),
				str(RARITY_LABELS.get(rarity, rarity)),
			]

	return {
		"recipeId": recipe_id,
		"displayName": str(recipe.get("displayName", recipe_id)),
		"kind": kind,
		"skill": skill,
		"skillLabel": str(SKILL_LABELS.get(skill, "")),
		"requiredLevel": int(recipe.get("requiredLevel", 0)),
		"skillLevel": level,
		"gate": level >= int(recipe.get("requiredLevel", 0)),
		"materials": materials,
		"outputText": output_text,
		"enabled": bool(state.get("can", false)),
		"reason": str(state.get("reason", "")),
	}


static func _count(avatar, template_id: String) -> int:
	var total: int = 0
	if avatar == null:
		return 0
	for held in avatar.inventory:
		var instance: Dictionary = avatar.item_instances.get(held, {})
		if str(instance.get("templateId", "")) == template_id:
			total += 1
	return total


static func _lookup(tables: Dictionary, key: String) -> Dictionary:
	var value: Variant = tables.get(key, null)
	return value if value is Dictionary else {}