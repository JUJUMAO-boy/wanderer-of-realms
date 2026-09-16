class_name ChronicleViewModel
extends RefCounted

## 世界纪年史书的视图模型（M16）。
##
## 纯函数：把 world.chronicle（旧到新追加）倒过来排成最近在顶的列表，供面板逐条
## 渲染。行与详情都直接从纪年条目取，不做数值加工——面板只负责把它摊开。
##
## 三种条目来源（kind）在这里各得一种气泡色与文案角标，界面据此一眼看出
## 这条史是城市事件、城市跨档、还是转生世系。

static func build(entries: Array, cursor: int) -> Dictionary:
	var rows: Array = []
	# chronicle 是按时间旧到新追加的，史书要「最近在前」，故倒序。
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		if not entry is Dictionary:
			continue
		rows.append(_row(entry))
	var row_count: int = rows.size()
	var index: int = clampi(cursor, 0, maxi(0, row_count - 1))
	var selected: Dictionary = rows[index] if row_count > 0 else {}
	return {
		"rows": rows,
		"rowCount": row_count,
		"cursor": index,
		"selected": selected,
		"counts": count_kinds(rows),
	}


static func _row(entry: Dictionary) -> Dictionary:
	return {
		"id": int(entry.get("id", 0)),
		"kind": str(entry.get("kind", "cityEvent")),
		"year": str(entry.get("year", "")),
		"month": int(entry.get("month", 0)),
		"title": str(entry.get("title", "")),
		"cityLabel": str(entry.get("cityLabel", "")),
		"detail": str(entry.get("detail", "")),
		"attribution": str(entry.get("attribution", "")),
		"kindLabel": kind_label(str(entry.get("kind", "cityEvent"))),
	}


## 各类来源的条数（城市事件 / 城市跨档 / 转生世系）。史书有混着看的一面，
## 也有「这一百年历史上的转折主要长在哪条线上」的统计场景。
static func count_kinds(rows: Array) -> Dictionary:
	var out: Dictionary = {
		Chronicle.KIND_CITY_EVENT: 0,
		Chronicle.KIND_TIER: 0,
		Chronicle.KIND_SOUL: 0,
	}
	for row in rows:
		var kind: String = str(row.get("kind", ""))
		if out.has(kind):
			out[kind] = int(out[kind]) + 1
	return out


## 条目来源的中文角标，与 panel 的气泡色一一对应。
static func kind_label(kind: String) -> String:
	match kind:
		Chronicle.KIND_CITY_EVENT:
			return "大事"
		Chronicle.KIND_TIER:
			return "跨档"
		Chronicle.KIND_SOUL:
			return "转生"
	return "纪事"