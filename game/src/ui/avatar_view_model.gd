class_name AvatarViewModel
extends RefCounted

## 角色面板的视图模型（M6.2「含角色面板、背包、任务列表、对话」里的前两项）。
##
## 与 CityViewModel 同一个理由：把"面板该显示什么"与"怎么画"分开，
## 前者是纯函数，能在无头环境下被验收测试钉住。
##
## 名字解析走调用方传入的一张查询表，不直接读 ContentLoader——
## 这样测试可以塞小样本进去，不必背一份完整配置。
##
## 查询表用一个大字典而不是五个并排的参数：并排的字典参数在调用处全长得一样，
## 传错顺序编译器一句话都不会说，而症状是"面板上某处显示成了 ID"。
## 键名：skillNames / talentNames / itemTemplates / cityNames / raceNames。
const LOOKUP_KEYS: Array = [
	"skillNames", "talentNames", "itemTemplates", "cityNames", "raceNames",
]

## 属性档位（《数值框架》2.1 节）
const ATTRIBUTE_TIERS: Array = [
	{"max": 5, "label": "羸弱"},
	{"max": 20, "label": "普通"},
	{"max": 40, "label": "精悍"},
	{"max": 60, "label": "强者"},
	{"max": 85, "label": "传奇"},
	{"max": 9999, "label": "破限"},
]

## 技能阶位（《技能库》1.3 节）
const SKILL_TIERS: Array = [
	{"max": 20, "label": "入门"},
	{"max": 40, "label": "熟练"},
	{"max": 60, "label": "精通"},
	{"max": 80, "label": "大师"},
	{"max": 100, "label": "宗师"},
]

## 稀有度显示名（《数值框架》8 节）
const RARITY_LABELS: Dictionary = {
	"common": "普通", "fine": "精良", "rare": "稀有",
	"epic": "史诗", "legendary": "传奇", "dragonforged": "龙魂",
}

const GENDER_LABELS: Dictionary = {"male": "男", "female": "女"}

## 光标的两段：先装备槽，再背包。一个光标走完两段（而不是每段一个），
## 因为玩家的动作是同一件事的两个方向——"这件穿上"与"那件脱下"。
const CURSOR_KIND_SLOT: String = "slot"
const CURSOR_KIND_BAG: String = "bag"


## equipment 与 cursor 是这一轮（装备槽）加进来的：面板从"只能看"变成"能动手"，
## 于是需要一个光标，而光标要落在哪一行、那一行是什么，属于"该显示什么"，
## 一并归视图模型管。equipment 为 null 时退化成只有背包（老调用方与部分测试）。
static func build(
	avatar: PlayerAvatar,
	derived: DerivedStats,
	lookups: Dictionary,
	location: String = "",
	equipment: Equipment = null,
	cursor: int = 0
) -> Dictionary:
	if avatar == null:
		return {}
	var skill_names: Dictionary = _lookup(lookups, "skillNames")
	var talent_names: Dictionary = _lookup(lookups, "talentNames")
	var item_templates: Dictionary = _lookup(lookups, "itemTemplates")
	var city_names: Dictionary = _lookup(lookups, "cityNames")
	var race_names: Dictionary = _lookup(lookups, "raceNames")
	var race_label: String = str(race_names.get(avatar.race, avatar.race))

	# 装备带来的七维加成。属性行与派生值都要用"穿上之后"的属性算——
	# 否则"戴一件 +2 体质的护符"在面板上一个数字都不会变（D-54）。
	var bonus: Dictionary = equipment.attribute_bonus(avatar) if equipment != null else {}
	var effective: Dictionary = avatar.attributes.duplicate()
	for attribute in bonus:
		var key: String = str(attribute)
		effective[key] = int(effective.get(key, 0)) + int(bonus[key])

	var power: int = derived.power_level(effective, avatar.skills)
	var attribute_rows: Array = []
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		var base_value: int = avatar.get_attribute(attr)
		var attr_bonus: int = int(bonus.get(attr, 0))
		var value: int = base_value + attr_bonus
		attribute_rows.append({
			"key": attr,
			"label": str(PlayerAvatar.ATTRIBUTE_LABELS.get(attr, attr)),
			"value": value,
			"baseValue": base_value,
			"bonus": attr_bonus,
			"valueLabel": str(value) if attr_bonus == 0 \
				else "%d（%d%+d）" % [value, base_value, attr_bonus],
			"tierLabel": tier_label(value, ATTRIBUTE_TIERS),
			"bar": clampf(float(value) / 100.0, 0.0, 1.0),
		})

	var derived_rows: Array = [
		row("最大生命", derived.max_hp(effective, power)),
		row("最大魔力", derived.max_mp(effective)),
		row("最大耐力", derived.max_sp(effective)),
		row("每轮行动点", derived.action_points(effective)),
		row("时间单位 TU", derived.time_units(effective)),
		row("实力等级 PL", power),
		row("闪避（基点）", derived.dodge_bp(effective)),
	]

	var talent_rows: Array = []
	for talent_id in avatar.talents:
		talent_rows.append(entry_row(str(talent_id), talent_names, "天赋"))
	for flaw_id in avatar.flaws:
		talent_rows.append(entry_row(str(flaw_id), talent_names, "缺陷"))

	var skill_rows: Array = []
	var skill_ids: Array = avatar.skills.keys()
	skill_ids.sort()
	for skill_id in skill_ids:
		var level: int = int(avatar.skills[skill_id])
		skill_rows.append({
			"key": str(skill_id),
			"label": str(skill_names.get(str(skill_id), str(skill_id))),
			"level": level,
			"tierLabel": tier_label(level, SKILL_TIERS),
			"bar": clampf(float(level) / 100.0, 0.0, 1.0),
		})

	var equipment_rows: Array = []
	if equipment != null:
		equipment_rows = _equipment_rows(avatar, equipment, item_templates)

	var inventory_rows: Array = []
	for instance_id in avatar.inventory:
		var instance: Dictionary = avatar.item_instances.get(instance_id, {})
		var template_id: String = str(instance.get("templateId", ""))
		var template: Dictionary = _template(item_templates, template_id)
		var slot: String = str(template.get("slot", ""))
		var equippable: bool = equipment != null and not slot.is_empty()
		var row: Dictionary = _plain_item_row(instance_id, template_id, template) \
			if equipment == null \
			else instance_info(equipment.rules(), instance, template)
		row["instanceId"] = str(instance_id)
		row["templateId"] = template_id
		row["equippable"] = equippable
		row["slotLabel"] = equipment.slot_label(slot) if equippable else ""
		inventory_rows.append(row)

	var total: int = equipment_rows.size() + inventory_rows.size()
	cursor = clampi(cursor, 0, maxi(0, total - 1))
	var selected: Dictionary = {}
	if total > 0:
		selected = _slot_selection(equipment_rows[cursor]) if cursor < equipment_rows.size() \
			else _bag_selection(inventory_rows[cursor - equipment_rows.size()])

	return {
		"displayName": avatar.display_name,
		"raceLabel": race_label,
		"backgroundLabel": avatar.background_id,
		"genderLabel": str(GENDER_LABELS.get(avatar.gender, avatar.gender)),
		"age": avatar.age,
		"location": location,
		"identityLine": "%s · %s · %d 岁" % [
			str(GENDER_LABELS.get(avatar.gender, avatar.gender)), race_label, avatar.age
		],
		"attributeRows": attribute_rows,
		"derivedRows": derived_rows,
		"talentRows": talent_rows,
		"skillRows": skill_rows,
		"equipmentRows": equipment_rows,
		"inventoryRows": inventory_rows,
		"cursor": cursor,
		"rowCount": total,
		"selected": selected,
		"actionLine": str(selected.get("actionLine", "")),
		"moneyLabel": _money_label(avatar.money),
		"debtLabel": _money_label(avatar.debt_copper),
		"luck": avatar.luck,
		"karma": avatar.karma,
		"reputationRows": _reputation_rows(avatar, city_names),
		"legacyRows": _legacy_rows(avatar),
		"hasLegacy": not avatar.legacy.is_empty(),
	}


## 光标落在哪一段。面板按它把高亮画到正确的栏里（槽位在左栏、背包在右栏）。
static func cursor_kind(view: Dictionary, cursor: int) -> String:
	var slots: Array = view.get("equipmentRows", [])
	if cursor < 0:
		return ""
	return CURSOR_KIND_SLOT if cursor < slots.size() else CURSOR_KIND_BAG


## 光标落在背包里的第几行（槽位行返回 −1）。
static func bag_index_of(view: Dictionary, cursor: int) -> int:
	var slots: Array = view.get("equipmentRows", [])
	return cursor - slots.size() if cursor >= slots.size() else -1


## 统一光标序号 → 槽位行序号（不是槽位行返回 −1）。
static func slot_index_of(view: Dictionary, cursor: int) -> int:
	var slots: Array = view.get("equipmentRows", [])
	return cursor if cursor >= 0 and cursor < slots.size() else -1


## 装备槽的行。空槽与"被双手武器占着"都各占一行——同一个空槽，
## 一种是"你还没放东西"，另一种是"你现在放不了"，玩家得能分清。
static func _equipment_rows(
	avatar: PlayerAvatar, equipment: Equipment, item_templates: Dictionary
) -> Array:
	var blocked: Dictionary = equipment.blocked_slots(avatar)
	var rules: ItemInstance = equipment.rules()
	var rows: Array = []
	for slot in equipment.slots():
		var slot_name: String = str(slot)
		var instance_id: String = equipment.equipped_instance(avatar, slot_name)
		var blocker: String = str(blocked.get(slot_name, ""))
		var row: Dictionary = {
			"slot": slot_name,
			"slotLabel": equipment.slot_label(slot_name),
			"empty": instance_id.is_empty(),
			"blocked": not blocker.is_empty(),
			"blockedBy": "",
		}
		if not blocker.is_empty():
			row["blockedBy"] = rules.display_name(equipment.instance_of(avatar, blocker))
		# 有货的槽走同一份实例信息（背包行也是它）：两处各拼一次的话，
		# "精良长剑 +2 · 锋锐 +3 攻击"这条规则会慢慢漂成两套
		if not instance_id.is_empty():
			var instance: Dictionary = equipment.instance_of(avatar, instance_id)
			row.merge(
				instance_info(rules, instance, _template(item_templates,
					str(instance.get("templateId", "")))),
				true
			)
		rows.append(row)
	return rows


## 没有实例规则时的退化行（老调用方与部分测试只传 avatar + derived，没有 Equipment）。
static func _plain_item_row(
	instance_id: String, template_id: String, template: Dictionary
) -> Dictionary:
	var label: String = str(template.get("displayName", template_id))
	return {
		"instanceId": str(instance_id),
		"templateId": template_id,
		"label": label,
		"templateLabel": label,
		"rarityLabel": str(RARITY_LABELS.get(str(template.get("rarity", "")), "—")),
		"detail": item_detail(template),
		"enhancement": 0,
		"enhancementLabel": "",
		"affixText": "",
		"affixRows": [],
		"durabilityText": "",
	}


## 一件实例要显示的那几项。角色面板的装备槽、背包，商铺的卖出列表与铁匠铺
## 都要写"精良长剑 +2 / 锋锐 +3 攻击 / 耐久 100/100"，四处各拼一次的话，
## 同一件货在不同界面上会长得不一样。
static func instance_info(
	rules: ItemInstance, instance: Dictionary, template: Dictionary
) -> Dictionary:
	var level: int = rules.enhancement(instance)
	return {
		"label": rules.display_name(instance),
		"templateLabel": str(template.get("displayName", instance.get("templateId", ""))),
		"rarityLabel": str(RARITY_LABELS.get(str(template.get("rarity", "")), "—")),
		"detail": item_detail(template, rules.effective_stats(instance)),
		"enhancement": level,
		"enhancementLabel": "" if level <= 0 else "+%d" % level,
		"affixText": rules.affix_text(instance),
		"affixRows": rules.affix_rows(instance),
		"durabilityText": rules.durability_text(instance),
	}


static func _slot_selection(row: Dictionary) -> Dictionary:
	if row.is_empty():
		return {}
	var label: String = str(row.get("slotLabel", ""))
	if bool(row.get("blocked", false)):
		return {
			"kind": CURSOR_KIND_SLOT, "slot": str(row.get("slot", "")),
			"label": label, "canAct": false,
			"actionLine": "%s 现在腾不出来：被%s占着，先把它脱下" % [
				label, str(row.get("blockedBy", "双手武器"))
			],
		}
	if bool(row.get("empty", false)):
		return {
			"kind": CURSOR_KIND_SLOT, "slot": str(row.get("slot", "")),
			"label": label, "canAct": false,
			"actionLine": "%s 空着。在背包里选一件，回车穿上。" % label,
		}
	return {
		"kind": CURSOR_KIND_SLOT,
		"slot": str(row.get("slot", "")),
		"instanceId": str(row.get("instanceId", "")),
		"label": str(row.get("label", "")),
		"canAct": true,
		"actionLabel": "脱下",
		"actionLine": _append_note("回车脱下「%s」" % str(row.get("label", "")), row),
	}


static func _bag_selection(row: Dictionary) -> Dictionary:
	if row.is_empty():
		return {}
	var label: String = str(row.get("label", ""))
	if not bool(row.get("equippable", false)):
		return {
			"kind": CURSOR_KIND_BAG,
			"instanceId": str(row.get("instanceId", "")),
			"templateId": str(row.get("templateId", "")),
			"label": label, "canAct": false,
			"actionLine": "%s 不是能穿在身上的东西。" % label,
		}
	return {
		"kind": CURSOR_KIND_BAG,
		"instanceId": str(row.get("instanceId", "")),
		"templateId": str(row.get("templateId", "")),
		"label": label,
		"slotLabel": str(row.get("slotLabel", "")),
		"canAct": true,
		"actionLabel": "穿上",
		"actionLine": _append_note(
			"回车穿上「%s」（%s）" % [label, str(row.get("slotLabel", ""))], row
		),
	}


## 把这一件的词缀与耐久缀在动作说明后面。
##
## 耐久只在这里出现：它现在不磨损（D-55），全是 100/100，占一整行版面是浪费；
## 而词缀不写出来的话，"为什么这件比那件贵"就没有答案。
static func _append_note(text: String, row: Dictionary) -> String:
	var notes: Array = []
	var affix: String = str(row.get("affixText", ""))
	if not affix.is_empty():
		notes.append(affix)
	var durability: String = str(row.get("durabilityText", ""))
	if not durability.is_empty():
		notes.append(durability)
	if notes.is_empty():
		return text
	return "%s　%s" % [text, " · ".join(PackedStringArray(notes))]


## 属性/技能档位标签。给界面一句话说明"这个数意味着什么"，
## 否则玩家看到 18 不知道是高是低。
static func tier_label(value: int, tiers: Array) -> String:
	for entry in tiers:
		if value <= int(entry["max"]):
			return str(entry["label"])
	return str(tiers[tiers.size() - 1]["label"])


## 铜币换算成人话（《数值框架》9.1 节：1 金 = 100 银 = 10000 铜）。
static func money_label(copper: int) -> String:
	return _money_label(copper)


static func _money_label(copper: int) -> String:
	var value: int = maxi(0, copper)
	@warning_ignore("integer_division")
	var gold: int = value / 10000
	@warning_ignore("integer_division")
	var silver: int = (value % 10000) / 100
	var bronze: int = value % 100
	var parts: Array = []
	if gold > 0:
		parts.append("%d 金" % gold)
	if silver > 0:
		parts.append("%d 银" % silver)
	if bronze > 0 or parts.is_empty():
		parts.append("%d 铜" % bronze)
	return " ".join(PackedStringArray(parts))


## 一件装备的一句话说明。公开：角色面板与商铺界面都要在行上写这一句，
## 两处各写一份的话"武器看伤害、防具看护甲"这条规则会慢慢漂成两套。
##
## stats 是实例的有效数值（特性强化与词缀之后）。不给时退回模板值——商铺的
## 货架是按模板报价的，那里本来就没有实例。
static func item_detail(template: Dictionary, stats: Dictionary = {}) -> String:
	if template.is_empty():
		return "（模板缺失）"
	match str(template.get("category", "")):
		"weapon":
			return "伤害 %d · 距离 %d 格" % [
				int(stats.get(ItemInstance.STAT_ATTACK, template.get("attack", 0))),
				int(stats.get(ItemInstance.STAT_ATTACK_RANGE, template.get("attackRange", 1))),
			]
		"armor":
			return "护甲 %d · 魔抗 %d" % [
				int(stats.get(ItemInstance.STAT_ARMOR, template.get("armor", 0))),
				int(stats.get(ItemInstance.STAT_MAGIC_RESIST, template.get("magicResist", 0))),
			]
	return str(template.get("effectText", ""))


static func _reputation_rows(avatar: PlayerAvatar, city_names: Dictionary) -> Array:
	var ids: Array = avatar.city_reputation.keys()
	ids.sort()
	var out: Array = []
	for city_id in ids:
		var value: int = int(avatar.city_reputation[city_id])
		if value == 0:
			continue
		out.append({
			"cityId": str(city_id),
			"cityLabel": str(city_names.get(str(city_id), str(city_id))),
			"value": value,
			"label": ("%+d" % value),
		})
	return out


## 宿主遗留（M3.2）。三项里非空的才列出来，空的不占版面。
static func _legacy_rows(avatar: PlayerAvatar) -> Array:
	if avatar.legacy.is_empty():
		return []
	var out: Array = []
	var host_name: String = str(avatar.legacy.get("hostName", ""))
	if not host_name.is_empty():
		out.append({"label": "宿主", "value": host_name, "kind": "host"})
	var kin: Array = avatar.legacy.get("kin", [])
	if not kin.is_empty():
		out.append({"label": "亲属", "value": "%d 位" % kin.size(), "kind": "kin"})
	var debt: int = int(avatar.legacy.get("debtCopper", 0))
	if debt > 0:
		out.append({"label": "宿主债务", "value": _money_label(debt), "kind": "debt"})
	for matter in avatar.legacy.get("pending", []):
		out.append({
			"label": "待办",
			"value": str(matter.get("text", "")),
			"kind": str(matter.get("kind", "")),
		})
	return out


static func row(label: String, value: int) -> Dictionary:
	return {"label": label, "value": value, "valueLabel": str(value)}


## 取一张查询表。缺表不是错误——测试只关心某个字段时不必把五张表都备齐，
## 取不到就退回空表，于是所有名字都退化成 ID，界面仍然画得出来。
static func _lookup(lookups: Dictionary, key: String) -> Dictionary:
	var value: Variant = lookups.get(key, null)
	return value if value is Dictionary else {}


static func _template(templates: Dictionary, template_id: String) -> Dictionary:
	var value: Variant = templates.get(template_id, null)
	return value if value is Dictionary else {}


static func entry_row(entry_id: String, names: Dictionary, fallback: String) -> Dictionary:
	return {
		"key": entry_id,
		"label": str(names.get(entry_id, entry_id)),
		"categoryLabel": fallback,
	}
