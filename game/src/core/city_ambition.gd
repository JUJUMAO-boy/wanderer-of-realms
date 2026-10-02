class_name CityAmbition
extends RefCounted

## 城市野心·势力（第三阶段 C1，D-191~D-193）。
##
## 承接 C4 的势力慢轴：C4 只让「谁在统治这座城」跨年漂移、把易手写进史书，城与城
## 之间仍旧各过各的。C1 要补的正是**城际关系**这一层——每座城按自身维度长出一种
## 「野心」（尚武 / 经商 / 自守 / 崇文），野心相冲的两城才可能兵戎相见；交战城之间
## 的商路随之兴衰（既存的正规商路被战火掐断、新的也修不起来），让 C4 史书里的
## 「势力兴衰」真正咬到玩家做买卖的那本账上。
##
## 全篇守两条铁则：
##   1. **能派生就不落盘**：野心由城市六维派生、城际关系由 (世界种子 ⊕ 纪元 ⊕ 城对)
##      确定性掷出，不新增任何持久字段。同一世界同一纪元读到的战争/通商完全一致，
##      读档回到「离场那一年」就回到同一张邦交图。
##   2. **第 1 年零行为变化**：era 0（原初纪元）恒无战争、也无通商——与 M30/C3 的
##      「era 0 不受扰」同一口径，新开局谁也不打谁。
##
## 数值全走 balance.cityAmbition，这里只留「野心怎么长、谁跟谁相冲」的规则形状，
## 纯规则可无头钉测。

## 野心原型（四档）。
const AMB_MARTIAL: String = "martial"            ## 尚武·以刀立城
const AMB_MERCANTILE: String = "mercantile"      ## 经商·以利通城
const AMB_ISOLATIONIST: String = "isolationist"  ## 自守·关起门过活
const AMB_SCHOLARLY: String = "scholarly"        ## 崇文·以书为城徽

const AMBITIONS: Array = [AMB_MARTIAL, AMB_MERCANTILE, AMB_ISOLATIONIST, AMB_SCHOLARLY]

## 城际关系（三档）。
const REL_WAR: String = "war"           ## 交战（相冲且掷中）
const REL_ACCORD: String = "accord"     ## 通商（同野心且掷中）
const REL_NEUTRAL: String = "neutral"   ## 井水不犯河水

## 野心 → 可读标签与一句城性描述（过 A1 文风闸的单一来源）。
const AMBITION_LABELS: Dictionary = {
	AMB_MARTIAL: "尚武",
	AMB_MERCANTILE: "经商",
	AMB_ISOLATIONIST: "自守",
	AMB_SCHOLARLY: "崇文",
}
const AMBITION_TRAITS: Dictionary = {
	AMB_MARTIAL: "军旗压过账簿，这座城的野心写在刀口上。",
	AMB_MERCANTILE: "银钱说话比号角响，先算利、再论义。",
	AMB_ISOLATIONIST: "关起门来过自己的日子，外头的风云懒得理会。",
	AMB_SCHOLARLY: "钟楼与书页是它的城徽，宁可慢，不肯糙。",
}
const RELATION_LABELS: Dictionary = {
	REL_WAR: "交战",
	REL_ACCORD: "通商",
	REL_NEUTRAL: "井水不犯河水",
}

## 野心相冲的对（对称）。相冲的两城才可能开战——这是「政策冲突」这一层的形状，
## 固定写在规则层，不落 JSON。
const OPPOSED_PAIRS: Array = [
	[AMB_MARTIAL, AMB_MERCANTILE],
	[AMB_MARTIAL, AMB_SCHOLARLY],
	[AMB_ISOLATIONIST, AMB_MERCANTILE],
]

## 势力纪年条目的权重（> Chronicle 默认门槛 250，保证进史书）。
const WAR_WEIGHT: int = 300

const _SALT: int = 0x51A7B3C9


# --- 野心 ---

## 一座城的野心。由**开局本相六维**（cities.json 的配置值）派生：得分最高者当选，
## 平手时按 (世界种子 ⊕ 纪元 ⊕ 城) 确定性择一。
##
## 刻意读「配置里的本相维度」而不是「运行时正在漂移的维度」：城性是一城的底色，
## 若随月度六维微涨微跌，同一纪元内邦交会翻来覆去、读档也复现不了同一张邦交图，
## 更会让「交战掐断商路」在无关的城对上误触发。取本相即让野心成为 (世界种子⊕
## 纪元⊕城) 的纯函数——纪元只用于平手择一，本相则给每城一个稳定的性子。
static func ambition_for(city: City, era: int, world_seed: int) -> String:
	if city == null:
		return AMB_ISOLATIONIST
	var scores: Dictionary = ambition_scores(city)
	var best: int = -1
	for amb in AMBITIONS:
		best = maxi(best, int(scores[amb]))
	var tied: Array = []
	for amb in AMBITIONS:
		if int(scores[amb]) == best:
			tied.append(amb)
	if tied.size() == 1:
		return str(tied[0])
	var rng: DeterministicRNG = _ambition_rng(city.city_id, era, world_seed)
	return str(tied[rng.next_int(tied.size())])


## 各野心原型的得分（纯函数，便于测试与调参）。维度取该城的开局本相配置。
static func ambition_scores(city: City) -> Dictionary:
	if city == null:
		return {}
	return ambition_scores_from_dims(ContentLoader.get_city_config(city.city_id))


## 本相六维 → 各野心得分。本相即 cities.json 里这座城开局的那组六维。
static func ambition_scores_from_dims(dims: Dictionary) -> Dictionary:
	var faction: int = int(dims.get("faction", 0))
	var wealth: int = int(dims.get("wealth", 0))
	var development: int = int(dims.get("development", 0))
	var security: int = int(dims.get("security", 0))
	var culture: int = int(dims.get("culture", 0))
	return {
		AMB_MARTIAL: faction * 5 + security * 3 + (100 - culture) * 2,
		AMB_MERCANTILE: wealth * 6 + development * 4,
		AMB_ISOLATIONIST: (100 - wealth) * 4 + (100 - development) * 4 + security * 2,
		AMB_SCHOLARLY: culture * 7 + development * 3,
	}


static func ambition_label(ambition: String) -> String:
	return str(AMBITION_LABELS.get(ambition, ambition))


static func ambition_trait(ambition: String) -> String:
	return str(AMBITION_TRAITS.get(ambition, ""))


# --- 城际关系 ---

## 两城在本纪元的关系：war / accord / neutral。era <= 0 恒 neutral（第 1 年零行为
## 变化）。入参顺序不影响结果（内部按城 id 排序后掷，保证 A↔B 与 B↔A 同解）。
static func relation_for(
	a: City, b: City, era: int, world_seed: int, cfg: Dictionary = {}
) -> String:
	if a == null or b == null or a.city_id == b.city_id:
		return REL_NEUTRAL
	if era <= 0:
		return REL_NEUTRAL
	var amb_a: String = ambition_for(a, era, world_seed)
	var amb_b: String = ambition_for(b, era, world_seed)
	var rng: DeterministicRNG = _relation_rng(a.city_id, b.city_id, era, world_seed)
	if _opposed(amb_a, amb_b):
		if rng.chance(_war_chance(cfg)):
			return REL_WAR
		return REL_NEUTRAL
	if amb_a == amb_b:
		if rng.chance(_accord_chance(cfg)):
			return REL_ACCORD
	return REL_NEUTRAL


static func at_war(a: City, b: City, era: int, world_seed: int, cfg: Dictionary = {}) -> bool:
	return relation_for(a, b, era, world_seed, cfg) == REL_WAR


## 交战城之间的商路是否（该被拒建 / 应被掐断）。传奇航线由调用方豁免。
static func route_blocked(
	a: City, b: City, era: int, world_seed: int, cfg: Dictionary = {}
) -> bool:
	return at_war(a, b, era, world_seed, cfg)


## 某城与其余各城的邦交列表（交战在前、通商次之、中立垫底）。
static func relations_for_city(
	city_id: String, world: WorldState, era: int, world_seed: int, cfg: Dictionary = {}
) -> Array:
	var out: Array = []
	if world == null:
		return out
	var me: City = world.get_city(city_id)
	if me == null:
		return out
	for other_id in world.get_city_ids():
		var oid: String = str(other_id)
		if oid == city_id:
			continue
		var other: City = world.get_city(oid)
		if other == null:
			continue
		var rel: String = relation_for(me, other, era, world_seed, cfg)
		out.append({
			"cityId": oid,
			"cityLabel": other.display_name,
			"relation": rel,
			"relationLabel": relation_label(rel),
		})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var rx: int = _relation_rank(str(x["relation"]))
		var ry: int = _relation_rank(str(y["relation"]))
		if rx != ry:
			return rx < ry
		return str(x["cityId"]) < str(y["cityId"]))
	return out


## 邦交一览的短句（供城市面板统计行）。没有战也没有通商，就说「四邻无事」。
static func diplomacy_summary(relations: Array) -> String:
	var wars: int = 0
	var accords: int = 0
	for row in relations:
		var rel: String = str(row.get("relation", REL_NEUTRAL))
		if rel == REL_WAR:
			wars += 1
		elif rel == REL_ACCORD:
			accords += 1
	var parts: Array = []
	if wars > 0:
		parts.append("交战 %d" % wars)
	if accords > 0:
		parts.append("通商 %d" % accords)
	if parts.is_empty():
		return "四邻无事"
	return " · ".join(PackedStringArray(parts))


static func relation_label(rel: String) -> String:
	return str(RELATION_LABELS.get(rel, rel))


# --- 纪年 ---

## 城际开战的纪年条目（纯函数）。接 M16 Chronicle。带一处按城的荒诞细节锚过 A1 文风闸。
static func war_entry(
	world: WorldState, city_a_id: String, city_b_id: String, month: int, year: String
) -> Dictionary:
	var a: City = null if world == null else world.get_city(city_a_id)
	var b: City = null if world == null else world.get_city(city_b_id)
	var a_label: String = a.display_name if a != null else city_a_id
	var b_label: String = b.display_name if b != null else city_b_id
	var detail: String = "%s与%s的商队连夜改道，官道上竖起了拒马。两国旗号一挂，先断的是" \
		% [a_label, b_label]
	return {
		"kind": Chronicle.KIND_WAR,
		"title": "%s 与 %s 兵戎相见" % [a_label, b_label],
		"cityId": city_a_id,
		"cityLabel": a_label,
		"detail": detail + _war_tail(a_label, b_label),
		"attribution": "战事",
		"month": month,
		"year": year,
		"weight": WAR_WEIGHT,
	}


# --- 内部 ---

static func _opposed(amb_a: String, amb_b: String) -> bool:
	for pair in OPPOSED_PAIRS:
		if (str(pair[0]) == amb_a and str(pair[1]) == amb_b) \
			or (str(pair[0]) == amb_b and str(pair[1]) == amb_a):
			return true
	return false


static func _relation_rank(rel: String) -> int:
	if rel == REL_WAR:
		return 0
	if rel == REL_ACCORD:
		return 1
	return 2


static func _war_chance(cfg: Dictionary) -> float:
	return clampf(float(cfg.get("warChanceBp", 4500)) / 10000.0, 0.0, 1.0)


static func _accord_chance(cfg: Dictionary) -> float:
	return clampf(float(cfg.get("accordChanceBp", 6000)) / 10000.0, 0.0, 1.0)


## 野心平手时的择一 RNG，只认 (城, 纪元, 世界种子)。
static func _ambition_rng(city_id: String, era: int, world_seed: int) -> DeterministicRNG:
	var seed: int = (world_seed ^ (era * 2654435761) ^ String(city_id).hash() ^ _SALT) \
		& DeterministicRNG.MASK32
	return DeterministicRNG.new(seed)


## 城对关系的掷骰 RNG。按城 id 排序后取盐，保证 A↔B 与 B↔A 同解。
static func _relation_rng(
	a_id: String, b_id: String, era: int, world_seed: int
) -> DeterministicRNG:
	var x: String = a_id
	var y: String = b_id
	if y < x:
		var tmp: String = x
		x = y
		y = tmp
	var seed: int = (world_seed ^ (era * 2654435761) ^ String(x).hash()
		^ (String(y).hash() * 37) ^ _SALT) & DeterministicRNG.MASK32
	return DeterministicRNG.new(seed)


## 战事的荒诞细节锚：按主动方城取一处意象，凑密度过 MenuStyle 筛（P8 每 N 字一处荒诞）。
static func _war_tail(a_label: String, b_label: String) -> String:
	match a_label:
		"艾德兰":
			return " 传令官念了三遍战书，才发现把对方城名念错了两个字，干脆照错的打。"
		"索恩港":
			return " 码头的水手把对方货船的旗子换成了自家破帆，扬长而去。"
		"铁锤堡":
			return " 熔炉连夜改铸兵刃，废矿渣堆到城门口，孩子们拿来当弹珠玩。"
		"银月塔":
			return " 占星师在星图上圈出敌城的方位，笔尖一抖，圈进了自家后院。"
		"绿荫":
			return " 树人把边界的界碑连根拔起，走了三步，又插回原处——只是换了个朝向。"
		"十字路":
			return " 竞技场挂出「今日不打」的牌子，底下用小字补了一句「明日也不一定」。"
		"霜语堡":
			return " 冰川把两家的界河冻成一条硬邦邦的白道，谁先踩滑谁先示弱。"
		_:
			return " %s的商队把货卸在界碑前，扭头就走——留下%s的人对着一地箱子发愣。" \
				% [a_label, b_label]