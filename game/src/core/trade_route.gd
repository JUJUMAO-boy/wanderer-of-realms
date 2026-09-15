class_name TradeRoute
extends RefCounted

## 贸易路线。正规商路与走私航线共用这个结构，差异全部落在判定与收益系数上
## （《世界模拟量化规则》9.3 与 9.4 节）。
##
## 两端城市存成有序对（city_a < city_b，按字符串比较），routeId 由两端拼出。
## 这样同一条路线无论从哪一端建立，得到的 ID 都一样，查重与结算排序都不需要
## 额外的规范化步骤。

const KIND_REGULAR: String = "regular"
const KIND_SMUGGLING: String = "smuggling"
## 传奇航线。只有城市事件（EV-02 讨伐利维坦）会给出这一类：收益高于走私、不受
## 治安门槛约束、不被查抄、也不因治安崩坏而中断——它买到的正是"不受这套规则约束"。
const KIND_LEGENDARY: String = "legendary"

const ALL_KINDS: Array = [KIND_REGULAR, KIND_SMUGGLING, KIND_LEGENDARY]

## 归属。这条航线是谁的，决定了被查抄时账单寄给谁。
##
## 世界航线（空串）是 NPC 商旅自己跑出来的，被查抄是城市自己的损失；只有
## 玩家自己建的航线，被查抄才扣玩家的声誉与善恶（量化规则 6 章「垄断贸易
## 路线：该路线收益归玩家」——有收益才有代价，两者必须成对）。
## 原先没有这个字段，查抄一律扣玩家，于是玩家替全世界的走私航线背锅。
const OWNER_WORLD: String = ""
const OWNER_PLAYER: String = "player"

var route_id: String = ""
var city_a: String = ""
var city_b: String = ""
var kind: String = KIND_REGULAR
var established_month: int = 0
var owner_id: String = OWNER_WORLD


static func make(
	p_city_x: String, p_city_y: String, p_kind: String, p_month: int,
	p_owner_id: String = OWNER_WORLD
) -> TradeRoute:
	var r := TradeRoute.new()
	r.city_a = p_city_x
	r.city_b = p_city_y
	if r.city_b < r.city_a:
		var swap: String = r.city_a
		r.city_a = r.city_b
		r.city_b = swap
	r.kind = p_kind
	r.established_month = p_month
	r.owner_id = p_owner_id
	r.route_id = route_id_for(r.city_a, r.city_b)
	return r


static func route_id_for(city_x: String, city_y: String) -> String:
	var a: String = city_x
	var b: String = city_y
	if b < a:
		a = city_y
		b = city_x
	return "%s__%s" % [a, b]


func involves(city_id: String) -> bool:
	return city_id == city_a or city_id == city_b


func other_city(city_id: String) -> String:
	if city_id == city_a:
		return city_b
	if city_id == city_b:
		return city_a
	return ""


func is_smuggling() -> bool:
	return kind == KIND_SMUGGLING


func is_legendary() -> bool:
	return kind == KIND_LEGENDARY


func is_player_owned() -> bool:
	return owner_id == OWNER_PLAYER


func to_dict() -> Dictionary:
	return {
		"routeId": route_id,
		"cityA": city_a,
		"cityB": city_b,
		"kind": kind,
		"establishedMonth": established_month,
		"ownerId": owner_id,
	}


static func from_dict(data: Dictionary) -> TradeRoute:
	var r := TradeRoute.new()
	r.route_id = str(data.get("routeId", ""))
	r.city_a = str(data.get("cityA", ""))
	r.city_b = str(data.get("cityB", ""))
	r.kind = str(data.get("kind", KIND_REGULAR))
	r.established_month = int(data.get("establishedMonth", 0))
	# 旧存档没有这个字段，缺省即"世界的航线"——那正是它们在加这个字段之前的含义
	r.owner_id = str(data.get("ownerId", OWNER_WORLD))
	if r.route_id.is_empty():
		r.route_id = route_id_for(r.city_a, r.city_b)
	return r
