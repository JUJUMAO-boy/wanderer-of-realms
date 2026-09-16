class_name Chronicle
extends RefCounted

## 世界大事件与历史纪年（M16）。把「这个世界因谁改了什么」沉淀成跨代落盘的
## 纪年条目，玩家换了代还能翻开看。
##
## 与防线的同源设计：这是**规则层**，就地读配置、就地改 world，产出形如
## {id, year, month, kind, title, cityId, cityLabel, detail, attribution} 的条目
## 追加进 world.chronicle。谁够格进纪年、用哪个 kind / 文案，都由这里定，界面只
## 负责把它排出来。持久化归 WorldState（随世界存档），本类不碰存档。

## 条目来源类别。界面按它着色/分节，也透出「这事从哪来」。
const KIND_CITY_EVENT: String = "cityEvent"
const KIND_TIER: String = "tier"
const KIND_SOUL: String = "soul"

const DEFAULT_MIN_WEIGHT: int = 250
const DEFAULT_MAX_ENTRIES: int = 400

var _min_weight: int = DEFAULT_MIN_WEIGHT
var _max_entries: int = DEFAULT_MAX_ENTRIES
var _months_per_year: int = 12


## 直接用 balance.chronicle 装配。事件模板的 chronicleBp 也是从 ContentLoader 现读。
static func create() -> Chronicle:
	var c := Chronicle.new()
	var cfg: Dictionary = ContentLoader.get_balance_section("chronicle")
	c._min_weight = int(cfg.get("minChronicleWeight", DEFAULT_MIN_WEIGHT))
	c._max_entries = int(cfg.get("maxEntries", DEFAULT_MAX_ENTRIES))
	c._months_per_year = maxi(1, int(ContentLoader.get_balance_section("time").get("monthsPerYear", 12)))
	return c


func _init(min_weight: int = DEFAULT_MIN_WEIGHT, max_entries: int = DEFAULT_MAX_ENTRIES,
		months_per_year: int = 12) -> void:
	_min_weight = min_weight
	_max_entries = maxi(1, max_entries)
	_months_per_year = maxi(1, months_per_year)


## balance 的 chronicle 段。界面要摆出过滤阈值之类时从这里取。
func rules() -> Dictionary:
	return {
		"minChronicleWeight": _min_weight,
		"maxEntries": _max_entries,
	}


## 一件候选（事件模板）够不够格上纪年。事件支不留、只记真的大的：
## 阈值内的琐碎事件照旧只走单城事件流，不进世界史，免得被刷屏稀释。
func is_notable(template: Dictionary) -> bool:
	return chronicle_weight(template) >= _min_weight


## 事件模板的纪年权重（chronicleBp）。缺省 0 = 不够格。值越大代表这场越值得
## 被后人记住。
func chronicle_weight(template: Dictionary) -> int:
	return int(template.get("chronicleBp", 0))


## 把一件已达标的城市事件转成纪年条目（不进 world，纯函数）。
## 调用方须先 is_notable(template) == true。返回 {kind, title, cityId, cityLabel,
## detail, attribution, year, month}。
func event_entry(world: WorldState, event: CityEvent) -> Dictionary:
	if event == null:
		return {}
	var city: City = null if world == null else world.get_city(event.city_id)
	var city_label: String = city.display_name if city != null else event.city_id
	var config: Dictionary = ContentLoader.get_event_template(event.template_id)
	var title: String = EventSystem.template_label(config, event.template_id)
	var detail: String = str(config.get("summary", ""))
	if detail.is_empty():
		detail = "「%s」在 %s 发生并了结" % [title, city_label]
	return {
		"kind": KIND_CITY_EVENT,
		"title": "%s的行动：%s" % [city_label, title],
		"cityId": event.city_id,
		"cityLabel": city_label,
		"detail": detail,
		"attribution": "城市事件",
		"month": event.triggered_month,
		"year": _year_label(event.triggered_month),
		"weight": chronicle_weight(config),
	}


## 某城建模升级/降级的纪年条目。month 取该档变化发生的当月；成品文案由
## fromLabel/toLabel 拼，与 WorldSim 的 tier 事件用同一套标签。
func tier_entry(world: WorldState, city_id: String, from_label: String, to_label: String,
		month: int) -> Dictionary:
	var city: City = null if world == null else world.get_city(city_id)
	var city_label: String = city.display_name if city != null else city_id
	return {
		"kind": KIND_TIER,
		"title": "%s 从「%s」变为「%s」" % [city_label, from_label, to_label],
		"cityId": city_id,
		"cityLabel": city_label,
		"detail": "这座城的建模发生了跨档变化——是这一百年里最值得记住的转折之一。",
		"attribution": "城市演化",
		"month": month,
		"year": _year_label(month),
		"weight": _min_weight,
	}


## 第 N 世落幕的纪年条目（玩家转生时写一条）。month 取转生发生的当月。
func soul_entry(gen: int, name: String, month: int) -> Dictionary:
	return {
		"kind": KIND_SOUL,
		"title": "第%d世%s落幕" % [gen, name],
		"cityId": "",
		"cityLabel": "世间",
		"detail": "一个活过、挣扎过、留下痕迹的魂转身归于轮回。它的一生沉进了这座世界的史书。",
		"attribution": "转生",
		"month": month,
		"year": _year_label(month),
		"weight": _min_weight,
	}


## 把一条条目追加进世界纪年。分配自增 id，超 maxEntries 时丢最老一条。
## 就地改 world.chronicle，返回带 id 的已存条目。
func record(world: WorldState, entry: Dictionary) -> Dictionary:
	if world == null:
		return {}
	var stored: Dictionary = entry.duplicate(true)
	stored["id"] = int(world.chronicle_seq) + 1
	world.chronicle_seq = int(stored["id"])
	world.chronicle.append(stored)
	while world.chronicle.size() > _max_entries:
		world.chronicle.pop_front()
	return stored


## 纪年条目的中文年标。与主场景 _event_month_label 同一套口径，保证事件流与
## 纪年史书说同一年月。
func _year_label(month: int) -> String:
	@warning_ignore("integer_division")
	var year: int = month / _months_per_year + 1
	var month_in_year: int = month % _months_per_year
	return "第%d年%d月" % [year, month_in_year if month_in_year != 0 else _months_per_year]


static func _city_label(city_id: String) -> String:
	return city_id