class_name LifeViewModel
extends RefCounted

## 世代记录的视图模型（第十个视图）。
##
## 一屏两件事：左列是**历代**（活着的那一行排在最上，其后由近及远），右列是选中那一世的
## **功绩成就**——寿数、身家、名声、经历、关系、对世界做过的事。死亡之后自动进这一屏、
## 光标停在刚结束的那一世，底部多一个「转生」按钮；在世时进来则是翻记录，底部给的是
## 「结束这一生」（D-59 / D-62）。
##
## 与其它视图模型同一条分工：只读世界与灵魂记录，不写任何东西；"现在能不能转生"
## 由 mode 回答，真正装配化身仍是主场景的事。

## 左列的两种行。在世的那一世没有档案可查，但它有自己的位置。
const ROW_KIND_ALIVE: String = "alive"
const ROW_KIND_ARCHIVE: String = "archive"

## 翻记录（在世）与刚结束这一世（等着转生）。两者的差别只有底部那两个按钮与
## 页脚那句话。
const MODE_REVIEW: int = 0
const MODE_SETTLE: int = 1


## 行按"由近及远"排：这一世（在世）→ 最近结束的那一世 → … → 第一世。
## 理由是玩家来这里十次有九次是问"我上一世干了什么"。
static func build(
	soul: SoulRecord,
	avatar: PlayerAvatar,
	lifecycle: Lifecycle,
	now_month: int,
	cursor: int,
	mode: int = MODE_REVIEW,
	city_names: Dictionary = {},
	skill_names: Dictionary = {},
	retire_armed: bool = false
) -> Dictionary:
	var archives: Array = soul.life_archives if soul != null else []
	var rows: Array = []
	if avatar != null:
		rows.append(_alive_row(avatar, lifecycle, now_month))
	for i in range(archives.size() - 1, -1, -1):
		rows.append(_archive_row(archives, i))

	var row_count: int = rows.size()
	var index: int = clampi(cursor, 0, maxi(0, row_count - 1))
	var selected: Dictionary = rows[index] if row_count > 0 else {}
	var sections: Array = _sections(selected, archives, city_names, skill_names)

	return {
		"rows": rows,
		"rowCount": row_count,
		"cursor": index,
		"selected": selected,
		"sections": sections,
		"mode": mode,
		"alive": avatar != null,
		"canRebirth": mode == MODE_SETTLE and avatar == null,
		"canRetire": avatar != null and mode == MODE_REVIEW,
		"retireArmed": retire_armed,
		"reincarnationCount": soul.reincarnation_count if soul != null else 0,
		"lastRetention": soul.last_retention if soul != null else 0.0,
		"aliveLine": _alive_line(avatar, lifecycle, now_month),
		"hint": _hint(mode, retire_armed),
	}


# --- 左列 ---

static func _alive_row(avatar: PlayerAvatar, lifecycle: Lifecycle, now_month: int) -> Dictionary:
	var age: int = lifecycle.current_age(avatar, now_month) if lifecycle != null else avatar.age
	var span: int = lifecycle.lifespan_of(avatar) if lifecycle != null else 0
	return {
		"kind": ROW_KIND_ALIVE,
		"title": "这一世 · %s" % avatar.display_name,
		"meta": "%d 岁 · %s" % [age, avatar.race],
		"detail": "%d 岁 · %s · %s" % [age, avatar.race, _standing(age, span, lifecycle)],
		"lifeNumber": -1,
		"age": age,
		"lifespan": span,
	}


static func _archive_row(archives: Array, index: int) -> Dictionary:
	var archive: Dictionary = archives[index]
	var snapshot: Dictionary = archive.get("avatarSnapshot", {})
	var cause: String = str(archive.get("deathCause", ""))
	var age: int = int(archive.get("age", 0))
	var span: int = int(archive.get("lifespan", 0))
	return {
		"kind": ROW_KIND_ARCHIVE,
		"title": "第 %d 世 · %s" % [index + 1, str(snapshot.get("displayName", "无名者"))],
		"meta": "%d 岁 · %s" % [age, _cause_label(cause)],
		"detail": "%d 岁 · 第 %d 月终 · %s" % [age, int(archive.get("endedMonth", 0)), _cause_label(cause)],
		"lifeNumber": index + 1,
		"age": age,
		"lifespan": span,
		"archiveId": str(archive.get("archiveId", "")),
	}


# --- 右列：功绩成就 ---

static func _sections(
	row: Dictionary, archives: Array, city_names: Dictionary, skill_names: Dictionary
) -> Array:
	if row.is_empty():
		return []
	if str(row.get("kind", "")) == ROW_KIND_ALIVE:
		return _alive_sections(row, city_names, skill_names)
	var index: int = int(row.get("lifeNumber", 0)) - 1
	if index < 0 or index >= archives.size():
		return []
	return _archive_sections(archives[index], city_names, skill_names)


## 在世那一世：档案还没写，所以只摆"现在是什么样"。它不是传世记录，
## 而是"这一世到目前为止"——玩家翻记录时最先看到的也是它。
static func _alive_sections(
	row: Dictionary, city_names: Dictionary, skill_names: Dictionary
) -> Array:
	var span: int = int(row.get("lifespan", 0))
	var age: int = int(row.get("age", 0))
	return [
		_section("寿数", [
			"%d 岁（寿命上限约 %d 岁，还有 %d 年）" % [age, span, maxi(0, span - age)],
		]),
		_section("眼下", [
			"身家、名声与经历要等这一世结束才写得成——那时它们才定下来。",
		]),
	]


static func _archive_sections(
	archive: Dictionary, city_names: Dictionary, skill_names: Dictionary
) -> Array:
	var deeds: Dictionary = archive.get("deeds", {})
	var snapshot: Dictionary = archive.get("avatarSnapshot", {})
	var out: Array = [_identity_section(archive, deeds, snapshot, city_names)]
	if deeds.is_empty():
		out.append(_section("功绩", ["这一世没有留下功绩记录（结算时还没有这一栏）。"]))
		return out
	out.append(_fortune_section(deeds))
	out.append(_fame_section(deeds, city_names))
	out.append(_attributes_section(deeds, snapshot))
	out.append(_skills_section(deeds, skill_names))
	out.append(_experience_section(deeds))
	out.append(_relations_section(deeds))
	out.append(_world_section(deeds, city_names))
	return out


static func _identity_section(
	archive: Dictionary, deeds: Dictionary, snapshot: Dictionary, city_names: Dictionary
) -> Dictionary:
	var age: int = int(deeds.get("age", archive.get("age", 0)))
	var span: int = int(deeds.get("lifespan", archive.get("lifespan", 0)))
	var months: int = int(deeds.get("monthsLived", 0))
	var lines: Array = []
	lines.append("%s · %s · %s" % [
		str(snapshot.get("displayName", "无名者")),
		str(snapshot.get("race", "")),
		"男" if str(snapshot.get("gender", "")) == PlayerAvatar.GENDER_MALE else "女",
	])
	lines.append("享年 %d 岁（寿命上限约 %d 岁）· 死因：%s" % [
		age, span, _cause_label(str(archive.get("deathCause", ""))),
	])
	lines.append("于第 %d 月终了（这一世活了 %d 年 %d 月）" % [
		int(archive.get("endedMonth", 0)), months / 12, months % 12,
	])
	var background: String = str(snapshot.get("backgroundId", ""))
	if not background.is_empty():
		lines.append("出身：%s" % background)
	return _section("这一世", lines)


static func _fortune_section(deeds: Dictionary) -> Dictionary:
	return _section("身家", [
		"终了时的现钱：%s" % AvatarViewModel.money_label(int(deeds.get("money", 0))),
		"欠着的债：%s" % AvatarViewModel.money_label(int(deeds.get("debtCopper", 0))),
		"背包 %d 件 · 身上披挂 %d 件" % [
			int(deeds.get("itemCount", 0)), int(deeds.get("equippedCount", 0)),
		],
	])


static func _fame_section(deeds: Dictionary, city_names: Dictionary) -> Dictionary:
	var lines: Array = []
	var reputation: Array = deeds.get("reputation", [])
	if reputation.is_empty():
		lines.append("哪座城都没记住你（各城声誉都是 0）。")
	else:
		for record in reputation:
			var value: int = int(record.get("value", 0))
			lines.append("%s：%s" % [
				_city_label(city_names, str(record.get("cityId", ""))), _signed(value),
			])
	lines.append("善恶 %s · 幸运 %s" % [
		_signed(int(deeds.get("karma", 0))), _signed(int(deeds.get("luck", 0))),
	])
	return _section("名声", lines)


static func _attributes_section(deeds: Dictionary, snapshot: Dictionary) -> Dictionary:
	var attributes: Dictionary = deeds.get("attributes", snapshot.get("attributes", {}))
	var parts: Array = []
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		parts.append("%s %d" % [_short_attribute(attr), int(attributes.get(attr, 0))])
	return _section("终了时的七维", [" · ".join(PackedStringArray(parts))])


static func _skills_section(deeds: Dictionary, skill_names: Dictionary) -> Dictionary:
	var rows: Array = deeds.get("topSkills", [])
	if rows.is_empty():
		return _section("技艺", ["没有一项练到家（熟练度全为 0）。"])
	var lines: Array = []
	for record in rows:
		var skill_id: String = str(record.get("skillId", ""))
		lines.append("%s %d" % [str(skill_names.get(skill_id, skill_id)), int(record.get("level", 0))])
	return _section("最拿手的几项", lines)


static func _experience_section(deeds: Dictionary) -> Dictionary:
	var counters: Dictionary = deeds.get("counters", {})
	var lines: Array = []
	for key in PlayerAvatar.DEED_KEYS:
		var value: int = int(counters.get(str(key), 0))
		# 零的行照写：一整列都齐全才看得出"这个人没打过架"，缺行反而像漏了
		lines.append("%s：%d" % [str(PlayerAvatar.DEED_LABELS.get(str(key), str(key))), value])
	return _section("经历", lines)


static func _relations_section(deeds: Dictionary) -> Dictionary:
	var relations: Dictionary = deeds.get("relations", {})
	var host: String = str(relations.get("hostName", ""))
	if host.is_empty():
		return _section("关系", ["这一世是自己挑的身子，没有接手别人的旧账。"])
	return _section("关系", [
		"占了%s的身子" % host,
		"留下亲属 %d 人 · 仇敌 %d 人" % [
			int(relations.get("kin", 0)), int(relations.get("enemies", 0)),
		],
	])


static func _world_section(deeds: Dictionary, city_names: Dictionary) -> Dictionary:
	var world: Dictionary = deeds.get("world", {})
	var visited: Array = deeds.get("visitedCities", [])
	var lines: Array = [
		"开过的航线 %d 条（世上共 %d 条）" % [
			int(world.get("routesOwned", 0)), int(world.get("routesTotal", 0)),
		],
		"世上留下 %d 条痕迹 · 踏足 %d / %d 座城" % [
			int(world.get("flags", 0)), visited.size(), int(world.get("cities", 0)),
		],
	]
	if not visited.is_empty():
		var names: Array = []
		for city_id in visited:
			names.append(_city_label(city_names, str(city_id)))
		lines.append(" · ".join(PackedStringArray(names)))
	return _section("对世界做过的事", lines)


# --- 文案小工具 ---

static func _section(title: String, lines: Array) -> Dictionary:
	return {"title": title, "lines": lines}


static func _cause_label(cause: String) -> String:
	return str(Reincarnation.CAUSE_LABELS.get(cause, cause))


## 在世那一世的"活得怎么样"。这一句只说年龄与寿命的关系——它是玩家判断
## "还要不要接着活"的唯一依据（D-58 的暮年线只用来提示，不参与判定）。
static func _standing(age: int, span: int, lifecycle: Lifecycle) -> String:
	if span <= 0 or lifecycle == null:
		return "在世"
	if lifecycle.has_reached(age, span):
		return "已经该寿终了"
	if lifecycle.is_elder(age, span):
		return "来日无多（暮年）"
	return "在世"


static func _alive_line(avatar: PlayerAvatar, lifecycle: Lifecycle, now_month: int) -> String:
	if avatar == null:
		return ""
	var age: int = lifecycle.current_age(avatar, now_month)
	var span: int = lifecycle.lifespan_of(avatar)
	return "%s · %d 岁 · 寿命上限约 %d 岁 · %s" % [
		avatar.display_name, age, span, _standing(age, span, lifecycle),
	]


static func _hint(mode: int, retire_armed: bool) -> String:
	if mode == MODE_SETTLE:
		return "这一世到这里了。按回车去转生——沉眠若干年之后，你会在别人身上醒来。"
	if retire_armed:
		return "再按一次「结束这一生」就真的结束了：背包、钱、名声都带不走。"
	return "↑↓ 翻看历代；「结束这一生」是主动放下这一世，之后走的是同一条转生流程。"


## 七维的短名。PlayerAvatar.ATTRIBUTE_LABELS 是 "力量 STR" 这种带缩写的形式，
## 一行七项时太长，取空格前那一半。
static func _short_attribute(attribute: String) -> String:
	var label: String = str(PlayerAvatar.ATTRIBUTE_LABELS.get(attribute, attribute))
	var parts: PackedStringArray = label.split(" ")
	return str(parts[0]) if parts.size() > 0 else attribute


static func _city_label(city_names: Dictionary, city_id: String) -> String:
	return str(city_names.get(city_id, city_id))


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
