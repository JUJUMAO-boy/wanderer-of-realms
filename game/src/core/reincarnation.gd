class_name Reincarnation
extends RefCounted

## 随机转生开局与死亡结算（M3.2、接口 I-23 ~ I-25）。
##
## 验收标准（《技术设计文档》8.4 节）：随机产出宿主，宿主带有非空的既有债务
## 或亲属或待办中的至少一项。
##
## 文档在这条里程碑上留了三个洞，实现时补齐，均已记入技术设计文档 9.5 节：
##   1. 「债务」与「待办」在 3.2 节的 SIM_NPC 表里连字段都没有。这里改从宿主的
##      实际数据推导：亲属来自 family_id 与关系网，债务按概率与区间抽样，
##      待办从宿主的亲属、仇敌与债务生成——不新建一套内容表，也不去读 M4 的
##      委托系统（那会破坏 M3.2「只依赖 M2.3 与 M3.1」的边界）。
##   2. sleepMonths 是悬空引用：《世界模拟量化规则》7 节把它交给「数值框架
##      第 11 章」，而那一章没有这个公式。这里按原文「由灵魂属性与随机决定」
##      补出公式，系数落在 balance.reincarnation。
##   3. 「幸运越高，随机到优质躯壳的概率越大」（《数值框架》3.2 节）没有量化。
##      这里把「优质」定义为剩余寿命比例，幸运按该比例加权。
##
## 宿主选出来后**不移除**出模拟 NPC 池。移掉会让整个关系网出现指向已删 NPC 的
## 悬空引用，而关系网正是「亲属」这一项遗留物的来源，代价大于收益。

const CAUSE_NATURAL: String = "natural"
const CAUSE_COMBAT: String = "combat"
const CAUSE_ACCIDENT: String = "accident"
## 自己放下了这一生（退隐）。它不是"死"，走的是同一条结算与转生流程——不允许
## 主动结束的话，玩家就只能靠快进几十年等一个寿终（D-59）。
const CAUSE_RETIRE: String = "retire"
const ALL_CAUSES: Array = [CAUSE_NATURAL, CAUSE_COMBAT, CAUSE_ACCIDENT, CAUSE_RETIRE]

## 死因在界面上怎么写。世代记录里每一世都带着它。
const CAUSE_LABELS: Dictionary = {
	CAUSE_NATURAL: "寿终",
	CAUSE_COMBAT: "战死",
	CAUSE_ACCIDENT: "意外",
	CAUSE_RETIRE: "退隐",
}

## 待办事项的类别，用于界面分类与后续映射到 M4 的委托
const MATTER_FAMILY: String = "family"
const MATTER_FEUD: String = "feud"
const MATTER_DEBT: String = "debt"

var _cfg: Dictionary = {}
var _creator: CharacterCreation = null
var _rng: DeterministicRNG = null


func _init(
	cfg: Dictionary = {},
	creator: CharacterCreation = null,
	rng: DeterministicRNG = null
) -> void:
	_cfg = cfg
	_creator = creator
	_rng = rng


# --- 保留率与继承（《数值框架》11 节）---

## 记忆保留率 = 20% + SOU×0.4%，上限 60%。
func compute_retention(sou_value: int) -> float:
	var raw: float = float(_cfg.get("baseRetention", 0.2)) \
		+ float(sou_value) * float(_cfg.get("retentionPerSoul", 0.004))
	return clampf(raw, 0.0, float(_cfg.get("retentionCap", 0.6)))


## 保留率的千分位整数形式。存档里 lastRetention 是浮点，但参与运算一律走
## 整数，免得同一份存档在不同平台上算出不同的继承熟练度。
func retention_milli(sou_value: int) -> int:
	return int(round(compute_retention(sou_value) * 1000.0))


## 技能继承：前世每项熟练度 × 保留率。
func inherited_skills(skills: Dictionary, sou_value: int) -> Dictionary:
	var milli: int = retention_milli(sou_value)
	var out: Dictionary = {}
	for skill_id in skills:
		var level: int = int(skills[skill_id])
		@warning_ignore("integer_division")
		var carried: int = level * milli / 1000
		if carried > 0:
			out[str(skill_id)] = carried
	return out


## 属性继承：前世七维 × 保留率 × 0.3，作为下一世的基础属性加成。
func inherited_attribute_bonus(attributes: Dictionary, sou_value: int) -> Dictionary:
	var milli: int = retention_milli(sou_value)
	var factor_milli: int = int(round(float(_cfg.get("attributeInheritFactor", 0.3)) * 1000.0))
	var out: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		@warning_ignore("integer_division")
		var bonus: int = int(attributes.get(attr, 0)) * milli * factor_milli / 1000000
		if bonus > 0:
			out[attr] = bonus
	return out


# --- 沉眠时长 ---

## 沉眠月数 = 沉眠年数 × 12。沉眠年数 = clamp(base + SOU×perSoul + 抖动, min, max)，
## 抖动取三次均匀抽样的平均（三角分布近似正态），与 NPC 年龄的取法一致，
## 避免引入浮点正态。
func sleep_months(sou_value: int) -> int:
	var base: float = float(_cfg.get("sleepMonthsBaseYears", 5))
	var per_soul: float = float(_cfg.get("sleepMonthsPerSoul", 0.1))
	var jitter: int = maxi(0, int(_cfg.get("sleepMonthsJitterYears", 3)))
	var spread: int = 0
	if jitter > 0 and _rng != null:
		@warning_ignore("integer_division")
		spread = (_rng.range_int(-jitter, jitter)
			+ _rng.range_int(-jitter, jitter)
			+ _rng.range_int(-jitter, jitter)) / 3
	var years: int = roundi(base + float(sou_value) * per_soul) + spread
	years = clampi(
		years,
		int(_cfg.get("sleepMonthsMinYears", 1)),
		int(_cfg.get("sleepMonthsMaxYears", 20))
	)
	return years * 12


# --- 宿主选取 ---

## 候选宿主：成年、未到暮年、非具名。返回按 npcId 排序，保证同一种子结果一致。
##
## 排除具名 NPC 的理由：他们是《世界观与背景设定》第七章名录里的角色，
## 被玩家占据会与设定直接冲突。
func host_candidates(world: WorldState, host_spec: Dictionary = {}) -> Array:
	var min_age: int = int(host_spec.get("minAge", _cfg.get("hostMinAge", 16)))
	var margin: int = int(host_spec.get("maxAgeMargin", _cfg.get("hostMaxAgeMargin", 15)))
	var out: Array = []
	for npc_id in world.npcs:
		var npc: SimNpc = world.npcs[npc_id]
		if npc.is_named:
			continue
		if npc.age < min_age:
			continue
		if npc.is_elder(margin):
			continue
		out.append(npc)
	out.sort_custom(func(a: SimNpc, b: SimNpc) -> bool:
		return a.npc_id < b.npc_id)
	return out


## 单个躯壳的抽取权重（千分位）。幸运 +100 且质量满分 → 1500（1.5 倍），
## 幸运 −100 → 500（0.5 倍）。抽成独立函数，是为了让"幸运越高，优质躯壳
## 概率越大"这条《数值框架》3.2 节的要求可以被直接断言，而不必靠抽样统计
## ——抽样统计在几百次的量级上分不出这条公式带来的偏移。
func host_weight(luck: int, quality_milli: int) -> int:
	var factor: int = int(_cfg.get("hostLuckWeightFactor", 5))
	@warning_ignore("integer_division")
	var weight: int = 1000 + luck * factor * quality_milli / 1000
	return maxi(1, weight)


## 按「躯壳质量」加权抽一个宿主。质量 = 剩余寿命比例；幸运按该比例加权，
## 高幸运更容易抽到年轻的身体（《数值框架》3.2 节：幸运越高，优质躯壳概率越大）。
func pick_host(world: WorldState, luck: int, host_spec: Dictionary = {}) -> SimNpc:
	var candidates: Array = host_candidates(world, host_spec)
	if candidates.is_empty():
		return null
	var cumulative: Array = []
	var total: int = 0
	for npc in candidates:
		var npc_ref: SimNpc = npc
		var quality: int = 1000
		if npc_ref.lifespan > 0:
			@warning_ignore("integer_division")
			quality = maxi(0, npc_ref.lifespan - npc_ref.age) * 1000 / npc_ref.lifespan
		total += host_weight(luck, quality)
		cumulative.append(total)
	var roll: int = (_rng.next_int(total) if _rng != null else 0)
	for i in range(cumulative.size()):
		if roll < int(cumulative[i]):
			return candidates[i]
	return candidates[candidates.size() - 1]


## 宿主抽取所用的随机源。界面可能只想预览候选而不消耗随机数，因此单独暴露。
func has_rng() -> bool:
	return _rng != null


# --- 遗留物 ---

## 从宿主的实际数据推导三类遗留：亲属、债务、待办。
## 至少会产出亲属一项——生成器给每个 NPC 都分配了 family_id，
## 而同家庭的 NPC 之间必然已建立亲属关系（《世界模拟量化规则》12.3 节）。
func build_legacy(world: WorldState, host: SimNpc) -> Dictionary:
	# 关系是双向存的，"both" 会把同一条关系返回两次（出向一次、入向一次），
	# 所以先按对端 ID 去重，再排序——不然亲属列表里会出现两份同一个人。
	var kin_map: Dictionary = {}
	var enemy_map: Dictionary = {}
	for record in world.get_relations(host.npc_id, "both"):
		var relation: Dictionary = record
		var relation_type: String = str(relation.get("type", ""))
		var other_id: String = _other_id(relation, host.npc_id)
		if other_id.is_empty():
			continue
		if relation_type == NpcGenerator.RELATION_KIN:
			kin_map[other_id] = int(relation.get("value", 0))
		elif relation_type == NpcGenerator.RELATION_ENEMY:
			enemy_map[other_id] = int(relation.get("value", 0))

	var kin: Array = _sorted_pairs(kin_map)
	var enemies: Array = _sorted_pairs(enemy_map)

	var debt: int = _draw_debt()

	var pending: Array = []
	if not kin.is_empty():
		pending.append(_matter(MATTER_FAMILY, kin[0]["npcId"],
			"%s 还留在%s，你若撒手，他无人照看" % [
				_npc_name(world, str(kin[0]["npcId"])), _city_label(world, host.city_id)
			]))
	if not enemies.is_empty():
		pending.append(_matter(MATTER_FEUD, enemies[0]["npcId"],
			"你和%s的旧账还没了结" % _npc_name(world, str(enemies[0]["npcId"]))))
	if debt > 0:
		pending.append(_matter(MATTER_DEBT, "", "你欠着一笔 %d 铜的债，债主迟早会来" % debt))

	return {
		"hostNpcId": host.npc_id,
		"hostName": host.display_name(),
		"hostCityId": host.city_id,
		"hostRace": host.race_id,
		"hostAge": host.age,
		"hostGender": host.gender,
		"kin": kin,
		"enemies": enemies,
		"debtCopper": debt,
		"pending": pending,
	}


## 遗留物是否非空。M3.2 的验收就看这一条。
static func legacy_is_empty(legacy: Dictionary) -> bool:
	return legacy.get("kin", []).is_empty() \
		and int(legacy.get("debtCopper", 0)) <= 0 \
		and legacy.get("pending", []).is_empty()


## 三类遗留里各有多少项，供界面与测试直接断言。
static func legacy_summary(legacy: Dictionary) -> Dictionary:
	return {
		"kin": legacy.get("kin", []).size(),
		"debt": int(legacy.get("debtCopper", 0)),
		"pending": legacy.get("pending", []).size(),
	}


func _draw_debt() -> int:
	var chance_permille: int = int(_cfg.get("hostDebtChancePerMille", 400))
	if _rng == null:
		return 0
	if _rng.next_int(1000) >= chance_permille:
		return 0
	return _rng.range_int(
		int(_cfg.get("hostDebtMinCopper", 300)),
		int(_cfg.get("hostDebtMaxCopper", 3000))
	)


func _matter(kind: String, npc_id: String, text: String) -> Dictionary:
	return {"kind": kind, "npcId": npc_id, "text": text}


## 从一条关系记录里取出「对端」的 NPC ID。关系是双向存的，两个方向都要能取对。
static func _other_id(relation: Dictionary, self_id: String) -> String:
	var to_id: String = str(relation.get("toNpcId", ""))
	if not to_id.is_empty() and to_id != self_id:
		return to_id
	var from_id: String = str(relation.get("fromNpcId", ""))
	if not from_id.is_empty() and from_id != self_id:
		return from_id
	return ""


## 把 {npcId: value} 转成按 npcId 排序的数组，保证同一种子下遗留物顺序稳定。
static func _sorted_pairs(source: Dictionary) -> Array:
	var ids: Array = source.keys()
	ids.sort()
	var out: Array = []
	for npc_id in ids:
		out.append({"npcId": str(npc_id), "value": int(source[npc_id])})
	return out


func _npc_name(world: WorldState, npc_id: String) -> String:
	var npc: SimNpc = world.get_npc(npc_id)
	return "某人" if npc == null else npc.display_name()


func _city_label(world: WorldState, city_id: String) -> String:
	var city: City = world.get_city(city_id)
	return city_id if city == null else city.display_name


# --- 转生 ---

## 产出新化身的规格。契约（10.4 节）要求返回 sleepMonths 而不是自己执行快进，
## 因为快进会改动世界状态，属于 WorldSim 的职责。
##
## host_spec 可指定 race/city/npcId 以缩小抽取范围；缺省为随机转生。
func rebirth(
	world: WorldState,
	soul: SoulRecord,
	luck: int = 0,
	host_spec: Dictionary = {}
) -> Dictionary:
	var host: SimNpc = null
	var forced_id: String = str(host_spec.get("npcId", ""))
	if not forced_id.is_empty():
		host = world.get_npc(forced_id)
	if host == null:
		host = pick_host(world, luck, host_spec)
	if host == null:
		return {"ok": false, "error": "PRECONDITION_FAILED", "reason": "没有可用的宿主"}

	var legacy: Dictionary = build_legacy(world, host)
	var sou_value: int = _soul_value(soul)
	var spec: Dictionary = {
		"race": host.race_id,
		"gender": host.gender,
		"displayName": host.display_name(),
		"backgroundId": "",
		"startAge": host.age,
		"startCityId": host.city_id,
		"talents": [],
		"flaws": [],
		"hostAvatarId": host.npc_id,
		"legacy": legacy,
	}
	# 随机转生是「放弃塑造」，因此没有创建期分配点，但吃前世的属性继承加成
	spec[CharacterCreation.ATTR_POINTS_KEY] = CharacterCreation.zero_allocations()
	spec["attributeBonuses"] = inherited_attribute_bonus(_last_life_attributes(soul), sou_value)
	return {
		"ok": true,
		"avatarSpec": spec,
		"host": host,
		"legacy": legacy,
		"sleepMonths": sleep_months(sou_value),
		"inheritedSkills": inherited_skills(soul.inherited_skills, sou_value),
		"retention": compute_retention(sou_value),
	}


## 死亡结算（接口 I-23）：把这一世的成果折进灵魂记录，并留下一份生平存档。
## 返回 {soulId, retention, inheritedSkills, archiveId}。
##
## context 是本模块之外的、调用方才知道的两样东西（D-62）：
##   - deeds / age / lifespan：这一世的功绩成就与寿数（由 deeds_from 组装）
##   - 其余键原样进档案，将来加一项功绩不必再改这个签名
func settle_death(
	soul: SoulRecord,
	avatar: PlayerAvatar,
	cause: String,
	month: int,
	context: Dictionary = {}
) -> Dictionary:
	# 保留率用的是**将死这一世**的 SOU，不是上一世的——所以在这里直接读化身的属性，
	# 而不是走 _soul_value（它读的是最近一份生命存档，此刻还没写入）。
	var sou_value: int = clampi(avatar.get_attribute(PlayerAvatar.ATTR_SOUL), 0, 100)
	var retention: float = compute_retention(sou_value)
	soul.last_retention = retention
	soul.reincarnation_count += 1

	# 技能继承取「灵魂里已有的」与「这一世新练的」中较高者，避免转生一次掉一次
	var carried: Dictionary = inherited_skills(avatar.skills, sou_value)
	for skill_id in carried:
		var previous: int = int(soul.inherited_skills.get(skill_id, 0))
		soul.inherited_skills[skill_id] = maxi(previous, int(carried[skill_id]))
	var bonus: Dictionary = inherited_attribute_bonus(avatar.attributes, sou_value)
	for attr in bonus:
		var previous_bonus: int = int(soul.inherited_attr_bonus.get(attr, 0))
		soul.inherited_attr_bonus[attr] = maxi(previous_bonus, int(bonus[attr]))

	# 善恶与幸运按化身侧的本世视图累计进跨世痕迹
	soul.karma_carry = clampi(soul.karma_carry + avatar.karma, -100, 100)
	soul.luck_carry = clampi(soul.luck_carry + avatar.luck, -100, 100)
	soul.dragonization_carry = avatar.dragonization

	var archive_id: String = "%s-life-%03d" % [soul.soul_id, soul.life_archives.size() + 1]
	soul.life_archives.append({
		"archiveId": archive_id,
		"soulId": soul.soul_id,
		"avatarSnapshot": avatar.to_dict(),
		"endedMonth": month,
		"deathCause": cause,
		# 功绩成就（世代记录按它列"这一生做过什么"）。缺 context 时写空表而不是不写：
		# 读的人永远能拿到这个键，不必到处判 has。
		"deeds": _dict_of(context.get("deeds", null)),
		"age": int(context.get("age", 0)),
		"lifespan": int(context.get("lifespan", 0)),
		"worldImpact": {
			"hostAvatarId": avatar.host_avatar_id,
			"backgroundId": avatar.background_id,
			"debtCopper": avatar.debt_copper,
		},
	})
	return {
		"soulId": soul.soul_id,
		"retention": retention,
		"inheritedSkills": carried,
		"archiveId": archive_id,
	}


# --- 功绩成就（世代记录的数据来源）---

## 把这一世的身家、经历、名声、对世界做过的事收成一份功绩表。
##
## 分两层：化身侧的从这里取（它只认 PlayersAvatar），世界侧的由调用方用 world_deeds
## 算好放进 extra["world"]——本类不引用 WorldState 的集合，依赖方向保持单向。
func deeds_from(avatar: PlayerAvatar, extra: Dictionary = {}) -> Dictionary:
	if avatar == null:
		return _dict_of(extra.get("world", null))
	return {
		"age": int(extra.get("age", 0)),
		"lifespan": int(extra.get("lifespan", 0)),
		"monthsLived": int(extra.get("monthsLived", 0)),
		"money": avatar.money,
		"debtCopper": avatar.debt_copper,
		"itemCount": avatar.inventory.size(),
		"equippedCount": avatar.equipment.size(),
		"karma": avatar.karma,
		"luck": avatar.luck,
		"attributes": avatar.attributes.duplicate(),
		"topSkills": _top_skills(avatar.skills),
		"reputation": _reputation_rows(avatar.city_reputation),
		"counters": _counters(avatar),
		"visitedCities": avatar.visited_cities.duplicate(),
		"relations": _relations(avatar),
		"world": _dict_of(extra.get("world", null)),
	}


## 世界侧的那一份：这一世开过的航线、留下的标记、走过几座城。
static func world_deeds(world: WorldState) -> Dictionary:
	if world == null:
		return {"routesOwned": 0, "routesTotal": 0, "flags": 0, "cities": 0}
	var owned: int = 0
	for route in world.trade_routes:
		if route is TradeRoute and route.owner_id == TradeRoute.OWNER_PLAYER:
			owned += 1
	return {
		"routesOwned": owned,
		"routesTotal": world.trade_routes.size(),
		"flags": world.world_flags.size(),
		"cities": world.get_city_count(),
	}


## 这一世结束：化身带着的东西一样都不留（D-61）——背包、钱、声誉、手上接的委托。
##
## 世界侧的账**不动**：延迟后果、进行中的事件、玩家开过的航线都还留在世界上，
## 那些是"世界记得的事"，不是"这个人带着的东西"。
##
## 放在这里而不是主场景：主场景在无头测试中不存在，而这一条是有后果的规则
## （未办完的委托到底作不作废），必须能被钉住。
func clear_avatar_life(world: WorldState) -> Dictionary:
	if world == null:
		return {"hadAvatar": false, "avatarId": "", "abandonedQuests": 0}
	var avatar: PlayerAvatar = world.avatar
	var abandoned: int = world.quests.size()
	world.quests.clear()
	world.avatar = null
	return {
		"hadAvatar": avatar != null,
		"avatarId": "" if avatar == null else avatar.avatar_id,
		"abandonedQuests": abandoned,
	}


## 熟练度最高的几项技能。同分按 skillId 升序——排序要确定，不然同一份存档
## 每次打开看到的行序都不一样。
func _top_skills(skills: Dictionary) -> Array:
	var rows: Array = []
	for skill_id in skills:
		var level: int = int(skills[skill_id])
		if level > 0:
			rows.append({"skillId": str(skill_id), "level": level})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["level"]) != int(b["level"]):
			return int(a["level"]) > int(b["level"])
		return str(a["skillId"]) < str(b["skillId"])
	)
	return rows.slice(0, maxi(1, int(_cfg.get("recordSkillCount", 5))))


## 名声：只列非零的城，按绝对值从大到小（"最有名的/最臭名昭著的那几座城"
## 才是这一栏想说的话），同值按 cityId 升序。
func _reputation_rows(city_reputation: Dictionary) -> Array:
	var rows: Array = []
	for city_id in city_reputation:
		var value: int = int(city_reputation[city_id])
		if value != 0:
			rows.append({"cityId": str(city_id), "value": value})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absi(int(a["value"])) != absi(int(b["value"])):
			return absi(int(a["value"])) > absi(int(b["value"]))
		return str(a["cityId"]) < str(b["cityId"])
	)
	return rows.slice(0, maxi(1, int(_cfg.get("recordReputationCount", 4))))


## 经历计数。零也照记：世代记录里写"打赢的仗 0"比整行消失更容易读。
static func _counters(avatar: PlayerAvatar) -> Dictionary:
	var out: Dictionary = {}
	for key in PlayerAvatar.DEED_KEYS:
		out[key] = avatar.deed(str(key))
	return out


## 这一世接下的关系（转生来的那一世才有宿主与他的亲属、仇敌）。
static func _relations(avatar: PlayerAvatar) -> Dictionary:
	var legacy: Dictionary = avatar.legacy
	var kin: Array = _array_of(legacy.get("kin", null))
	var enemies: Array = _array_of(legacy.get("enemies", null))
	return {
		"hostName": str(legacy.get("hostName", "")),
		"kin": kin.size(),
		"enemies": enemies.size(),
	}


static func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []


## 上一世的 SOU。《数值框架》11 节的保留率公式读的是「灵魂属性」，转生时
## 指的是刚结束那一世的属性值——所以取最近一份生命存档的化身快照。
## 没有存档（尚未死过一次）时退回灵魂上已有的继承加成，最后再退回 0。
func _soul_value(soul: SoulRecord) -> int:
	if soul == null:
		return 0
	var attributes: Dictionary = _last_life_attributes(soul)
	if not attributes.is_empty():
		return clampi(int(attributes.get(PlayerAvatar.ATTR_SOUL, 0)), 0, 100)
	return clampi(int(soul.inherited_attr_bonus.get(PlayerAvatar.ATTR_SOUL, 0)), 0, 100)


## 上一世的七维属性。来源是最近一份生命存档里的化身快照。
func _last_life_attributes(soul: SoulRecord) -> Dictionary:
	if soul == null or soul.life_archives.is_empty():
		return {}
	var last: Dictionary = soul.life_archives[soul.life_archives.size() - 1]
	var snapshot: Dictionary = last.get("avatarSnapshot", {})
	return snapshot.get("attributes", {})
