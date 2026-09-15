class_name EventViewModel
extends RefCounted

## 城市事件界面的视图模型（M7.1）。
##
## 与委托界面同构：左边一件事一行，右边是选中那件的来龙去脉（剧本里的关键对白、
## 为什么是这座城、封港让什么在流血）；抉择是同一个面板的另一种形态
## （mode = MODE_BRANCH），把三种做法与各自后果摊开。
##
## 后果预览与交付走的是同一个函数（EventSystem.branch_preview），所以"选项上写着
## 财富 +30、落账却是 +20"这种错误没有藏身处。
##
## **已了结的事也留在列上**。这不是为了记事，而是为了回答玩家一定会问的那句
## "这海怪还会不会再来"——判据是上一次怎么收的场（病根除了还是没除），
## 而这件事只写在已了结的那一行上。

const ROW_KIND_ACTIVE: String = "active"
const ROW_KIND_RESOLVED: String = "resolved"

const MODE_LIST: int = 0
const MODE_BRANCH: int = 1


## events 是世界的全部事件实例（含已了结的），city_id 是这一屏看的是哪座城。
static func build(
	world: WorldState,
	events: Array,
	city_id: String,
	here_city_id: String,
	city_names: Dictionary,
	cursor: int,
	mode: int = MODE_LIST
) -> Dictionary:
	if world.get_city(city_id) == null:
		return {}
	var city_label: String = _city_label(city_names, city_id)
	var rows: Array = []
	# 只看这座城的事：面板的名字就叫「城中大事」，而"别的城出了什么事"由底部
	# 事件流与那座城的详情页去说。把八座城的事全塞进一屏，玩家反而找不到自己
	# 脚下这件事。
	var mine: Array = []
	for event in events:
		if event.city_id == city_id:
			mine.append(event)
	# 进行中的排前面：那才是玩家来这一屏的事由
	for event in mine:
		if event.is_active():
			rows.append(_active_row(event, city_label, here_city_id))
	for event in mine:
		if not event.is_active():
			rows.append(_resolved_row(event, city_label))

	var row_count: int = rows.size()
	var index: int = clampi(cursor, 0, maxi(0, row_count - 1))
	var selected: Dictionary = rows[index] if row_count > 0 else {}
	return {
		"cityId": city_id,
		"cityLabel": city_label,
		"hereCityId": here_city_id,
		"atCity": city_id == here_city_id,
		"rows": rows,
		"rowCount": row_count,
		"cursor": index,
		"selected": selected,
		"mode": mode,
		"activeCount": _count_kind(rows, ROW_KIND_ACTIVE),
		"branches": branch_rows(selected),
		"selectedIsActive": str(selected.get("kind", "")) == ROW_KIND_ACTIVE,
	}


# --- 行 ---

static func _active_row(
	event: CityEvent, city_label: String, here_city_id: String
) -> Dictionary:
	var config: Dictionary = ContentLoader.get_event_template(event.template_id)
	var here: bool = event.city_id == here_city_id
	var blockade: Variant = config.get("blockade", null)
	var blockade_spec: Dictionary = blockade if blockade is Dictionary else {}
	return {
		"kind": ROW_KIND_ACTIVE,
		"eventId": event.event_id,
		"templateId": event.template_id,
		"title": EventSystem.template_label(config, event.template_id),
		"scriptRef": str(config.get("scriptRef", event.template_id)),
		"cityLabel": city_label,
		"summary": str(config.get("summary", "")),
		"dialogue": config.get("dialogue", []),
		"reason": "第 %d 月起的变故" % event.triggered_month,
		"effect": blockade_effect_text(blockade_spec),
		"statusLabel": "未了",
		# 事件只能在它发生的那座城里处理。不在那座城时不置灰也不静默：
		# 说清楚要回哪座城（与委托的 blockedReason 同一条道理）
		"enabled": here,
		"canResolve": here,
		"blockedReason": "" if here else "要回到%s才能处置" % city_label,
		"outcomeLabel": "",
	}


static func _resolved_row(event: CityEvent, city_label: String) -> Dictionary:
	var config: Dictionary = ContentLoader.get_event_template(event.template_id)
	var branch: Dictionary = EventSystem.find_branch(config, event.branch_id)
	var lifted: bool = event.branch_id == EventSystem.BRANCH_LIFTED
	var label: String = "封锁自行解除" if lifted else str(branch.get("label", "—"))
	var tail: String = ""
	if lifted:
		tail = "没人管过它，船改走了别的航道"
	elif bool(branch.get("recurrence", false)):
		tail = "病根还在，日后可能再犯"
	else:
		tail = "病根已除，不会再来"
	return {
		"kind": ROW_KIND_RESOLVED,
		"eventId": event.event_id,
		"templateId": event.template_id,
		"title": EventSystem.template_label(config, event.template_id),
		"scriptRef": str(config.get("scriptRef", event.template_id)),
		"cityLabel": city_label,
		"summary": str(config.get("summary", "")),
		"dialogue": config.get("dialogue", []),
		"reason": "第 %d 月了结" % event.resolved_month,
		"effect": tail,
		"statusLabel": "已了",
		"enabled": true,
		"canResolve": false,
		"blockedReason": "",
		"outcomeLabel": label,
	}


# --- 抉择 ---

## 这件事可以怎么处置，以及各选各的后果。带战斗的那条只说明"打完再定"，
## 但把赢与输两套后果都先摊开——玩家要的是"这一仗值不值得打"，而不是猜。
static func branch_rows(selected: Dictionary) -> Array:
	if str(selected.get("kind", "")) != ROW_KIND_ACTIVE:
		return []
	if not bool(selected.get("canResolve", false)):
		return []
	var config: Dictionary = ContentLoader.get_event_template(str(selected.get("templateId", "")))
	if config.is_empty():
		return []
	var out: Array = []
	for branch in config.get("branches", []):
		var branch_id: String = str(branch.get("branchId", ""))
		var preview: Dictionary = EventSystem.branch_preview(config, branch_id)
		var is_combat: bool = bool(branch.get("isCombat", false))
		out.append({
			"branchId": branch_id,
			"isCombat": is_combat,
			"label": str(preview.get("label", branch_id)),
			"detail": str(preview.get("detail", "")),
			"effectLabel": combat_effect_text(preview) if is_combat \
				else EventSystem.effect_label(preview),
			"enabled": true,
		})
	return out


## 战斗分支的后果说明。两套都写出来，中间用「／」隔开——一行里说清
## "赢了会怎样、输了会怎样"，比让玩家自己去试要诚实。
static func combat_effect_text(preview: Dictionary) -> String:
	var parts: Array = []
	for key in [
		{"key": "victory", "label": "赢"},
		{"key": "defeat", "label": "输"},
	]:
		var outcome: Dictionary = preview.get(str(key["key"]), {})
		if outcome.is_empty():
			continue
		parts.append("%s：%s" % [str(key["label"]), EventSystem.effect_label(outcome)])
	return " ／ ".join(PackedStringArray(parts))


## 封港期间城里在发生什么。这是玩家判断"要不要管"的唯一依据，所以三条都要写全：
## 触发时扣了多少、每月还在扣多少、以及航线断没断。
static func blockade_effect_text(blockade: Dictionary) -> String:
	var parts: Array = []
	var changes: Variant = blockade.get("changes", null)
	if changes is Dictionary:
		for dimension in (changes as Dictionary):
			parts.append("触发时 %s %s" % [
				_dimension_label(str(dimension)), _signed(int((changes as Dictionary)[dimension]))
			])
	var drain: Variant = blockade.get("drainPerMonth", null)
	if drain is Dictionary:
		var per_month: Dictionary = drain
		parts.append("每月 %s %s" % [
			_dimension_label(str(per_month.get("dimension", ""))),
			_signed(int(per_month.get("delta", 0))),
		])
	if bool(blockade.get("haltRoutes", false)):
		parts.append("该城航线收益全断")
	if parts.is_empty():
		return "城里的日子照旧"
	return " · ".join(PackedStringArray(parts))


# --- 文案小工具 ---

static func _count_kind(rows: Array, kind: String) -> int:
	var total: int = 0
	for row in rows:
		if str(row.get("kind", "")) == kind:
			total += 1
	return total


static func _dimension_label(dimension: String) -> String:
	return str(City.DIMENSION_LABELS.get(dimension, dimension))


static func _city_label(city_names: Dictionary, city_id: String) -> String:
	return str(city_names.get(city_id, city_id))


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
