class_name EncounterSystem
extends RefCounted

## 世界遭遇（《技术设计文档》9.12 节，D-58 ~ D-61）。
##
## 在此之前，按 B 拉两个同城居民是**临时的遭遇入口**：它把 M5 从逻辑层搬到了窗口里，
## 但"谁在什么地方因为什么拦住你"这件事一处也没有。这一层把它补上。
##
## 边界与 EventSystem 一样：**不碰城市六维、不提交 StateChange**。野外打一场架不该
## 改变一座城的发展度——城市状态的唯一写入口仍是 WorldSim.applyStateChange（10.1 第 2 条，
## 见 D-47 对这条约束适用范围的收窄）。玩家的钱与背包同样由调用方结清。
##
## 与 EventSystem 的分别有两处：
##   1. 遭遇**要有随机数**（走到哪、遇上谁、几个人），所以随机源由调用方注入，
##      而且必须是与世界演化分开的那一支——"路上撞见一头狼"不该改变城市接下来的走向。
##   2. 遭遇**不落盘**：它短命（一次判定 → 一个决定 → 打完），会话状态留在主场景里，
##      与战斗会话同一条处境（读档回到地图，那一场就没了）。
##
## 三个决定（D-60）：迎战 / 绕开 / 交涉。"遭遇里没有回头路"是刻意的——三条路都通向
## 结果，绕开要花时间且可能甩不掉，交涉只对讲道理的人形有效。给一个免费的返回键，
## 遭遇就退化成一道可以随手关掉的提示框。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_CONTENT_MISSING: String = "CONTENT_MISSING"

## 遭遇发生在什么样的地方。只有这三种：城里（进城那一下）、商路上、荒野。
const CONTEXT_CITY: String = "city"
const CONTEXT_ROAD: String = "road"
const CONTEXT_WILD: String = "wild"

const KIND_MONSTER: String = "monster"
const KIND_NPC: String = "npc"

const CHOICE_FIGHT: String = "fight"
const CHOICE_AVOID: String = "avoid"
const CHOICE_PARLEY: String = "parley"

const OUTCOME_WON: String = "won"
const OUTCOME_LOST: String = "lost"
const OUTCOME_AVOIDED: String = "avoided"
const OUTCOME_PARLEYED: String = "parleyed"

## 荒野一侧偏爱哪些分类、商路一侧偏爱哪些分类（D-59）。石与狼不会在官道上
## 排队劫道，"路上遇上的多半是人"是玩家一望即知的常识。
const WILD_CATEGORIES: Array = ["beast", "undead"]
const ROAD_CATEGORIES: Array = ["humanoid"]

const BP_FULL: int = 10000

var world: WorldState = null
var grid: MapGrid = null

var _rules: Dictionary = {}
var _derived: DerivedStats = null
var _profession_category: Dictionary = {}  ## professionId -> category


static func create(
	p_world: WorldState, p_grid: MapGrid, p_derived: DerivedStats = null
) -> EncounterSystem:
	var system := EncounterSystem.new()
	system.world = p_world
	system.grid = p_grid
	system._derived = p_derived if p_derived != null else DerivedStats.new()
	system._rules = ContentLoader.get_balance_section("encounters")
	system._profession_category = EncounterSystem.profession_categories()
	return system


## 职业类别表（11.3 节）。城里挑拦路的人要按它筛（军中与灰色两个类别），
## 只建一次：每次判定都遍历一遍职业表没有意义。
static func profession_categories() -> Dictionary:
	var out: Dictionary = {}
	var professions: Variant = ContentLoader.get_profession_config().get("professions", null)
	if not (professions is Array):
		return out
	for entry in professions:
		if entry is Dictionary:
			out[str((entry as Dictionary).get("professionId", ""))] = \
				str((entry as Dictionary).get("category", ""))
	return out


func rules() -> Dictionary:
	return _rules


# --- 位置与危险（D-59）---

## 到最近一座城的曼哈顿距离（格）。
func distance_to_nearest_city(pos: Vector2i) -> int:
	var best: int = -1
	for city_id in world.get_city_ids():
		var city: City = world.get_city(city_id)
		if city == null:
			continue
		var distance: int = MapGrid.manhattan(pos, Vector2i(city.coord_x, city.coord_y))
		if best < 0 or distance < best:
			best = distance
	return maxi(0, best)


## 这一格属于第几档危险区（0 起）。边界取自 rules.tierBoundaries。
func tier_at(pos: Vector2i) -> int:
	var boundaries: Array = _array_of(_rules.get("tierBoundaries", null))
	var distance: int = distance_to_nearest_city(pos)
	var tier: int = 0
	for edge in boundaries:
		if distance > int(edge):
			tier += 1
	return tier


## 某一档的 TL 区间（闭区间），下标越界时退到最后一档。
func tier_threat_range(tier: int) -> Array:
	var lows: Array = _array_of(_rules.get("tierThreatMin", null))
	var highs: Array = _array_of(_rules.get("tierThreatMax", null))
	if lows.is_empty() or highs.is_empty():
		return [1, 1]
	var index: int = clampi(tier, 0, mini(lows.size(), highs.size()) - 1)
	return [int(lows[index]), int(highs[index])]


## 这一格算不算"在路上"：点到任意一条路线（正规商路或走私航线）线段的距离
## 在 roadWidthTiles 以内。地图上画出来的那条线就是判据——玩家看到的与实际
## 判定的必须是同一件事。
func on_route(pos: Vector2i) -> bool:
	var width: int = int(_rules.get("roadWidthTiles", 2))
	for route in world.get_routes_sorted():
		var a: City = world.get_city(str(route.city_a))
		var b: City = world.get_city(str(route.city_b))
		if a == null or b == null:
			continue
		if _distance_to_segment(
			pos, Vector2i(a.coord_x, a.coord_y), Vector2i(b.coord_x, b.coord_y)
		) <= float(width):
			return true
	return false


## 这一格属于哪一类地方。站在城里是城里，不是城里但在路上就是在路上。
func context_at(pos: Vector2i) -> String:
	if not grid.get_city_id_at(pos.x, pos.y).is_empty():
		return CONTEXT_CITY
	return CONTEXT_ROAD if on_route(pos) else CONTEXT_WILD


## 一次判定撞上的概率（基点，D-58）：
##   城里 = cityBaseChanceBp × (citySecurityCeiling − 治安) / citySecurityCeiling
##   路上 = roadChanceBp      荒野 = wildChanceBp
##
## 治安这一项是"乱世的城里也不安全"的全部落点：治安 30 以上进多少次城都没事，
## 十字路（20）与赤沙（30）才会出事——而且这件事能从城市面板上读出来。
func encounter_chance_bp(context: String, city_id: String) -> int:
	if context != CONTEXT_CITY:
		return maxi(0, int(_rules.get("roadChanceBp" if context == CONTEXT_ROAD \
			else "wildChanceBp", 0)))
	var ceiling: int = maxi(1, int(_rules.get("citySecurityCeiling", 30)))
	var city: City = world.get_city(city_id)
	if city == null:
		return 0
	var security: int = city.get_dimension(City.DIM_SECURITY)
	if security >= ceiling:
		return 0
	var base: int = maxi(0, int(_rules.get("cityBaseChanceBp", 0)))
	return int(round(float(base) * float(ceiling - security) / float(ceiling)))


## 走了这么多格之后该不该判一次（D-58：野外每 stepInterval 格一次）。
func should_check(steps: int) -> bool:
	return steps >= maxi(1, int(_rules.get("stepInterval", 8)))


# --- 触发 ---

## 做一次判定。force 为真时跳过概率（调试用的"就地惹一场"，走的仍是下面这条
## 完全相同的路，所以调试看到的与真遇上的是同一件事）。
##
## 返回 {ok, engaged, chanceBp, encounter, errorCode, error}。engaged 为假是正常结果，
## 不是错误——绝大多数判定都不该撞上人。
func check(
	context: String, city_id: String, month: int, encounter_id: String,
	rng: DeterministicRNG, force: bool = false
) -> Dictionary:
	if world == null or grid == null:
		return _fail(ERROR_INVALID_ARGUMENT, "遭遇系统还没接到世界上")
	if not [CONTEXT_CITY, CONTEXT_ROAD, CONTEXT_WILD].has(context):
		return _fail(ERROR_INVALID_ARGUMENT, "未知的遭遇场合：%s" % context)

	var source: DeterministicRNG = rng if rng != null else DeterministicRNG.new(20260915)
	var chance: int = encounter_chance_bp(context, city_id)
	if not force and source.next_int(BP_FULL) >= chance:
		return {
			"ok": true, "engaged": false, "chanceBp": chance,
			"encounter": {}, "errorCode": ERROR_NONE, "error": "",
		}

	var spec: Dictionary = roll(context, city_id, month, encounter_id, source)
	if spec.is_empty():
		return _fail(ERROR_CONTENT_MISSING, "这一带没有能拦住你的对手（看生物表与三档的 TL 区间）")
	return {
		"ok": true, "engaged": true, "chanceBp": chance,
		"encounter": spec, "errorCode": ERROR_NONE, "error": "",
	}


## 摇一场遭遇。不判概率，所以调用它之前先过 check（或自己判）。
func roll(
	context: String, city_id: String, month: int, encounter_id: String,
	rng: DeterministicRNG
) -> Dictionary:
	var source: DeterministicRNG = rng if rng != null else DeterministicRNG.new(20260915)
	var opponents: Array = []
	var kind: String = KIND_MONSTER
	var title: String = ""
	if context == CONTEXT_CITY:
		opponents = _roll_city_opponents(city_id, encounter_id, source)
		kind = KIND_NPC
		title = _city_title(city_id)
	else:
		opponents = _roll_monsters(context, encounter_id, source)
		if not opponents.is_empty():
			title = str(opponents[0].get("displayName", ""))
	if opponents.is_empty():
		return {}

	var threat: int = 0
	for opponent in opponents:
		threat = maxi(threat, int(opponent.get("threatLevel", 0)))
	var pos: Vector2i = Vector2i(0, 0)
	if world.avatar != null:
		pos = Vector2i(world.avatar.pos_x, world.avatar.pos_y)
	var parleyable: bool = is_parleyable(opponents)
	return {
		"encounterId": encounter_id,
		"context": context,
		"cityId": city_id,
		# 城里那一场"最近的城市"就是脚下这座；野外的才是真的离你最近的那座。
		# 界面上的城名与交涉用的声誉都读它，所以这里不能用"离玩家最近"，
		# 进城那一下的坐标正落在城上，两者本来就该是同一座。
		"nearestCityId": city_id if context == CONTEXT_CITY else nearest_city_id(pos),
		"pos": [pos.x, pos.y],
		"tier": tier_at(pos),
		"kind": kind,
		"title": title,
		"threatLevel": threat,
		"opponents": opponents,
		"parleyable": parleyable,
		"parleyBlockReason": parley_block_reason_of(
			parleyable, str((opponents[0] as Dictionary).get("category", ""))
		),
		"month": month,
		"story": _story_of(context, title, opponents, city_id),
	}


## 离这一格最近的那座城。野外的遭遇也要报出"这是哪一带"，否则玩家不知道该
## 往哪边跑——地图上的方向感是遇险时唯一有用的信息。
func nearest_city_id(pos: Vector2i) -> String:
	var best: String = ""
	var best_distance: int = -1
	for city_id in world.get_city_ids():
		var city: City = world.get_city(city_id)
		if city == null:
			continue
		var distance: int = MapGrid.manhattan(pos, Vector2i(city.coord_x, city.coord_y))
		if best_distance < 0 or distance < best_distance:
			best_distance = distance
			best = str(city_id)
	return best


# --- 对手 ---

## 三个决定的可用性：交涉只对讲道理的人形。（野兽与亡灵不跟你谈。）
func is_parleyable(opponents: Array) -> bool:
	if opponents.is_empty():
		return false
	for opponent in opponents:
		if not bool(opponent.get("parleyable", false)):
			return false
	return true


## 把对手档案变成参战单位规格。站位由调用方给（战场版式属表现层），
## 这一层只管"这些人是谁、有多强"。
func units_of(spec: Dictionary, spawns: Array) -> Array:
	var out: Array = []
	var opponents: Array = _array_of(spec.get("opponents", null))
	for i in range(opponents.size()):
		var opponent: Dictionary = opponents[i]
		var spawn: Array = spawns[i % maxi(1, spawns.size())] if not spawns.is_empty() else [0, 0]
		out.append({
			"unitId": str(opponent.get("unitId", "unit-enemy-%d" % (i + 1))),
			"side": Combat.SIDE_ENEMY,
			"name": str(opponent.get("name", "")),
			"attributes": (opponent.get("attributes", {}) as Dictionary).duplicate(),
			"skills": {},
			"weaponTemplateId": "",
			# 生物不背铁剑：伤害与射程直接给（战斗层收 weaponAttack / weaponRange）
			"weaponAttack": int(opponent.get("attack", 0)),
			"weaponRange": int(opponent.get("attackRange", 1)),
			"armor": int(opponent.get("armor", 0)),
			"magicResist": int(opponent.get("magicResist", 0)),
			"luck": 0,
			"position": (spawn as Array).duplicate(),
			"threatLevel": int(opponent.get("threatLevel", 1)),
			"hp": int(opponent.get("hp", 0)),
			"maxHp": int(opponent.get("hp", 0)),
		})
	return out


## 荒野与路上的对手：按这一格的档位取 TL 区间，再在该区间里挑一条生物。
func _roll_monsters(context: String, encounter_id: String, rng: DeterministicRNG) -> Array:
	var pos: Vector2i = Vector2i(0, 0)
	if world.avatar != null:
		pos = Vector2i(world.avatar.pos_x, world.avatar.pos_y)
	var tier: int = tier_at(pos)
	var range: Array = tier_threat_range(tier)
	var pool: Array = []
	var preferred: Array = WILD_CATEGORIES if context == CONTEXT_WILD else ROAD_CATEGORIES
	for entry in ContentLoader.get_monsters():
		if not (entry is Dictionary):
			continue
		var monster: Dictionary = entry
		var tl: int = int(monster.get("threatLevel", 0))
		if tl < int(range[0]) or tl > int(range[1]):
			continue
		pool.append(monster)
	# 这一带偏好的分类先挑；一条都没有就退回整档（否则"路上只会遇到人形"
	# 会让某一段距离上的整档内容凭空消失）
	var favoured: Array = []
	for monster in pool:
		if preferred.has(str(monster.get("category", ""))):
			favoured.append(monster)
	var candidates: Array = favoured if not favoured.is_empty() else pool
	if candidates.is_empty():
		return []

	var picked: Dictionary = candidates[rng.next_int(candidates.size())]
	var count: int = clampi(
		rng.range_int(int(picked.get("groupMin", 1)), int(picked.get("groupMax", 1))),
		1, maxi(1, int(_rules.get("maxOpponents", 3)))
	)
	var out: Array = []
	for i in range(count):
		out.append(_monster_profile(picked, i, count, encounter_id))
	return out


func _monster_profile(monster: Dictionary, index: int, count: int, encounter_id: String) -> Dictionary:
	var name: String = str(monster.get("displayName", ""))
	if count > 1:
		name = "%s %d" % [name, index + 1]
	return {
		# 单位 id 带遭遇号：世界标记写成 combat.<处置>.<unitId>，带上它才追得到
		# "这一场发生在哪一次遭遇里"
		"unitId": "%s-%d" % [encounter_id, index + 1],
		"name": name,
		"displayName": str(monster.get("displayName", "")),
		"category": str(monster.get("category", "")),
		"threatLevel": int(monster.get("threatLevel", 1)),
		"attributes": (monster.get("attributes", {}) as Dictionary).duplicate(),
		"hp": int(monster.get("hp", 0)),
		"armor": int(monster.get("armor", 0)),
		"magicResist": int(monster.get("magicResist", 0)),
		"attack": int(monster.get("attack", 0)),
		"attackRange": int(monster.get("attackRange", 1)),
		"parleyable": str(monster.get("category", "")) == ContentLoader.MONSTER_PARLEYABLE_CATEGORY,
		"isNpc": false,
		"npcId": "",
	}


## 城里的对手：从这座城的模拟居民里，按职业类别（军中与灰色）挑几个成年人。
## 用真人不只是省一张表——处置（放走/俘虏/补刀）记在标记里，将来要追到人身上。
func _roll_city_opponents(
	city_id: String, encounter_id: String, rng: DeterministicRNG
) -> Array:
	var city: City = world.get_city(city_id)
	if city == null:
		return []
	var wanted: Array = _array_of(_rules.get("cityNpcCategories", null))
	var pool: Array = []
	for npc_id in city.npc_ids:
		var npc: SimNpc = world.get_npc(str(npc_id))
		if npc == null or npc.is_named or npc.age < NpcGenerator.ADULT_AGE:
			continue
		if not wanted.has(str(_profession_category.get(npc.profession_id, ""))):
			continue
		pool.append(npc)
	if pool.is_empty():
		return []

	# 数量 1–2：城里拦路的通常也就一两个人，一群人在街上堵你不像这座城市
	# 平时会发生的事（野外的"成群"由生物表自己给，见 groupMin/groupMax）
	var low: int = maxi(1, int(_rules.get("cityNpcMin", 1)))
	var high: int = maxi(low, int(_rules.get("cityNpcMax", 2)))
	var count: int = clampi(
		rng.range_int(low, high), 1, maxi(1, int(_rules.get("maxOpponents", 3)))
	)
	count = mini(count, pool.size())
	var out: Array = []
	# 等距取样而不是随机取：不断按 B 时，随机取会在同一座城里反复撞上同一个人
	var stride: int = maxi(1, pool.size() / count)
	for i in range(count):
		var npc: SimNpc = pool[mini(pool.size() - 1, i * stride)]
		out.append(_npc_profile(npc, i, count, encounter_id))
	return out


func _npc_profile(npc: SimNpc, index: int, count: int, encounter_id: String) -> Dictionary:
	var low: int = int(_rules.get("cityNpcAttributeMin", 8))
	var high: int = maxi(low, int(_rules.get("cityNpcAttributeMax", 14)))
	# 模拟 NPC 身上没有属性字段（世界模拟不需要它），所以只能在这一层现抽。
	# 用遭遇自己的随机源，保证同一场可复现。
	var rng := DeterministicRNG.new(ItemInstance.seed_from_text(
		"%s|%s|%d" % [encounter_id, npc.npc_id, index]
	))
	var attributes: Dictionary = {}
	for attribute in PlayerAvatar.ALL_ATTRIBUTES:
		attributes[attribute] = rng.range_int(low, high)
	var name: String = npc.display_name()
	if count > 1:
		name = "%s（%d）" % [name, index + 1]
	return {
		# 人形对手的单位 id 直接用 NPC 的 id：标记写的就是这个 id，
		# 于是"谁被怎么了"能一路追到那个人身上
		"unitId": npc.npc_id,
		"name": name,
		"displayName": npc.display_name(),
		"category": ContentLoader.MONSTER_PARLEYABLE_CATEGORY,
		"threatLevel": _threat_level(attributes),
		"attributes": attributes,
		"hp": _derived.max_hp(attributes, _derived.power_level(attributes, {})),
		"armor": int(_common_armor(ContentLoader.get_items())),
		"magicResist": 0,
		"attack": _common_attack(ContentLoader.get_items()),
		"attackRange": 1,
		"parleyable": true,
		"isNpc": true,
		"npcId": npc.npc_id,
	}


## 模拟 NPC 的威胁等级：取实力等级的量级，与主场景算玩家那一头用的是同一条式子。
func _threat_level(attributes: Dictionary) -> int:
	var power: int = _derived.power_level(attributes, {})
	@warning_ignore("integer_division")
	var level: int = 1 + power / 4
	return clampi(level, 1, 40)


# --- 三个决定（D-60）---

## 绕开的成功率（基点）：基础 + 敏捷 × 每点 + 幸运 × 每点，钳在 avoidMinBp–avoidMaxBp。
## 公开出来是为了让界面能把"大概几成"写在做法上，也让这条算式可以被直接断言。
func avoid_chance_bp(attributes: Dictionary, luck: int) -> int:
	var chance: int = int(_rules.get("avoidBaseBp", 4000))
	chance += int(attributes.get(PlayerAvatar.ATTR_DEXTERITY, 0)) \
		* int(_rules.get("avoidPerDexBp", 120))
	chance += luck * int(_rules.get("avoidPerLuckBp", 20))
	return clampi(
		chance, int(_rules.get("avoidMinBp", 500)), int(_rules.get("avoidMaxBp", 9500))
	)


## 绕开判定。掷一次，看能不能甩掉。甩不掉就只能打——所以它不是一个"跳过键"。
func avoid_check(attributes: Dictionary, luck: int, rng: DeterministicRNG) -> Dictionary:
	var chance: int = avoid_chance_bp(attributes, luck)
	var source: DeterministicRNG = rng if rng != null else DeterministicRNG.new(20260915)
	var roll: int = source.next_int(BP_FULL)
	return {
		"ok": true,
		"escaped": roll < chance,
		"chanceBp": chance,
		"rollBp": roll,
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 绕开要花掉的时间（天）。按已有的时间刻度换算，不另造一套"花时间"的概念。
func avoid_time_days() -> int:
	return maxi(0, int(_rules.get("avoidTimeDays", 1)))


## 交涉的成功率（基点）。两端是硬门槛（与委托、商铺同一组 ±60），中间按
## 「基础 + 声誉 × 每点」线性取——名声在这条路上是能兑现的，只是兑得有限。
func parley_chance_bp(reputation: int) -> int:
	if reputation >= int(_rules.get("parleyAcceptReputation", 60)):
		return BP_FULL
	if reputation <= int(_rules.get("parleyRefuseReputation", -60)):
		return 0
	var chance: int = int(_rules.get("parleyBaseBp", 5000)) \
		+ reputation * int(_rules.get("parleyPerReputationBp", 50))
	return clampi(chance, 0, BP_FULL)


func parley_check(reputation: int, rng: DeterministicRNG) -> Dictionary:
	var chance: int = parley_chance_bp(reputation)
	var source: DeterministicRNG = rng if rng != null else DeterministicRNG.new(20260915)
	var roll: int = source.next_int(BP_FULL)
	return {
		"ok": true,
		"accepted": roll < chance,
		"chanceBp": chance,
		"rollBp": roll,
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 交涉失败时的理由。野兽那一条要说清楚"不是名声的问题"——否则玩家会以为
## 是自己名声不够，跑去刷声望。
static func parley_block_reason_of(parleyable: bool, category: String) -> String:
	if parleyable:
		return ""
	if category == "beast":
		return "野兽不听人话"
	if category == "undead":
		return "这些东西没有能谈的余地"
	if category == "dragon":
		return "龙不跟站在地上的人商量"
	return "它们不跟你讲道理"


# --- 结算 ---

## 遭遇的结算。**只产出文案与世界事件流的一条记录**：掉落、世界标记由战斗层与
## 调用方落（10.1 第 3 条"战斗不产生世界后果"那条链路照旧）。
##
## outcome 取 OUTCOME_WON / OUTCOME_LOST / OUTCOME_AVOIDED / OUTCOME_PARLEYED；
## 战斗那两种由 `_settle_combat` 战后调用，另外两种在按下做法时调用。
func resolve(spec: Dictionary, outcome: String, month: int, detail: String = "") -> Dictionary:
	if spec.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这一场遭遇")
	var title: String = str(spec.get("title", "对手"))
	var text: String = ""
	match outcome:
		OUTCOME_WON:
			text = "在%s打退了 %s%s" % [_place_label(spec), title, _detail_suffix(detail)]
		OUTCOME_LOST:
			text = "在%s被 %s 打倒了%s" % [_place_label(spec), title, _detail_suffix(detail)]
		OUTCOME_AVOIDED:
			text = "在%s绕开了 %s（花了 %d 天）" % [
				_place_label(spec), title, avoid_time_days()
			]
		OUTCOME_PARLEYED:
			text = "在%s与 %s 谈拢了，各走各的" % [_place_label(spec), title]
		_:
			return _fail(ERROR_INVALID_ARGUMENT, "未知的遭遇结局：%s" % outcome)
	return {
		"ok": true,
		"outcome": outcome,
		"text": text,
		"notices": [{"month": month, "text": text}],
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 这一场发生在哪里，给文案用。
func _place_label(spec: Dictionary) -> String:
	var context: String = str(spec.get("context", ""))
	var city_id: String = str(spec.get("nearestCityId", ""))
	var city: City = world.get_city(city_id) if world != null else null
	var city_label: String = city.display_name if city != null else "野外"
	match context:
		CONTEXT_CITY:
			return city_label
		CONTEXT_ROAD:
			return "%s外的路上" % city_label
		_:
			return "%s外的荒野" % city_label


func _detail_suffix(detail: String) -> String:
	return "" if detail.is_empty() else "（%s）" % detail


# --- 内部 ---

## 城里那一场"为什么拦住你"。城里的人不是从地里冒出来的，句子要说得出缘由，
## 而缘由只能是这座城的样子（治安越低越说得通，判定本来就按治安算）。
func _city_title(city_id: String) -> String:
	var city: City = world.get_city(city_id)
	if city == null:
		return "拦路的人"
	if city.get_dimension(City.DIM_SECURITY) <= int(_rules.get("citySecurityCeiling", 30)) / 2:
		return "街上的人"
	return "找麻烦的人"


func _story_of(context: String, title: String, opponents: Array, city_id: String) -> String:
	if opponents.is_empty():
		return ""
	var first: Dictionary = opponents[0]
	var count: int = opponents.size()
	var head: String = title if count <= 1 else "%s（%d 个）" % [title, count]
	match context:
		CONTEXT_CITY:
			return "你刚进%s，%s 就跟了上来——这座城的名声，街上比告示牌上说得更清楚。" % [
				world.get_city(city_id).display_name if world.get_city(city_id) != null else "城",
				head,
			]
		CONTEXT_ROAD:
			return "%s 横在路当中。这条路上运货的人都知道，走夜路要结伴。" % head
		_:
			var category: String = str(first.get("category", ""))
			if category == "undead":
				return "这一带的枯骨站了起来。这里死过太多人，土早就记不住了。"
			if category == "dragon":
				return "%s 醒了——龙兽成群，而这片荒野是它们的猎场。" % head
			return "%s 从荒地里窜出来，挡在你面前。" % head


## 城里对手那点装备：随便挑一件普通武器与普通防具，与主场景
## 「陪练用普通货」的旧做法一致（那时的注释：不写死物品 ID，改名后不会静默退化）。
func _common_armor(items: Array) -> int:
	for item in items:
		if str(item.get("category", "")) == "armor" and str(item.get("rarity", "")) == "common":
			return int(item.get("armor", 0))
	return 0


func _common_attack(items: Array) -> int:
	for item in items:
		if str(item.get("category", "")) == "weapon" and str(item.get("rarity", "")) == "common":
			return int(item.get("attack", 0))
	return 1


## 点到线段的最短距离。路线是画在地图上的直线（_draw_map），
## "在路上"就该按几何判，而不是按格子的近似。
static func _distance_to_segment(point: Vector2i, a: Vector2i, b: Vector2i) -> float:
	var p := Vector2(float(point.x), float(point.y))
	var start := Vector2(float(a.x), float(a.y))
	var end := Vector2(float(b.x), float(b.y))
	var span: Vector2 = end - start
	var length_squared: float = span.length_squared()
	if length_squared <= 0.0:
		return p.distance_to(start)
	var t: float = clampf((p - start).dot(span) / length_squared, 0.0, 1.0)
	return p.distance_to(start + span * t)


static func _fail(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false, "engaged": false, "chanceBp": 0,
		"encounter": {}, "errorCode": error_code, "error": message,
	}


## 配置里显式写 null 时 Dictionary.get 的缺省值不生效，所以判型要显式做一次。
static func _array_of(value: Variant) -> Array:
	return value if value is Array else []
