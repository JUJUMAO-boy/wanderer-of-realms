class_name Gathering
extends RefCounted

## 野外采集规则层（M14）。在城郊/野外的固定观测点执行一次采集：按该点的产出表
## （itemId → weight）取一件主掉物，产量 1..yieldMax，并把对应生产技能熟练 +1。
##
## 与 Crafting 同一条边界：只看化身背包与熟练度，就地改 avatar 并返回改动摘要。
## 产出表挂在 recipes.json 的 gathers 数组里（采集技能 mine/lumber/herb）。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"

const GATHER_SKILLS: Array = ["mine", "lumber", "herb"]

var _spots: Dictionary = {}
var _templates: Dictionary = {}
var _item_rule: ItemInstance = null


## 直接用当前配置装配。
static func create() -> Gathering:
	var g := Gathering.new()
	var templates: Dictionary = {}
	for entry in ContentLoader.get_items():
		if entry is Dictionary:
			templates[str((entry as Dictionary).get("templateId", ""))] = entry
	g._templates = templates
	for spot in ContentLoader.get_gathers():
		if spot is Dictionary:
			g._spots[str((spot as Dictionary).get("spotId", ""))] = spot
	g._item_rule = ItemInstance.create_from_config()
	return g


func _init(spots: Dictionary = {}, templates: Dictionary = {}, item_rule: ItemInstance = null) -> void:
	_spots = spots
	_templates = templates
	_item_rule = item_rule if item_rule != null else (ItemInstance.create(templates) if not templates.is_empty() else null)


func spot(spot_id: String) -> Dictionary:
	var value: Variant = _spots.get(spot_id, null)
	return value if value is Dictionary else {}


func template(template_id: String) -> Dictionary:
	var value: Variant = _templates.get(template_id, null)
	return value if value is Dictionary else {}


## 能否在此采集（要点存在、有化身）。返回 {can, reason, spotId}。
func can_gather(avatar, spot_id: String) -> Dictionary:
	var spot: Dictionary = self.spot(spot_id)
	var result: Dictionary = { "can": false, "reason": ERROR_NONE, "spotId": spot_id }
	if spot.is_empty():
		result["reason"] = "没有这个采集点"
		return result
	if avatar == null or not (avatar is PlayerAvatar):
		result["reason"] = "没有化身"
		return result
	result["can"] = true
	return result


## 执行一次采集。seed_text 决定产出（同一段种子永远采到同一件），供测试复现。
## avatar 就地被改（产出入包、熟练 +1）。返回 {ok, errorCode, error, skill,
## gainedSkills, produced}。
func gather(avatar, spot_id: String, seed_text: String) -> Dictionary:
	var spot: Dictionary = self.spot(spot_id)
	if spot.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这个采集点：%s" % spot_id)
	if avatar == null or not (avatar is PlayerAvatar):
		return _fail(ERROR_PRECONDITION_FAILED, "没有化身")
	var skill: String = str(spot.get("skill", ""))

	var outputs: Array = _array_of(spot.get("outputs", []))
	if outputs.is_empty():
		return _fail(ERROR_PRECONDITION_FAILED, "采集点没有产出表")
	var total_weight: int = 0
	for drop in outputs:
		if drop is Dictionary:
			total_weight += maxi(1, int((drop as Dictionary).get("weight", 0)))
	var rng := DeterministicRNG.new(ItemInstance.seed_from_text(seed_text))
	var roll: int = rng.next_int(total_weight)
	var picked: Dictionary = {}
	var acc: int = 0
	for drop in outputs:
		if not (drop is Dictionary):
			continue
		acc += maxi(1, int((drop as Dictionary).get("weight", 0)))
		if roll < acc:
			picked = drop
			break
	if picked.is_empty():
		return _fail(ERROR_PRECONDITION_FAILED, "采集点产出表无法命中")

	var yield_max: int = maxi(1, int(spot.get("yieldMax", 1)))
	var yield_count: int = rng.range_int(1, yield_max)
	var item_id: String = str(picked.get("itemId", ""))
	var tmp: Dictionary = template(item_id)
	var instance_id: String = ""
	var make_id := func() -> String:
		if instance_id != "":
			return instance_id
		instance_id = _make_instance_id(avatar)
		return instance_id
	for _i in range(yield_count):
		var instance: Dictionary = bare_instance(item_id)
		_register(avatar, make_id.call(), instance)

	var gained: Dictionary = _skill_level_gain(avatar, skill)
	return {
		"ok": true, "skill": skill, "gainedSkills": gained,
		"produced": [{
			"instanceId": instance_id, "templateId": item_id,
			"displayName": str(tmp.get("displayName", item_id)), "count": yield_count,
		}],
	}


## 平值白板实例（采集产的基础材料，不摇词缀也不爬档）。
func bare_instance(template_id: String) -> Dictionary:
	var out: Dictionary
	if _item_rule != null:
		out = _item_rule.bare_instance(template_id)
	else:
		out = { "templateId": template_id, "durability": 0, "enhancement": 0, "modifiers": [] }
	out["craftRarity"] = str(template(template_id).get("rarity", "common"))
	return out


func _skill_level_gain(avatar, skill: String) -> Dictionary:
	var level: int = clampi(int(avatar.skills.get(skill, 0)) + 1, 0, 100)
	avatar.skills[skill] = level
	return { skill: 1 }


func _register(avatar, instance_id: String, instance: Dictionary) -> void:
	avatar.item_instances[instance_id] = instance
	avatar.inventory.append(instance_id)


func _make_instance_id(avatar) -> String:
	var seq: int = avatar.inventory.size() + 1
	var candidate: String = "%s-gather-%03d" % [str(avatar.avatar_id), seq]
	while avatar.item_instances.has(candidate):
		seq += 1
		candidate = "%s-gather-%03d" % [str(avatar.avatar_id), seq]
	return candidate


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []


static func _fail(error_code: String, message: String) -> Dictionary:
	return { "ok": false, "errorCode": error_code, "error": message }