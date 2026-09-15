class_name Equipment
extends RefCounted

## 装备槽与穿戴（《技术设计文档》3.3 节 PLAYER_AVATAR 的 equipment 字段）。
##
## 那个字段在文档里只有一句 `map<slot,itemInstanceId>`：槽位叫什么、哪件货进哪个槽、
## 双手武器怎么算，一处也没写（见《技术设计文档》D-50）。这一层把这几条规则收拢：
##   - 某件物品进哪个槽，写在 items.json 的 slot 上；槽位清单与双手槽在 balance.equipment
##   - 穿上 / 脱下 / 换下来：被替换的那件放回背包——绝不让玩家身上的东西消失
##   - 双手武器（hands == 2）连同 twoHandedSlots 里的另一个槽一起占住
##
## 与 Economy 同一条边界：这里改的是**玩家自己**的行装（equipment 与 inventory），
## 不碰城市六维，因此既不提交 StateChange、也不等月末。玩家侧当场生效，是 10.1 节
## 第 2 条留出的口子（它约束的是城市，不是玩家的钱与背包，见 D-47）。
##
## 穿戴不设属性门槛：《数值框架》只在派生值清单里提过一句"负重上限"，既没给公式
## 也没给每件装备的负担口径，见 D-51。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"

## 双手武器的判定阈：items.json 的 hands。写成常量而不是散在各处的字面量 2。
const HANDS_TWO: int = 2

var _slots: Array = []
var _labels: Dictionary = {}
var _two_handed: Array = []
var _templates: Dictionary = {}
## 实例层规则（词缀、强化、耐久）。装备的数值从这里取，不直接读模板——
## 同一把"普通长剑"强化过与没强化过，穿在身上的效果必须不一样（D-54）。
var _rules: ItemInstance = null


## 从 ContentLoader 取规则、从调用方取物品模板表。模板表由外面传进来（与
## AvatarViewModel 收 lookups 同一条理由）：测试可以塞一个小样本进来，
## 不必背一份完整配置，也就不必为了测"双手武器占副手"去配一件真的盾。
static func create(templates: Dictionary, rules: ItemInstance = null) -> Equipment:
	return Equipment.new(ContentLoader.get_balance_section("equipment"), templates, rules)


func _init(cfg: Dictionary = {}, templates: Dictionary = {}, rules: ItemInstance = null) -> void:
	_slots = _array_of(cfg.get("slots", null))
	_labels = _dict_of(cfg.get("slotLabels", null))
	_two_handed = _array_of(cfg.get("twoHandedSlots", null))
	_templates = templates
	_rules = rules if rules != null else ItemInstance.create(templates)


# --- 规则查询 ---

## 槽位清单，按配置里的次序（界面照它从上往下画）。
func slots() -> Array:
	return _slots.duplicate()


func slot_label(slot: String) -> String:
	return str(_labels.get(slot, slot))


func two_handed_slots() -> Array:
	return _two_handed.duplicate()


func has_slot(slot: String) -> bool:
	return _slots.has(slot)


## 一件物品进哪个槽。不占槽位的（消耗品）返回空串。
func slot_of(template_id: String) -> String:
	return str(template(template_id).get("slot", ""))


func template(template_id: String) -> Dictionary:
	var value: Variant = _templates.get(template_id, null)
	return value if value is Dictionary else {}


## 实例层规则。界面要写"精良长剑 +2 · 锋锐 +3 攻击"时走它，而不是自己再读
## 一遍配置——两处各读一份，规则一旦变就会分叉。
func rules() -> ItemInstance:
	return _rules


## 某个实例在存档里的那一份记录。读档前的老存档可能没有 durability 与
## modifiers，取值的地方一律带缺省，所以这里原样返回。
func instance_of(avatar: PlayerAvatar, instance_id: String) -> Dictionary:
	if avatar == null:
		return {}
	var value: Variant = avatar.item_instances.get(instance_id, null)
	return value if value is Dictionary else {}


## 这件东西能不能穿。不能穿的只有一种情况：它不属于任何槽位（药水、干粮）。
## 槽位被占、双手冲突都不算拒绝——换装会把旧的放回背包，那不是"穿不上"。
func can_equip(template_id: String) -> bool:
	return _slots.has(slot_of(template_id))


## 某个槽里现在挂着哪一件（返回实例 id）。挂在槽里但实例已不在的旧记录当作空槽。
func equipped_instance(avatar: PlayerAvatar, slot: String) -> String:
	if avatar == null:
		return ""
	var held: String = str(avatar.equipment.get(slot, ""))
	return held if avatar.item_instances.has(held) else ""


func equipped_template(avatar: PlayerAvatar, slot: String) -> Dictionary:
	var instance_id: String = equipped_instance(avatar, slot)
	if instance_id.is_empty():
		return {}
	return template_of_instance(avatar, instance_id)


func is_equipped(avatar: PlayerAvatar, instance_id: String) -> bool:
	if avatar == null or instance_id.is_empty():
		return false
	for slot in avatar.equipment:
		if str(avatar.equipment[slot]) == instance_id:
			return true
	return false


## 被双手武器占住的槽：槽 → 占着它的实例 id。空字典表示身上没有双手武器。
##
## 界面照它把那个槽写成"被 XX 占着"，而不是"（空）"——同一个空槽，
## 一种是"你还没放东西"，另一种是"你现在放不了"，玩家得能分清。
func blocked_slots(avatar: PlayerAvatar) -> Dictionary:
	var out: Dictionary = {}
	if avatar == null:
		return out
	for slot in _two_handed:
		var instance_id: String = equipped_instance(avatar, str(slot))
		if instance_id.is_empty():
			continue
		if int(template_of_instance(avatar, instance_id).get("hands", 1)) != HANDS_TWO:
			continue
		for other in _two_handed:
			if str(other) != str(slot):
				out[str(other)] = instance_id
	return out


## 这一身现在能打能扛多少。只算**穿在身上**的，背包里的一律不算——
## 这正是这个模块存在的理由：在这之前，战斗与称号折算都是"背包里攻击最高的武器
## + 所有防具的护甲之和"，于是买一把更好的剑还没穿就生效了（见 D-52）。
##
## 数值取自实例：同一件模板，强化过的与没强化过的、带词缀的与白板的，
## 穿在身上必须不一样。
func loadout(avatar: PlayerAvatar) -> Dictionary:
	var out: Dictionary = {
		"weapon": {},
		"attack": 0,
		"attackRange": 0,
		"hands": 0,
		"armor": 0,
		"magicResist": 0,
		"rows": [],
	}
	if avatar == null:
		return out
	for slot in _slots:
		var instance_id: String = equipped_instance(avatar, str(slot))
		if instance_id.is_empty():
			continue
		var instance: Dictionary = instance_of(avatar, instance_id)
		var entry_template: Dictionary = template(str(instance.get("templateId", "")))
		var stats: Dictionary = _rules.effective_stats(instance)
		out["rows"].append({
			"slot": str(slot),
			"instanceId": instance_id,
			"templateId": str(entry_template.get("templateId", "")),
			"displayName": _rules.display_name(instance),
		})
		if str(entry_template.get("category", "")) == "weapon":
			out["weapon"] = entry_template
			out["attack"] = int(stats[ItemInstance.STAT_ATTACK])
			out["attackRange"] = int(stats[ItemInstance.STAT_ATTACK_RANGE])
			out["hands"] = int(stats[ItemInstance.STAT_HANDS])
		out["armor"] = int(out["armor"]) + int(stats[ItemInstance.STAT_ARMOR])
		out["magicResist"] = int(out["magicResist"]) \
			+ int(stats[ItemInstance.STAT_MAGIC_RESIST])
	return out


## 身上装备带来的七维加成之和。派生值（生命、魔力、闪避……）要用"带上装备之后"
## 的属性算，否则"戴一件 +2 体质的护符"在面板上一个数字都不会变。
func attribute_bonus(avatar: PlayerAvatar) -> Dictionary:
	var out: Dictionary = {}
	if avatar == null:
		return out
	for slot in _slots:
		var instance_id: String = equipped_instance(avatar, str(slot))
		if instance_id.is_empty():
			continue
		var bonus: Dictionary = _rules.attribute_bonus(instance_of(avatar, instance_id))
		for attribute in bonus:
			var key: String = str(attribute)
			out[key] = int(out.get(key, 0)) + int(bonus[attribute])
	return out


## 一身的数值摘要，界面与战斗都要（战斗读 loadout，面板读这一份）。
func summary(avatar: PlayerAvatar) -> Dictionary:
	var loadout_value: Dictionary = loadout(avatar)
	loadout_value["attributes"] = attribute_bonus(avatar)
	return loadout_value


# --- 穿 / 脱 ---

## 穿上一件（实例 id）。返回 {ok, slot, instanceId, replaced}。
##
## 冲突时**拒绝**，不替玩家卸下另一件：穿与脱都是玩家明确的动作，"本来只想换副手，
## 结果主手的弓没了"比多按一次回车糟得多。同一个槽上的替换是例外——那是玩家在做
## 同一件事（换掉手上的这把），旧的放回背包即可。
func equip(avatar: PlayerAvatar, instance_id: String) -> Dictionary:
	if avatar == null:
		return _fail(ERROR_PRECONDITION_FAILED, "还没有化身，穿不上东西")
	if is_equipped(avatar, instance_id):
		return _fail(ERROR_PRECONDITION_FAILED, "这件已经穿在身上了")
	if not avatar.inventory.has(instance_id):
		return _fail(ERROR_NOT_FOUND, "背包里没有这件东西：%s" % instance_id)

	var entry_template: Dictionary = template_of_instance(avatar, instance_id)
	var label: String = _label_of(avatar, instance_id)
	var slot: String = str(entry_template.get("slot", ""))
	if not _slots.has(slot):
		return _fail(ERROR_INVALID_ARGUMENT, "%s 不是能穿在身上的东西" % label)

	var conflict: String = _conflict_with(avatar, slot, entry_template, label)
	if not conflict.is_empty():
		return _fail(ERROR_PRECONDITION_FAILED, conflict)

	# 同一个槽上的旧货先回背包，再把新的挂上去
	var replaced: String = _unequip_slot(avatar, slot)
	avatar.inventory.erase(instance_id)
	avatar.equipment[slot] = instance_id
	return {
		"ok": true,
		"errorCode": ERROR_NONE,
		"error": "",
		"slot": slot,
		"slotLabel": slot_label(slot),
		"instanceId": instance_id,
		"displayName": label,
		"replaced": replaced,
	}


## 穿上这件会不会与身上的东西打架，返回冲突说明（空串表示不冲突）。
## 两种情形都是同一件事的两面：双手武器占两只手。
func _conflict_with(
	avatar: PlayerAvatar, slot: String, entry_template: Dictionary, label: String
) -> String:
	if int(entry_template.get("hands", 1)) == HANDS_TWO:
		for other in _two_handed:
			var other_slot: String = str(other)
			if other_slot == slot:
				continue
			var held: String = equipped_instance(avatar, other_slot)
			if held.is_empty():
				continue
			return "%s 要占两只手：先把%s上的「%s」卸下" % [
				label,
				slot_label(other_slot),
				_label_of(avatar, held),
			]
		return ""
	# 反方向：目标槽可能正被一件双手武器占着
	for holder in _two_handed:
		var holder_slot: String = str(holder)
		if holder_slot == slot:
			continue
		var holder_id: String = equipped_instance(avatar, holder_slot)
		if holder_id.is_empty():
			continue
		var holder_template: Dictionary = template_of_instance(avatar, holder_id)
		if int(holder_template.get("hands", 1)) != HANDS_TWO:
			continue
		return "%s 被「%s」占着：那是双手武器，先把它卸下" % [
			slot_label(slot), _label_of(avatar, holder_id)
		]
	return ""


## 脱下某个槽上的东西，放回背包。返回 {ok, slot, instanceId}。
func unequip(avatar: PlayerAvatar, slot: String) -> Dictionary:
	if avatar == null:
		return _fail(ERROR_PRECONDITION_FAILED, "还没有化身，脱不下东西")
	if not _slots.has(slot):
		return _fail(ERROR_INVALID_ARGUMENT, "没有这个装备槽：%s" % slot)
	var instance_id: String = equipped_instance(avatar, slot)
	if instance_id.is_empty():
		return _fail(ERROR_NOT_FOUND, "%s 上是空的" % slot_label(slot))
	_unequip_slot(avatar, slot)
	return {
		"ok": true,
		"errorCode": ERROR_NONE,
		"error": "",
		"slot": slot,
		"slotLabel": slot_label(slot),
		"instanceId": instance_id,
		"displayName": _label_of(avatar, instance_id),
	}


## 把槽清空并把东西放回背包，返回被放回的那一件（空槽返回空串）。
##
## 放回而不是丢弃：穿戴是误触代价最小的操作，而"东西没了"是玩家最不能接受的
## 失败方式。已经指向不存在实例的旧记录顺手清掉——那种记录会让槽看起来是占着的。
func _unequip_slot(avatar: PlayerAvatar, slot: String) -> String:
	var instance_id: String = equipped_instance(avatar, slot)
	avatar.equipment.erase(slot)
	if instance_id.is_empty():
		return ""
	if not avatar.inventory.has(instance_id):
		avatar.inventory.append(instance_id)
	return instance_id


# --- 内部 ---

## 某个实例的模板。缺模板时返回空字典，调用方给出的名字会退化成实例 id。
func template_of_instance(avatar: PlayerAvatar, instance_id: String) -> Dictionary:
	var instance: Dictionary = avatar.item_instances.get(instance_id, {})
	return template(str(instance.get("templateId", "")))


## 界面上写什么名字。走实例层——有强化等级就带上（"精良长剑 +2"）。
## 面板、商铺与状态行写的必须是同一个名字，不然同一件货三处三个样子。
func _label_of(avatar: PlayerAvatar, instance_id: String) -> String:
	var instance: Dictionary = instance_of(avatar, instance_id)
	if instance.is_empty():
		return instance_id
	return _rules.display_name(instance)


static func _fail(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "errorCode": error_code, "error": message}


## 配置里显式写 null 时 Dictionary.get 的缺省值不生效，所以判型要显式做一次。
static func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []
