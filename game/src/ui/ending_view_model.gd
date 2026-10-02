class_name EndingViewModel
extends RefCounted

## 结局演出页的视图模型（第四阶段界面精修 · 上，里程碑 54）。
##
## 后日谈（剧本 12.1~12.4）与关系分支（12.5）字多，直接铺在主线面板里会溢出屏幕底沿、
## 读不全。这里把它摊成**一页一屏的演出脚本**：标题页 → 逐段后日谈 → 关系页 → 结局之后页，
## 由 `EndingPanel` 翻页读。纯函数：只排版，不加工数值、不碰渲染、不落盘。
##
## 输入取自 `EndingLine.briefing(...)` 的 `chosen`（已选结局），所以本类不含判定逻辑。

const KIND_LABELS: Dictionary = {"order": "秩序", "cycle": "轮回", "free": "自由"}


static func kind_label(kind: String) -> String:
	return str(KIND_LABELS.get(kind, ""))


## 把已选结局摊成演出页。返回：
##   { endingId, label, kind, kindLabel, pages, page, pageCount, canPrev, canNext }
## `pages` 每项 { kind, head, text, relations }，kind ∈ title/text/relations/after。
## chosen 为空时 pages 为空、pageCount 为 0。
static func build(chosen: Dictionary, page: int = 0) -> Dictionary:
	var pages: Array = []
	if not chosen.is_empty():
		pages.append({
			"kind": "title", "head": str(chosen.get("label", "")),
			"text": str(chosen.get("note", "")), "relations": [],
		})
		for para in chosen.get("epilogue", []):
			pages.append({"kind": "text", "head": "", "text": str(para), "relations": []})
		var relations: Array = chosen.get("relationLines", [])
		if not relations.is_empty():
			pages.append({"kind": "relations", "head": "你走过的关系", "text": "", "relations": relations})
		var after: String = str(chosen.get("worldAfter", ""))
		if not after.is_empty():
			pages.append({"kind": "after", "head": "结局之后", "text": after, "relations": []})
	var count: int = pages.size()
	var cur: int = clampi(page, 0, maxi(0, count - 1))
	var kind: String = str(chosen.get("kind", ""))
	return {
		"endingId": str(chosen.get("endingId", "")),
		"label": str(chosen.get("label", "")),
		"kind": kind,
		"kindLabel": kind_label(kind),
		"pages": pages,
		"page": cur,
		"pageCount": count,
		"canPrev": cur > 0,
		"canNext": cur < count - 1,
	}