class_name HudNav
extends RefCounted

## 左侧垂直导航侧栏（M20 阶段一）。
##
## 世界地图之下的十几个二级面板（城市总览 / 商铺 / 走私 / 委托 / 事件 / 角色 /
## 制作 / 纪年 / 居民 / 城内）共用一条竖向入口，替掉每块面板自己的「返回地图」
## 按钮式跳转。与 main.gd 的 VIEW_* 数值保持一致——但这里不能跨文件 import
## main.gd（Main 在场景树上，import 会产生循环依赖），所以把这份只读 id 表
## 复制一份。数值固定，不与 main.gd 联编，意图是"只要两边都从一个常量演化
## 出来，就永远不会错开"。

const VIEW_MAP: int = 0
const VIEW_CITY: int = 1
const VIEW_CREATION: int = 2
const VIEW_AVATAR: int = 3
const VIEW_COMBAT: int = 4
const VIEW_SMUGGLING: int = 5
const VIEW_QUEST: int = 6
const VIEW_EVENT: int = 7
const VIEW_TRADE: int = 8
const VIEW_ENCOUNTER: int = 9
const VIEW_CRAFTING: int = 10
const VIEW_HISTORY: int = 11
const VIEW_NPC: int = 12
const VIEW_CITY_SPACE: int = 13

## 竖排项高与侧栏宽度。字号 14 的标签在 34px 行高里居中绰绰有余。
const ITEM_HEIGHT: float = 34.0


## 侧栏的入口清单。第一项「世界地图」同时承担"返回世界地图"的语义——
## 在任何二级面板里点它都回地图。
static func entries() -> Array:
	return [
		{"view": VIEW_MAP, "label": "世界地图"},
		{"view": VIEW_CITY, "label": "城市总览"},
		{"view": VIEW_TRADE, "label": "商铺"},
		{"view": VIEW_SMUGGLING, "label": "走私"},
		{"view": VIEW_QUEST, "label": "委托"},
		{"view": VIEW_EVENT, "label": "事件"},
		{"view": VIEW_AVATAR, "label": "角色"},
		{"view": VIEW_CRAFTING, "label": "制作"},
		{"view": VIEW_HISTORY, "label": "纪年"},
		{"view": VIEW_NPC, "label": "居民"},
		{"view": VIEW_CITY_SPACE, "label": "城内"},
	]


## 在 rect 里排一竖列入口。返回 [{view, label, rect}]，rect 用于绘制与命中测试，
## 两边共用这一份，位置才不会漂移。超出 rect 底沿的项照排（由调用方定 rect 高度）。
static func layout(rect: Rect2) -> Array:
	var items: Array = []
	for e in entries():
		var y: float = rect.position.y + items.size() * ITEM_HEIGHT
		items.append({
			"view": int(e["view"]),
			"label": str(e["label"]),
			"rect": Rect2(rect.position.x, y, rect.size.x, ITEM_HEIGHT),
		})
	return items


## 画侧栏。底色 + 每项块的背景/描边 + 当前项高亮 + 标签。literal 字体可能为
## null（无头），但绘制从不发生在无头测试里，所以直接信任它。
static func draw(
	canvas: CanvasItem, rect: Rect2, current_view: int, items: Array, hover_view: int
) -> void:
	canvas.draw_rect(rect, UiTheme.COLOR_LIST_BG)
	canvas.draw_rect(rect, UiTheme.COLOR_BORDER, false, 1.0)
	var font: Font = UiTheme.font()
	for item in items:
		var r: Rect2 = item["rect"]
		var view: int = int(item["view"])
		var is_current: bool = view == current_view
		var is_hover: bool = view == hover_view
		canvas.draw_rect(r,
			UiTheme.COLOR_SELECTED if is_current or is_hover else UiTheme.COLOR_BG)
		var border: Color = UiTheme.COLOR_ACCENT if is_current else UiTheme.COLOR_BORDER
		canvas.draw_rect(r, border, false, 1.0)
		var color: Color = (
			UiTheme.COLOR_ACCENT if is_current
			else (UiTheme.COLOR_TEXT if is_hover else UiTheme.COLOR_DIM)
		)
		UiTheme.draw_text(canvas, font,
			Vector2(r.position.x + 10.0, r.position.y + r.size.y * 0.5 + 5.0),
			str(item["label"]), color, UiTheme.SIZE_NORMAL)


## 命中测试：point 落在哪一项里，返回该项下标；否则 -1。绘制与命中共用同一份
## layout 产物，所以两项天然对齐。
static func hit(items: Array, point: Vector2) -> int:
	for i in range(items.size()):
		if (items[i]["rect"] as Rect2).has_point(point):
			return i
	return -1