class_name NpcGenerator
extends RefCounted

## 模拟 NPC 的生成器（《世界模拟量化规则》11.3、11.4、12 章）。
##
## 生成分三件事：定数量、造个体与家庭、连关系网。三件都只用传入的确定性 RNG，
## 不碰引擎的随机函数，也不依赖哈希容器的遍历顺序——候选集在抽样前先按 ID
## 排序，否则同一份存档在两台机器上会长出不同的居民。
##
## 两处与上游规则有意的偏离，都记录在此：
##
## 1. 关系网密度。12.2 节把好友写成「随机抽取 NPC，以 10% 概率建立」，若按
##    全量配对理解，200 人的城市会产生近 2000 对好友，仅关系记录就超出整个
##    存档的体积估算（技术设计文档 4.4 节）。此处改成「每个 NPC 抽样若干候选
##    对象，各自按概率判定」：概率语义不变，密度由抽样规模决定。
## 2. 年龄分布。11.4 节要求正态分布，而正态要用到 log/cos，跨平台的数学库
##    实现差异会破坏确定性（设计文档 5.1 节）。改用三次均匀抽样取平均，形状
##    接近钟形，且全程整数运算。

const RELATION_KIN: String = "kin"
const RELATION_COLLEAGUE: String = "colleague"
const RELATION_FRIEND: String = "friend"
const RELATION_ENEMY: String = "enemy"

const ADULT_AGE: int = 16  ## 5.2 节：16 岁起成年，孩童不参与生产

var _cfg: Dictionary = {}
var _professions: Array = []
var _specialty: Dictionary = {}
var _specialty_mult: int = 4000
var _positions: Array = []
var _races: Array = []
var _race_index: Dictionary = {}
var _tendency: Dictionary = {}
var _tendency_mult: int = 6000


func _init(profession_cfg: Dictionary, name_cfg: Dictionary, npc_cfg: Dictionary) -> void:
	_cfg = npc_cfg
	_specialty_mult = _permille(profession_cfg, "specialtyWeightMultiplier", 4.0)
	_specialty = profession_cfg.get("citySpecialty", {})

	for entry in profession_cfg.get("professions", []):
		_professions.append({
			"id": str(entry.get("professionId", "")),
			"category": str(entry.get("category", "production")),
			"weight": maxi(1, int(round(float(entry.get("baseWeight", 1.0)) * 1000.0))),
		})
	_professions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"]))

	for position in profession_cfg.get("positionTemplates", []):
		_positions.append({
			"id": str(position.get("positionId", "")),
			"display": str(position.get("displayName", position.get("positionId", ""))),
			"from": str(position.get("fromProfession", "")),
			"count": maxi(1, int(position.get("countPerCity", 1))),
		})
	_positions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"]))

	_tendency_mult = _permille(name_cfg, "tendencyWeightMultiplier", 6.0)
	_tendency = name_cfg.get("cityTendency", {})
	for entry in name_cfg.get("races", []):
		var race: Dictionary = {
			"id": str(entry.get("raceId", "")),
			"lifespan": maxi(1, int(entry.get("lifespan", 80))),
			"weight": maxi(1, int(round(float(entry.get("populationWeight", 0.5)) * 1000.0))),
			"given": entry.get("givenNames", []),
			"family": entry.get("familyNames", []),
		}
		_races.append(race)
		_race_index[race["id"]] = race
	_races.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"]))


## 模拟 NPC 的目标数量：min(人口 × 3, 200)（11.1 节）。
func target_count(population: int) -> int:
	var per_point: int = int(_cfg.get("simulatedPerPopulationPoint", 3))
	var cap: int = int(_cfg.get("simulatedCap", 200))
	return mini(maxi(0, population) * per_point, cap)


func lifespan_of(race_id: String) -> int:
	var race: Dictionary = _race_index.get(race_id, {})
	return int(race.get("lifespan", 80))


func position_display_name(position_id: String) -> String:
	for position in _positions:
		if str(position["id"]) == position_id:
			return str(position["display"])
	return position_id


## 城市的职业权重累积表。权重按 11.3 节随城市状态调制，城市特色职业额外加权。
func profession_weight_table(city: City) -> Array:
	var table: Array = []
	var total: int = 0
	for p in _professions:
		total += weight_of(p, city)
		table.append(total)
	return table


## 按类别汇总的权重。用于校验"11.3 节的调制真的生效了"。
func category_weight_totals(city: City) -> Dictionary:
	var out: Dictionary = {}
	for p in _professions:
		var category: String = str(p["category"])
		out[category] = int(out.get(category, 0)) + weight_of(p, city)
	return out


func weight_of(profession: Dictionary, city: City) -> int:
	@warning_ignore("integer_division")
	var w: int = _category_weight(str(profession["category"]), city) \
		* int(profession["weight"]) / 1000
	var specialty: String = str(_specialty.get(city.city_id, ""))
	if not specialty.is_empty() and str(profession["id"]) == specialty:
		@warning_ignore("integer_division")
		w = w * _specialty_mult / 1000
	return maxi(0, w)


## 生成一批 NPC。first_seq 是本世界的 NPC 序号游标，返回下一序号，
## 保证 ID 全局唯一且与生成顺序绑定（生成顺序本身是确定的）。
func spawn_batch(city: City, count: int, first_seq: int, rng: DeterministicRNG) -> Dictionary:
	var batch: Array = []
	if count <= 0 or _races.is_empty():
		return {"npcs": batch, "nextSeq": first_seq}

	var seq: int = first_seq
	var remaining: int = count
	var family_min: int = maxi(2, int(_cfg.get("familyMinSize", 2)))
	var family_max: int = maxi(family_min, int(_cfg.get("familyMaxSize", 5)))
	var table: Array = profession_weight_table(city)

	while remaining > 0:
		var size: int = remaining if remaining <= family_max else rng.range_int(family_min, family_max)
		if remaining - size == 1:
			# 抽中的规模会把一位剩到最后单独成家，改为调小本组、让那一位并进来
			size = clampi(remaining - family_min, family_min, family_max)
		size = maxi(1, mini(size, remaining))
		remaining -= size
		var race: Dictionary = _pick_race(city, rng)
		var surname: String = _pick_from(race["family"], rng)
		var family_id: String = "fam-%s-%06d" % [city.city_id, seq]
		for _i in range(size):
			var npc := SimNpc.new()
			npc.npc_id = "npc-%08d" % seq
			seq += 1
			npc.city_id = city.city_id
			npc.race_id = str(race["id"])
			npc.lifespan = int(race["lifespan"])
			npc.gender = SimNpc.GENDER_MALE if rng.chance(0.5) else SimNpc.GENDER_FEMALE
			npc.given_name = _pick_from(race["given"], rng)
			npc.family_name = surname
			npc.age = _draw_age(rng, npc.lifespan)
			npc.profession_id = _pick_profession(table, rng) if npc.age >= ADULT_AGE else ""
			npc.family_id = family_id
			batch.append(npc)
	return {"npcs": batch, "nextSeq": seq}


## 为一批新 NPC 建立关系网。peers 是所在城市现有的全部 NPC（含本批），
## 用于抽样同事与好友。返回双向关系记录数组。
func link_relations(
	npcs: Array, peers: Array, city: City, rng: DeterministicRNG
) -> Array:
	var relations: Array = []

	# 亲属：同家庭必建（12.3 节，概率 100%）
	var by_family: Dictionary = {}
	for npc in npcs:
		var key: String = str(npc.family_id)
		if not by_family.has(key):
			by_family[key] = []
		by_family[key].append(npc)
	for family_id in _sorted_keys(by_family):
		var members: Array = by_family[family_id]
		members.sort_custom(func(a: SimNpc, b: SimNpc) -> bool:
			return str(a.npc_id) < str(b.npc_id))
		for i in range(members.size()):
			for j in range(i + 1, members.size()):
				_add_pair(relations, members[i], members[j], RELATION_KIN, rng,
					int(_cfg.get("kinRelationMin", 40)),
					int(_cfg.get("kinRelationMax", 80)))

	var limit: int = maxi(1, int(_cfg.get("relationSampleLimit", 4)))
	var colleague_p: float = float(_cfg.get("colleagueProbability", 0.3))
	var friend_p: float = float(_cfg.get("friendProbability", 0.1))
	var enemy_p: float = enemy_chance(city)

	var by_profession: Dictionary = {}
	var sorted_peers: Array = peers.duplicate()
	sorted_peers.sort_custom(func(a: SimNpc, b: SimNpc) -> bool:
		return str(a.npc_id) < str(b.npc_id))
	for peer in sorted_peers:
		var pid: String = str(peer.profession_id)
		if pid.is_empty():
			continue
		if not by_profession.has(pid):
			by_profession[pid] = []
		by_profession[pid].append(peer)

	for npc in npcs:
		var pid: String = str(npc.profession_id)
		if not pid.is_empty():
			var pool: Array = by_profession.get(pid, [])
			for peer in _sample(pool, limit, rng, npc):
				if rng.chance(colleague_p):
					_add_pair(relations, npc, peer, RELATION_COLLEAGUE, rng,
						int(_cfg.get("colleagueRelationMin", 10)),
						int(_cfg.get("colleagueRelationMax", 30)))
		for peer in _sample(sorted_peers, limit, rng, npc):
			if rng.chance(friend_p):
				_add_pair(relations, npc, peer, RELATION_FRIEND, rng,
					int(_cfg.get("friendRelationMin", 20)),
					int(_cfg.get("friendRelationMax", 50)))
		for peer in _sample(sorted_peers, limit, rng, npc):
			if rng.chance(enemy_p):
				_add_pair(relations, npc, peer, RELATION_ENEMY, rng,
					-int(_cfg.get("enemyRelationMax", 60)),
					-int(_cfg.get("enemyRelationMin", 30)))
	return relations


## 仇敌概率 = (100 - 治安)/100 × 15%（12.3 节）。治安越差，仇敌越多。
func enemy_chance(city: City) -> float:
	var factor: float = float(_cfg.get("enemySecurityFactor", 0.15))
	return float(100 - city.security) / 100.0 * factor


## 给空缺职位指派持有者（12.2 节第 5 步的简化：取该职业中年龄最长者）。
## 返回可展示的事件说明。
func assign_positions(city_npcs: Array) -> Array:
	var events: Array = []
	for position in _positions:
		var held: int = 0
		for npc in city_npcs:
			if str(npc.position_id) == str(position["id"]):
				held += 1
		for _slot in range(int(position["count"]) - held):
			var candidate: SimNpc = _pick_position_candidate(city_npcs, str(position["from"]))
			if candidate == null:
				break
			candidate.position_id = str(position["id"])
			candidate.is_named = true
			events.append("%s 的%s由 %s 出任" % [
				candidate.city_id, str(position["display"]), candidate.display_name()
			])
	return events


## 已无人的职位需要有人接替（5.2 节「继承」）。
func vacant_positions(city_npcs: Array) -> Array:
	var out: Array = []
	for position in _positions:
		var held: int = 0
		for npc in city_npcs:
			if str(npc.position_id) == str(position["id"]):
				held += 1
		if held < int(position["count"]):
			out.append(str(position["id"]))
	return out


func _pick_position_candidate(city_npcs: Array, profession_id: String) -> SimNpc:
	var best: SimNpc = null
	for npc in city_npcs:
		if str(npc.profession_id) != profession_id:
			continue
		if npc.is_elder(int(_cfg.get("elderAgeMargin", 15))):
			continue
		if best == null or npc.age > best.age or (npc.age == best.age and npc.npc_id < best.npc_id):
			best = npc
	return best


func _pick_race(city: City, rng: DeterministicRNG) -> Dictionary:
	var tendency: String = str(_tendency.get(city.city_id, ""))
	var weights: Array = []
	var total: int = 0
	for race in _races:
		var w: int = int(race["weight"])
		if not tendency.is_empty() and str(race["id"]) == tendency:
			@warning_ignore("integer_division")
			w = w * _tendency_mult / 1000
		total += maxi(0, w)
		weights.append(total)
	if total <= 0:
		return _races[0]
	var roll: int = rng.next_int(total)
	for i in range(weights.size()):
		if roll < int(weights[i]):
			return _races[i]
	return _races[_races.size() - 1]


func _pick_profession(table: Array, rng: DeterministicRNG) -> String:
	if table.is_empty():
		return ""
	var total: int = int(table[table.size() - 1])
	if total <= 0:
		return str(_professions[0]["id"])
	var roll: int = rng.next_int(total)
	for i in range(table.size()):
		if roll < int(table[i]):
			return str(_professions[i]["id"])
	return str(_professions[_professions.size() - 1]["id"])


func _pick_from(pool: Variant, rng: DeterministicRNG) -> String:
	var list: Array = pool
	if list.is_empty():
		return "无名"
	return str(list[rng.next_int(list.size())])


func _draw_age(rng: DeterministicRNG, lifespan: int) -> int:
	var ratio: float = float(_cfg.get("ageMeanLifespanRatio", 0.4))
	var half: int = maxi(1, int(_cfg.get("ageJitterHalfRange", 12)))
	var mean: int = int(round(float(lifespan) * ratio))
	@warning_ignore("integer_division")
	var jitter: int = (
		rng.range_int(-half, half) + rng.range_int(-half, half) + rng.range_int(-half, half)
	) / 3
	return clampi(mean + jitter, 1, maxi(1, lifespan - 1))


## 从候选集中抽样若干对象，排除自己并去重，结果按 ID 排序以保证判定顺序稳定。
func _sample(pool: Array, limit: int, rng: DeterministicRNG, exclude: SimNpc) -> Array:
	var out: Array = []
	if pool.is_empty():
		return out
	var size: int = pool.size()
	var tries: int = mini(limit * 2, size)
	for _i in range(tries):
		var pick: SimNpc = pool[rng.next_int(size)]
		if pick.npc_id == exclude.npc_id:
			continue
		var duplicate: bool = false
		for existing in out:
			if existing.npc_id == pick.npc_id:
				duplicate = true
				break
		if not duplicate:
			out.append(pick)
			if out.size() >= limit:
				break
	out.sort_custom(func(a: SimNpc, b: SimNpc) -> bool:
		return str(a.npc_id) < str(b.npc_id))
	return out


func _add_pair(
	relations: Array, a: SimNpc, b: SimNpc, type: String, rng: DeterministicRNG,
	value_min: int, value_max: int
) -> void:
	if a.npc_id == b.npc_id:
		return
	var value: int = rng.range_int(value_min, value_max)
	relations.append({"fromNpcId": a.npc_id, "toNpcId": b.npc_id, "type": type, "value": value})
	relations.append({"fromNpcId": b.npc_id, "toNpcId": a.npc_id, "type": type, "value": value})


## 11.3 节的职业权重调制。加工类上游未给调制规则，取中性权重。
func _category_weight(category: String, city: City) -> int:
	var dim: int = 50
	match category:
		"production":
			dim = 100 - city.development
		"knowledge":
			dim = city.culture
		"military":
			dim = 100 - city.security
		"gray":
			dim = 100 - city.security
		"commerce":
			dim = city.wealth
	return dim * 10


func _sorted_keys(source: Dictionary) -> Array:
	var keys: Array = source.keys()
	keys.sort()
	return keys


static func _permille(cfg: Dictionary, key: String, fallback: float) -> int:
	return int(round(float(cfg.get(key, fallback)) * 1000.0))
