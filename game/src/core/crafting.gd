class_name Crafting
extends RefCounted

## 生产制作规则层（M14）。把「消耗原料 → 产出物品」这条制造执行补上——M8 只有
## 买货 + 就地强化(forge +5) + 三档修理，没有一处真的去扣原料、造新件。
##
## 边界与 ItemInstance / Economy 一致：这是规则层，只看玩家自己的化身与背包，
## 不碰城市六维、不提交 StateChange。纯函数化——玩家私有状态（背包、实例表、
## 生产技能熟练度）由调用方以 avatar 传入，本层就地改 avatar 并返回改动摘要。
##
## 三个 M14 设计决策在这里：
##   - 全链路：craft 也能产中间材料与成品；enchant 就地给实例追加词条。
##   - 熟练度复用 avatar.skills（skillId → 0..100），每成功造一件 +1 钳 100。
##   - 成品稀有度随熟练爬升：craft_rarity 定档并把装备类产物的模板抬到对应档位。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"

## 熟练度 → 成品档位的阶梯（《数值框架》第 8 章、计划 M14 决策三）。
const RARITY_LADDER: Array = ["common", "fine", "rare", "epic", "legendary"]
const RARITY_THRESHOLDS: Array = [0, 40, 55, 70, 85]

## 会随熟练爬档的产物类别。材料/消耗品固定模板档，不爬。
const CLIMB_CATEGORIES: Array = ["weapon", "armor"]

var _templates: Dictionary = {}
var _recipes: Dictionary = {}
var _item_rule: ItemInstance = null


## 直接用当前配置装配。craft 的配方与素材都来自 ContentLoader。
static func create() -> Crafting:
	var c := Crafting.new()
	var templates: Dictionary = {}
	for entry in ContentLoader.get_items():
		if entry is Dictionary:
			templates[str((entry as Dictionary).get("templateId", ""))] = entry
	c._templates = templates
	c._recipes = _index_by(ContentLoader.get_recipes(), "recipeId")
	c._item_rule = ItemInstance.create_from_config()
	return c


static func _index_by(list: Array, key: String) -> Dictionary:
	var out: Dictionary = {}
	for entry in list:
		if entry is Dictionary:
			out[str((entry as Dictionary).get(key, ""))] = entry
	return out


func _init(templates: Dictionary = {}, recipes: Dictionary = {}, item_rule: ItemInstance = null) -> void:
	_templates = templates
	_recipes = recipes
	_item_rule = item_rule if item_rule != null else (ItemInstance.create(templates) if not templates.is_empty() else null)


func recipe(recipe_id: String) -> Dictionary:
	var value: Variant = _recipes.get(recipe_id, null)
	return value if value is Dictionary else {}


func template(template_id: String) -> Dictionary:
	var value: Variant = _templates.get(template_id, null)
	return value if value is Dictionary else {}


# --- 制造成品档位 ---

## 按熟练度定档：0/40/55/70/85 → common/fine/rare/epic/legendary。
func craft_rarity(skill_level: int) -> String:
	var chosen: String = RARITY_LADDER[0]
	for i in range(RARITY_LADDER.size()):
		if int(skill_level) >= RARITY_THRESHOLDS[i]:
			chosen = RARITY_LADDER[i]
	return chosen


## 把装备产物按已定档的稀有度抬到对应模板；变体不存在（如匕首没有 fine 档）时
## 退回基础模板，避免"造出空气"。非装备产物一律原样返回。
func resolve_output_template(base_template_id: String, rarity: String) -> String:
	var base: Dictionary = template(base_template_id)
	var category: String = str(base.get("category", ""))
	if not CLIMB_CATEGORIES.has(category) or rarity == "common":
		return base_template_id
	var idx: int = base_template_id.rfind("_common")
	if idx < 0:
		return base_template_id
	var prefix: String = base_template_id.substr(0, idx)
	var candidate: String = "%s_%s" % [prefix, rarity]
	return candidate if _templates.has(candidate) else base_template_id


# --- 门槛查询（给 UI 与测试） ---

## 能否做这件：熟练度达标 && 每味材料都够。返回 {can, reason, missing, recipeId}。
func can_craft(avatar, recipe_id: String) -> Dictionary:
	var recipe: Dictionary = recipe(recipe_id)
	var result: Dictionary = {
		"can": false, "reason": ERROR_NONE, "missing": [],
		"recipeId": recipe_id,
	}
	if recipe.is_empty():
		result["reason"] = "没有这张配方"
		return result
	if avatar == null or not (avatar is PlayerAvatar):
		result["reason"] = "没有化身"
		return result
	var skill: String = str(recipe.get("skill", ""))
	var threshold: int = int(recipe.get("requiredLevel", 0))
	if _skill_level(avatar, skill) < threshold:
		result["reason"] = "熟练度不足（需要 %d），当前 %d" % [
			threshold, _skill_level(avatar, skill)
		]
		return result
	var missing: Array = _missing(avatar, recipe.get("ingredients", []))
	if not missing.is_empty():
		result["missing"] = missing
		var first: Dictionary = missing[0]
		result["reason"] = "材料不足：缺 %s×%d（现有 %d）" % [
			str(first.get("displayName", "")), int(first.get("need", 0)),
			int(first.get("have", 0)),
		]
		return result
	result["can"] = true
	return result


func _skill_level(avatar, skill: String) -> int:
	return int(avatar.skills.get(skill, 0)) if avatar != null else 0


## 逐味材料算缺多少。返回 [{itemId, displayName, need, have}]。
func _missing(avatar, ingredients: Array) -> Array:
	var out: Array = []
	for ing in ingredients:
		if not (ing is Dictionary):
			continue
		var item_id: String = str((ing as Dictionary).get("itemId", ""))
		var need: int = int((ing as Dictionary).get("count", 0))
		var have: int = _count_template(avatar, item_id)
		if have < need:
			out.append({
				"itemId": item_id,
				"displayName": str(template(item_id).get("displayName", item_id)),
				"need": need,
				"have": have,
			})
	return out


# --- 制造执行 ---

## 执行一次制造。avatar 就地被改（扣料、产出入包、熟练 +1）。
## 返回 {ok, errorCode, error, skill, gainedSkills, consumed, produced}。
## 对 kind=enchant 配方，需传 target_instance_id（被附魔的那件实例）。
func craft(avatar, recipe_id: String, target_instance_id: String = "") -> Dictionary:
	var recipe: Dictionary = recipe(recipe_id)
	if recipe.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这张配方：%s" % recipe_id)
	if avatar == null or not (avatar is PlayerAvatar):
		return _fail(ERROR_PRECONDITION_FAILED, "没有化身")
	var skill: String = str(recipe.get("skill", ""))
	var threshold: int = int(recipe.get("requiredLevel", 0))
	if _skill_level(avatar, skill) < threshold:
		return _fail(ERROR_PRECONDITION_FAILED, "熟练度不足：需要 %d，当前 %d" % [
			threshold, _skill_level(avatar, skill)
		])

	# 材料在改变 avatar 之前先整体清点一次，避免造到一半料不够。
	var missing: Array = _missing(avatar, recipe.get("ingredients", []))
	if not missing.is_empty():
		var first: Dictionary = missing[0]
		return _fail(ERROR_PRECONDITION_FAILED, "材料不足：缺 %s×%d（现有 %d）" % [
			str(first.get("displayName", "")), int(first.get("need", 0)),
			int(first.get("have", 0)),
		])

	if str(recipe.get("kind", "")) == "enchant":
		return _craft_enchant(avatar, recipe, skill, target_instance_id)
	return _craft_produce(avatar, recipe, skill)


## 造物资类产物（含中间材料与消耗品）：扣料，逐件产出并登记实例。
func _craft_produce(avatar, recipe: Dictionary, skill: String) -> Dictionary:
	var consumed: Array = _record_consumed(recipe)
	for ing in _array_of(recipe.get("ingredients", [])):
		if ing is Dictionary:
			_take_template(avatar, str((ing as Dictionary).get("itemId", "")), int((ing as Dictionary).get("count", 0)))

	var rarity: String = craft_rarity(_skill_level(avatar, skill))
	var produced: Array = []
	var seq: int = 1
	for out in _array_of(recipe.get("outputs", [])):
		if not (out is Dictionary):
			continue
		var base_id: String = str((out as Dictionary).get("itemId", ""))
		var count: int = int((out as Dictionary).get("count", 1))
		for _i in range(count):
			var tpl_id: String = resolve_output_template(base_id, rarity)
			var tmp: Dictionary = template(tpl_id)
			var effective_rarity: String = rarity if CLIMB_CATEGORIES.has(str(tmp.get("category", ""))) else str(tmp.get("rarity", "common"))
			var instance: Dictionary
			if _item_rule == null:
				instance = { "templateId": tpl_id, "durability": 0, "enhancement": 0, "modifiers": [] }
			elif CLIMB_CATEGORIES.has(str(tmp.get("category", ""))):
				var seed_text: String = "craft|%s|%s|#%d" % [str(avatar.avatar_id), tpl_id, seq]
				instance = _item_rule.new_instance(tpl_id, seed_text)
			else:
				instance = _item_rule.bare_instance(tpl_id)
			instance["craftRarity"] = effective_rarity
			var instance_id: String = _register(avatar, instance)
			produced.append({
				"instanceId": instance_id, "templateId": tpl_id,
				"displayName": str(tmp.get("displayName", tpl_id)), "rarity": effective_rarity,
			})
			seq += 1

	var gained: Dictionary = _gain_skill(avatar, skill)
	return {
		"ok": true, "skill": skill, "gainedSkills": gained,
		"consumed": consumed, "produced": produced,
	}


## 附魔产物：就地给 target 实例追加词条（walk 复用 Modifier 的 target/value 口径）。
func _craft_enchant(avatar, recipe: Dictionary, skill: String, target_instance_id: String) -> Dictionary:
	if target_instance_id.is_empty() or not avatar.item_instances.has(target_instance_id):
		return _fail(ERROR_PRECONDITION_FAILED, "附魔需要指定一件目标实例")
	var instance: Dictionary = avatar.item_instances[target_instance_id]
	var tmp: Dictionary = template(str(instance.get("templateId", "")))
	var applies_to: String = str(recipe.get("appliesTo", ""))
	if not applies_to.is_empty() and str(tmp.get("category", "")) != applies_to:
		return _fail(ERROR_PRECONDITION_FAILED, "该实例类别（%s）不匹配 %s" % [
			str(tmp.get("category", "")), applies_to
		])

	var consumed: Array = _record_consumed(recipe)
	for ing in _array_of(recipe.get("ingredients", [])):
		if ing is Dictionary:
			_take_template(avatar, str((ing as Dictionary).get("itemId", "")), int((ing as Dictionary).get("count", 0)))

	var mods: Array = _modifiers_from(tmp, instance.get("modifiers", []), recipe)
	instance["modifiers"] = mods

	var gained: Dictionary = _gain_skill(avatar, skill)
	return {
		"ok": true, "skill": skill, "gainedSkills": gained,
		"consumed": consumed, "produced": [],
		"target": { "instanceId": target_instance_id, "templateId": str(instance.get("templateId", "")), "rarity": str(tmp.get("rarity", "common")) },
	}


## 把配方里的 modifiers 换算成实例可读的词条。ratioBp 是百分比基点（1000 = 100%），
## 按目标模板 target_template 的同名基值折算成整数 value（如"攻击 +10%"折成该武器
## 基值 ×10%）；value 字段则是平值直接落。追加 affixId 标识附魔来源。
func _modifiers_from(target_template: Dictionary, existing: Array, recipe: Dictionary) -> Array:
	var out: Array = existing.duplicate()
	for mod in _array_of(recipe.get("modifiers", [])):
		if not (mod is Dictionary):
			continue
		var target: String = str((mod as Dictionary).get("target", ""))
		var value: int = 0
		var ratio_bp: int = int((mod as Dictionary).get("ratioBp", 0))
		if ratio_bp > 0:
			var base: int = int(target_template.get(target, 0))
			value = int(round(float(base) * float(ratio_bp) / 1000.0))
		if value <= 0:
			value = int((mod as Dictionary).get("value", 0))
		if value <= 0:
			continue
		out.append({
			"affixId": "enchant:%s" % str(recipe.get("recipeId", "")),
			"target": target, "value": value,
		})
	return out


func _record_consumed(recipe: Dictionary) -> Array:
	var out: Array = []
	for ing in _array_of(recipe.get("ingredients", [])):
		if ing is Dictionary:
			var item_id: String = str((ing as Dictionary).get("itemId", ""))
			out.append({ "itemId": item_id, "count": int((ing as Dictionary).get("count", 0)) })
	return out


func _gain_skill(avatar, skill: String) -> Dictionary:
	var level: int = clampi(_skill_level(avatar, skill) + 1, 0, 100)
	avatar.skills[skill] = level
	return { skill: 1 }


# --- 背包操作 ---

## 背包里有几件指定模板（每格一件，计数即模板命中数）。
func _count_template(avatar, template_id: String) -> int:
	var count: int = 0
	for held in avatar.inventory:
		var instance: Dictionary = avatar.item_instances.get(held, {})
		if str(instance.get("templateId", "")) == template_id:
			count += 1
	return count


## 从背包拿走 count 件指定模板（按序位摘）。数量不足时只拿走有的那部分。
func _take_template(avatar, template_id: String, count: int) -> void:
	var need: int = count
	var taken: Array = []
	for i in range(avatar.inventory.size()):
		if need <= 0:
			break
		var held: String = str(avatar.inventory[i])
		var instance: Dictionary = avatar.item_instances.get(held, {})
		if str(instance.get("templateId", "")) == template_id:
			taken.append(held)
			need -= 1
	for held in taken:
		avatar.inventory.erase(held)
		avatar.item_instances.erase(held)


## 登记一件新实例并返回它的 id（与 Economy._make_instance_id 同款取号方式，
## 只是前缀换成 -craft-）。
func _register(avatar, instance: Dictionary) -> String:
	var instance_id: String = _make_instance_id(avatar)
	avatar.item_instances[instance_id] = instance
	avatar.inventory.append(instance_id)
	return instance_id


func _make_instance_id(avatar) -> String:
	var seq: int = avatar.inventory.size() + 1
	var candidate: String = "%s-craft-%03d" % [str(avatar.avatar_id), seq]
	while avatar.item_instances.has(candidate):
		seq += 1
		candidate = "%s-craft-%03d" % [str(avatar.avatar_id), seq]
	return candidate


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []


static func _fail(error_code: String, message: String) -> Dictionary:
	return { "ok": false, "errorCode": error_code, "error": message }