class_name FamilyViewModel
extends RefCounted

## 家族面板的视图模型（A3，D-181）。同其它视图模型一个理由："面板该显示什么"是
## 纯函数，能在无头环境里被验收测试钉住；"怎么画"留给 FamilyPanel。
##
## 它只消费 FamilyGate 已落盘的 avatar.family（现配偶）与 world.family.histories
## （家族史），把求亲的门槛、成婚的折扣、丧偶的来路排成一行行可读的文案。不改
## 任何状态——家族影响商业的折扣已经由 Economy.get_price 乘进价目，这里只是把
## 「你为什么在这座城买得便宜」摊开给玩家看。

## 家族史只认 FamilyGate 记下的这几栏；别处往 histories 里塞别的键，这里忽略。
const HISTORY_KEYS: Array = ["npcId", "name", "cityId", "marriedAt", "widowedAt", "widowClass"]


## 把 avatar + world 的家族现状组装成面板可画的 view。
static func build(avatar: PlayerAvatar, world: WorldState) -> Dictionary:
	var view: Dictionary = {
		"subject": "家族与姻缘",
		"histories": [],
	}
	if world == null:
		return view
	# 家族史：成婚在后、离世在前的条目照落盘顺序排。
	for h in (world.family.get("histories", []) as Array):
		var entry: Dictionary = _history_entry(h)
		if not entry.is_empty():
			view["histories"].append(entry)
	if avatar == null:
		return view

	var fam: Dictionary = FamilyGate.family(avatar)
	view["married"] = not fam.is_empty()
	view["discountPct"] = FamilyGate.discount_pct()
	if fam.is_empty():
		view["spouseName"] = ""
		view["spouseCity"] = ""
		view["marriedAtLabel"] = ""
		view["discountCity"] = ""
		view["courting"] = "好感到亲密的居民，可以在「居民」里向他求婚。嫁了人，那座城的铺子会念你一份情。"
	else:
		view["spouseName"] = str(fam.get("name", ""))
		view["spouseCity"] = _city_name(world, str(fam.get("cityId", "")))
		view["marriedAtLabel"] = _month_label(int(fam.get("marriedAt", 0)))
		view["discountCity"] = str(fam.get("discountCityId", ""))
		view["courting"] = ""
	if not str(avatar.bereaved_note).is_empty():
		view["bereaved"] = str(avatar.bereaved_note)
	return view


## 把一条家族史记录排成一行。只有 FamilyGate 写的字段才读。
static func _history_entry(h: Dictionary) -> Dictionary:
	if str(h.get("npcId", "")).is_empty():
		return {}
	var when: String = _month_label(int(h.get("marriedAt", 0)))
	var text: String = "你娶了「%s」（%s）。" % [str(h.get("name", "")), str(h.get("cityId", ""))]
	var wid: int = int(h.get("widowedAt", -1))
	if wid >= 0:
		text += "%s失了你（%s）。" % [
			_month_label(wid),
			"离世" if str(h.get("widowClass", "")) == FamilyGate.WIDOW_CLASS_DEATH else "转世",
		]
	return {"when": when, "text": text}


static func _city_name(world: WorldState, city_id: String) -> String:
	if world == null:
		return city_id
	var city: City = world.get_city(city_id)
	return city.display_name if city != null else city_id


static func _month_label(m: int) -> String:
	@warning_ignore("integer_division")
	var year: int = m / 12 + 1
	var month_in_year: int = m % 12
	return "第%d年%d月" % [year, month_in_year if month_in_year != 0 else 12]