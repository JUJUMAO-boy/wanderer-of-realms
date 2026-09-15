class_name CreationViewModel
extends RefCounted

## 开局创建界面的视图模型（M3.1 自由生成 + M3.2 随机转生）。
##
## 界面上是有顺序的五段，↑↓ 在段内移动、←→ 改值、TAB 或数字键换段。
## 之所以分段而不是铺成一个三四十行的长列表：种族 6 条 + 出身 8 条 + 七维 7 条
## + 天赋缺陷 10 条，铺平之后玩家要按几十次方向键才能从种族走到确认。

const SECTION_RACE: int = 0
const SECTION_BACKGROUND: int = 1
const SECTION_ATTRIBUTES: int = 2
const SECTION_TRAITS: int = 3
const SECTION_CONFIRM: int = 4
const SECTION_COUNT: int = 5
const SECTION_LABELS: Array = ["1 种族", "2 出身", "3 属性", "4 天赋缺陷", "5 确认"]

## 自由生成 / 随机转生两种开局方式
const MODE_FREE: int = 0
const MODE_REBIRTH: int = 1

## 每段的按键提示。都写明怎么回上一步——原先一个字都没提 ESC，
## 而 TAB 只会一路往前，玩家得撞到确认页才发现没有回头路。
const SECTION_HINTS: Array = [
	"↑↓ 选种族    TAB 下一段    ESC 回上一步",
	"↑↓ 选出身    TAB 下一段    ESC 回上一步",
	"↑↓ 选属性    ←→ 加减点数    TAB 下一段    ESC 回上一步",
	"↑↓ 选条目    空格 或 ←→ 切换    TAB 下一段    ESC 回上一步",
	"回车 开始这一生    ESC 回上一步",
]


## 组装一整屏。spec 会被读取但不修改；section / cursor 由调用方持有。
static func build(
	creator: CharacterCreation,
	spec: Dictionary,
	section: int,
	cursor: int,
	mode: int,
	rebirth: Dictionary = {},
	city_names: Dictionary = {}
) -> Dictionary:
	if creator == null:
		return {}
	var clamped_section: int = clampi(section, 0, SECTION_COUNT - 1)
	var rows: Array = _rows(creator, spec, clamped_section, mode, rebirth, city_names)
	var validation: Dictionary = creator.validate(spec) if mode == MODE_FREE else {"ok": true, "errors": []}
	return {
		"mode": mode,
		"section": clamped_section,
		"sectionLabel": str(SECTION_LABELS[clamped_section]),
		"sectionLabels": SECTION_LABELS,
		"sectionHint": str(SECTION_HINTS[clamped_section]),
		"cursor": clampi(cursor, 0, maxi(0, rows.size() - 1)),
		"rows": rows,
		"rowCount": rows.size(),
		"remainingPoints": creator.remaining_points(spec),
		"allocatablePoints": creator.allocatable_points(),
		"perAttributeCap": creator.per_attribute_cap(),
		"spentPoints": creator.spent_points(spec),
		"canStart": bool(validation["ok"]),
		"errors": validation["errors"],
		"gender": str(spec.get("gender", PlayerAvatar.GENDER_DEFAULT)),
		"raceId": str(spec.get("race", "")),
		"backgroundId": str(spec.get("backgroundId", "")),
		"talentCount": spec.get("talents", []).size(),
		"flawCount": spec.get("flaws", []).size(),
		"rebirth": rebirth,
	}


static func row_count(creator: CharacterCreation, section: int, mode: int) -> int:
	return _rows(creator, {}, section, mode, {}, {}).size()


static func _rows(
	creator: CharacterCreation, spec: Dictionary, section: int, mode: int,
	rebirth: Dictionary, city_names: Dictionary
) -> Array:
	match section:
		SECTION_RACE:
			return _race_rows(creator, spec)
		SECTION_BACKGROUND:
			return _background_rows(creator, spec)
		SECTION_ATTRIBUTES:
			return _attribute_rows(creator, spec)
		SECTION_TRAITS:
			return _trait_rows(creator, spec)
		SECTION_CONFIRM:
			return _confirm_rows(creator, spec, mode, rebirth, city_names)
	return []


static func _race_rows(creator: CharacterCreation, spec: Dictionary) -> Array:
	var current: String = str(spec.get("race", ""))
	var out: Array = []
	for race in creator.race_options():
		var race_id: String = str(race.get("raceId", ""))
		out.append({
			"key": race_id,
			"label": str(race.get("displayName", race_id)),
			"hint": offset_summary(race.get("attributeOffsets", {})),
			"selected": race_id == current,
		})
	return out


static func _background_rows(creator: CharacterCreation, spec: Dictionary) -> Array:
	var current: String = str(spec.get("backgroundId", ""))
	var out: Array = []
	for background in creator.background_options():
		var background_id: String = str(background.get("backgroundId", ""))
		out.append({
			"key": background_id,
			"label": str(background.get("displayName", background_id)),
			"hint": "%s · %d 铜 · %d 件物品" % [
				str(background.get("description", "")),
				int(background.get("initialMoney", 0)),
				background.get("initialItems", []).size(),
			],
			"selected": background_id == current,
		})
	return out


static func _attribute_rows(creator: CharacterCreation, spec: Dictionary) -> Array:
	var allocations: Dictionary = spec.get(CharacterCreation.ATTR_POINTS_KEY, {})
	var offsets: Dictionary = creator.race_offsets(str(spec.get("race", "")))
	var finals: Dictionary = creator.final_attributes(spec)
	var out: Array = []
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		out.append({
			"key": attr,
			"label": str(PlayerAvatar.ATTRIBUTE_LABELS.get(attr, attr)),
			"allocated": int(allocations.get(attr, 0)),
			"offset": int(offsets.get(attr, 0)),
			"final": int(finals.get(attr, 0)),
			"bar": clampf(float(finals.get(attr, 0)) / 100.0, 0.0, 1.0),
			"hint": "起点 %d %s 种族 %+d" % [
				creator.base_attribute(),
				("+%d 分配" % int(allocations.get(attr, 0))) if int(allocations.get(attr, 0)) > 0 else "无分配",
				int(offsets.get(attr, 0)),
			],
		})
	return out


static func _trait_rows(creator: CharacterCreation, spec: Dictionary) -> Array:
	var talents: Array = spec.get("talents", [])
	var flaws: Array = spec.get("flaws", [])
	var out: Array = []
	for entry in creator.talent_options():
		out.append(_trait_row(entry, talents, "天赋"))
	for entry in creator.flaw_options():
		out.append(_trait_row(entry, flaws, "缺陷"))
	return out


static func _trait_row(entry: Dictionary, chosen: Array, category_label: String) -> Dictionary:
	var entry_id: String = str(entry.get("talentId", ""))
	return {
		"key": entry_id,
		"label": str(entry.get("displayName", entry_id)),
		"categoryLabel": category_label,
		"weight": int(entry.get("weight", 0)),
		"weightLabel": "%+d" % int(entry.get("weight", 0)),
		"effectText": str(entry.get("effectText", "")),
		"selected": chosen.has(entry_id),
	}


static func _confirm_rows(
	creator: CharacterCreation, spec: Dictionary, mode: int, rebirth: Dictionary,
	city_names: Dictionary
) -> Array:
	if mode == MODE_REBIRTH:
		return _rebirth_rows(rebirth, city_names)

	var race_id: String = str(spec.get("race", ""))
	var background_id: String = str(spec.get("backgroundId", ""))
	var race_label: String = _label_of(creator.race_options(), "raceId", race_id)
	var background_label: String = _label_of(creator.background_options(), "backgroundId", background_id)
	var out: Array = [
		{"label": "种族", "value": race_label, "kind": "plain"},
		{"label": "出身", "value": background_label, "kind": "plain"},
		{
			"label": "性别", "kind": "plain",
			"value": "男" if str(spec.get("gender", "")) == PlayerAvatar.GENDER_MALE else "女",
		},
		{
			"label": "属性", "kind": "plain",
			"value": _attribute_summary(creator.final_attributes(spec)),
		},
		{
			"label": "天赋 / 缺陷", "kind": "plain",
			"value": "%d / %d（当量 %+d / %+d）" % [
				spec.get("talents", []).size(), spec.get("flaws", []).size(),
				_sum_weight(creator, spec.get("talents", [])),
				_sum_weight(creator, spec.get("flaws", [])),
			],
		},
	]
	for talent_id in spec.get("talents", []):
		out.append({
			"label": "  · 天赋", "kind": "trait",
			"value": _label_of(creator.talent_options(), "talentId", str(talent_id)),
		})
	for flaw_id in spec.get("flaws", []):
		out.append({
			"label": "  · 缺陷", "kind": "trait",
			"value": _label_of(creator.flaw_options(), "talentId", str(flaw_id)),
		})
	return out


static func _rebirth_rows(rebirth: Dictionary, city_names: Dictionary) -> Array:
	if rebirth.is_empty():
		return [{"label": "随机转生", "value": "按 R 抽一具躯壳", "kind": "plain"}]
	var legacy: Dictionary = rebirth.get("legacy", {})
	var host_city: String = str(legacy.get("hostCityId", ""))
	var out: Array = [
		{"label": "宿主", "value": str(legacy.get("hostName", "—")), "kind": "plain"},
		{
			"label": "躯壳", "value": "%s · %d 岁 · %s" % [
				str(legacy.get("hostRace", "")), int(legacy.get("hostAge", 0)),
				str(city_names.get(host_city, host_city)),
			], "kind": "plain",
		},
		{"label": "亲属", "value": "%d 位" % legacy.get("kin", []).size(), "kind": "plain"},
		{"label": "宿主的债", "value": AvatarViewModel.money_label(int(legacy.get("debtCopper", 0))), "kind": "plain"},
		{
			"label": "沉眠", "value": "%d 个月" % int(rebirth.get("sleepMonths", 0)),
			"kind": "plain",
		},
		{
			"label": "记忆保留率", "value": "%d%%" % int(round(float(rebirth.get("retention", 0.0)) * 100.0)),
			"kind": "plain",
		},
	]
	for matter in legacy.get("pending", []):
		out.append({"label": "  · 待办", "value": str(matter.get("text", "")), "kind": "pending"})
	return out


# --- 文案 ---

## 种族属性偏移压成一行，如「STR +3 · DEX −2 · CON +4」。
static func offset_summary(offsets: Dictionary) -> String:
	var parts: Array = []
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		var value: int = int(offsets.get(attr, 0))
		if value == 0:
			continue
		var short_name: String = str(PlayerAvatar.ATTRIBUTE_LABELS.get(attr, attr)).get_slice(" ", 1)
		parts.append("%s %+d" % [short_name, value])
	return " · ".join(PackedStringArray(parts)) if not parts.is_empty() else "无属性偏移"


static func _attribute_summary(attributes: Dictionary) -> String:
	var parts: Array = []
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		var short_name: String = str(PlayerAvatar.ATTRIBUTE_LABELS.get(attr, attr)).get_slice(" ", 1)
		parts.append("%s %d" % [short_name, int(attributes.get(attr, 0))])
	return " ".join(PackedStringArray(parts))


static func _sum_weight(creator: CharacterCreation, ids: Array) -> int:
	var total: int = 0
	for entry_id in ids:
		for entry in creator.talent_options() + creator.flaw_options():
			if str(entry.get("talentId", "")) == str(entry_id):
				total += int(entry.get("weight", 0))
	return total


static func _label_of(list: Array, key: String, value: String) -> String:
	for entry in list:
		if str(entry.get(key, "")) == value:
			return str(entry.get("displayName", value))
	return value
