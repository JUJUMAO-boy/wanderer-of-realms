class_name WorldState
extends RefCounted

## 存档根，也是"世界"本身。玩家不干预时它按规则自行演化，跨转生完整保留。
##
## 这里不持有时间：时间属于 ClockCore，存档时由 SaveIO 把两者合进同一个
## world.json。各系统各自持有自己的数据、文件负责组装，避免同一份状态存在
## 两个地方而出现不同步。
##
## 城市用 cityId 作键存字典以便 O(1) 查找，但对外一律按 cityId 排序遍历
## （get_city_ids）。结算是按下标顺序执行的，顺序不稳会破坏确定性——
## 哈希容器的遍历顺序在 Godot 里不保证稳定。
##
## NPC 是**双重记账**的：世界持有 npcId → SimNpc 的总表，城市持有该城的
## npcId 列表。这看着冗余，但两者服务于不同的访问模式——总表按 ID 直取，
## 城市列表要按月按城遍历（快进 1200 个月时，每月都要拿"这座城有哪些人"，
## 从总表过滤会是 8 × 1600 次比较/月）。两份列表**只允许经本类的方法修改**，
## 任何模块都不得直接动 city.npc_ids，否则两边会漂移。

const APPLIED_CHANGE_RETENTION_MONTHS: int = 12

## 六维历史保留的月数。界面上的趋势线只画这一段。
##
## 历史是**派生数据**，按 3.6 节的原则本不该落盘，这里破例是刻意的：趋势是
## 玩家感知"世界在变"的主要凭据，若只存在内存里，读档后所有曲线归零，玩家
## 就再也看不到自己造成的长期变化。8 城 × 6 维 × 60 月 = 2880 个整数，
## 序列化后约 15 KB，代价可以忽略。
const HISTORY_MONTHS: int = 60

var world_seed: int = 0
var rng: DeterministicRNG = null
var cities: Dictionary = {}       ## cityId -> City
var npcs: Dictionary = {}         ## npcId -> SimNpc
var npc_seq: int = 1              ## NPC ID 游标，随世界单调递增
var relations: Dictionary = {}    ## npcId -> Array[{toNpcId, type, value}]
var trade_routes: Array = []      ## TradeRoute[]
var world_flags: Dictionary = {}  ## 主线与全局事件标记
var avatar: PlayerAvatar = null
var city_history: Dictionary = {} ## cityId -> {dimension: Array[int]}，末尾为最近一月

## 玩家接下的委托（Quest[]）。**委托板不在其中**：板子是城市六维与世界标记的
## 纯函数（QuestBoard），落盘反而要额外维护"任务随城市状态出现或消失"的同步，
## 而按需推导天然就是对的。这里只放已经接下的，因为那才是玩家欠世界的账。
var quests: Array = []
## 待落账的延迟后果。分支里"数月后塌方"这类后果先记在这里，到期由月度结算
## 提升为 StateChange，走城市状态唯一的写入口（M4.3）。记录形如
## {dueMonth, cityId, dimension, delta, text, questId, seq}
var pending_consequences: Array = []

## 城市事件实例（CityEvent[]）。触发时新建、了结后不删——"这场事是怎么了结的"
## 决定了它还会不会再来（见 EventSystem._recently_resolved），删掉就丢了这个判据。
## 与委托板相反，事件模板不落盘：对白与分支后果现查 events.json（3.2 节）。
var events: Array = []

## 待落账的变更队列。applyStateChange 只入队，下一个整月结算时才生效
## （技术设计文档 10.4 节）——玩家交付委托后到月末之间，城市数字不应变化。
var pending_changes: Array = []
## 已落账变更的幂等表：changeId -> {sig, month}。保留 12 个月，
## 覆盖"读档重试同一批交付"的最长跨度。
var applied_changes: Dictionary = {}

## 玩家对各城各建筑的投资等级（D-69~D-72）。cityId -> {buildingId: level}。
## 玩家私有状态，必须落盘——像传奇航线一样不可由城市状态反推。城市自然等级是
## 派生值不落盘，这里只存玩家亲手投的那部分。
var building_investments: Dictionary = {}

## 世界大事件与历史纪年（M16）。跨城、跨代的条目数组，随世界落盘——纪年的价值
## 正在于"换了代还能翻开"，所以它是真实条目而非派生的趋势窗口。元素形如
## {id, kind, title, cityId, cityLabel, detail, attribution, month, year}，由
## Chronicle.record 追加、钳总量上限。chronicle_seq 是纪年 id 的单调游标。
var chronicle: Array = []
var chronicle_seq: int = 0


static func create(world_seed_value: int) -> WorldState:
	var w := WorldState.new()
	w.world_seed = world_seed_value & DeterministicRNG.MASK32
	w.rng = DeterministicRNG.new(w.world_seed)
	w.world_flags = {}
	return w


func add_city(city: City) -> void:
	cities[city.city_id] = city


func get_city(city_id: String) -> City:
	return cities.get(city_id, null)


## 按 cityId 排序的城市 ID。所有需要遍历城市的结算都应当用它，
## 保证同一份存档每次运行的结算顺序完全一致。
func get_city_ids() -> PackedStringArray:
	var ids: Array = cities.keys()
	ids.sort()
	return PackedStringArray(ids)


func get_city_count() -> int:
	return cities.size()


# --- NPC ---

func add_npc(npc: SimNpc) -> void:
	npcs[npc.npc_id] = npc
	var city: City = get_city(npc.city_id)
	if city != null:
		city.npc_ids.append(npc.npc_id)


func get_npc(npc_id: String) -> SimNpc:
	return npcs.get(npc_id, null)


func remove_npc(npc_id: String) -> void:
	var npc: SimNpc = npcs.get(npc_id, null)
	if npc == null:
		return
	var city: City = get_city(npc.city_id)
	if city != null:
		city.npc_ids.erase(npc_id)
	npcs.erase(npc_id)
	relations.erase(npc_id)


## 把 NPC 迁到另一座城，同时维护两边的索引。
func move_npc(npc_id: String, to_city_id: String) -> void:
	var npc: SimNpc = npcs.get(npc_id, null)
	if npc == null or npc.city_id == to_city_id:
		return
	var from_city: City = get_city(npc.city_id)
	if from_city != null:
		from_city.npc_ids.erase(npc_id)
	var to_city: City = get_city(to_city_id)
	if to_city == null:
		return
	npc.city_id = to_city_id
	to_city.npc_ids.append(npc_id)


## 某城的 NPC，按 npcId 排序。结算一律走这个顺序。
func get_city_npcs(city_id: String) -> Array:
	var city: City = get_city(city_id)
	var out: Array = []
	if city == null:
		return out
	var ids: Array = city.npc_ids.duplicate()
	ids.sort()
	for npc_id in ids:
		var npc: SimNpc = npcs.get(npc_id, null)
		if npc != null:
			out.append(npc)
	return out


func get_npc_count() -> int:
	return npcs.size()


## 批量移除 NPC，并一并清掉指向它们的**入向**关系。
##
## 单条移除做不到这件事：删掉 A 只清了 A 名下的记录，B 的关系里还留着"A"。
## 逐条清理要为每个人扫一遍整表，成本是 O(人数 × 关系数)。批量移除只扫一遍，
## 是快进能接受的开销——因此裁剪一律攒成一批再做。
func purge_npcs(npc_ids: Array) -> void:
	if npc_ids.is_empty():
		return
	var doomed: Dictionary = {}
	for npc_id in npc_ids:
		doomed[str(npc_id)] = true

	for npc_id in doomed:
		var npc: SimNpc = npcs.get(npc_id, null)
		if npc == null:
			continue
		var city: City = get_city(npc.city_id)
		if city != null:
			city.npc_ids.erase(npc_id)
		npcs.erase(npc_id)

	var keys: Array = relations.keys()
	for key in keys:
		if doomed.has(str(key)):
			relations.erase(key)
			continue
		var kept: Array = []
		for record in relations[key]:
			if not doomed.has(str(record["toNpcId"])):
				kept.append(record)
		if kept.is_empty():
			relations.erase(key)
		else:
			relations[key] = kept


# --- 关系 ---

func add_relations(records: Array) -> void:
	for record in records:
		var from_id: String = str(record.get("fromNpcId", ""))
		if from_id.is_empty():
			continue
		if not relations.has(from_id):
			relations[from_id] = []
		relations[from_id].append({
			"toNpcId": str(record.get("toNpcId", "")),
			"type": str(record.get("type", "")),
			"value": int(record.get("value", 0)),
		})


## 读取某 NPC 的关系。direction 取 out / in / both。
func get_relations(npc_id: String, direction: String = "both") -> Array:
	var out: Array = []
	if direction == "out" or direction == "both":
		for record in relations.get(npc_id, []):
			out.append({
				"fromNpcId": npc_id,
				"toNpcId": str(record["toNpcId"]),
				"type": str(record["type"]),
				"value": int(record["value"]),
			})
	if direction == "in" or direction == "both":
		var ids: Array = relations.keys()
		ids.sort()
		for from_id in ids:
			for record in relations[from_id]:
				if str(record["toNpcId"]) == npc_id:
					out.append({
						"fromNpcId": str(from_id),
						"toNpcId": npc_id,
						"type": str(record["type"]),
						"value": int(record["value"]),
					})
	return out


func get_relation_count() -> int:
	var total: int = 0
	for key in relations:
		total += relations[key].size()
	return total


# --- 贸易路线 ---

## 按 routeId 排序的路线。结算顺序必须稳定，否则查抄用的随机流会错位。
func get_routes_sorted() -> Array:
	var out: Array = trade_routes.duplicate()
	out.sort_custom(func(a: TradeRoute, b: TradeRoute) -> bool:
		return str(a.route_id) < str(b.route_id))
	return out


func find_route(city_x: String, city_y: String) -> TradeRoute:
	var route_id: String = TradeRoute.route_id_for(city_x, city_y)
	for route in trade_routes:
		if str(route.route_id) == route_id:
			return route
	return null


func get_routes_of_city(city_id: String, kind: String = "") -> Array:
	var out: Array = []
	for route in get_routes_sorted():
		if not route.involves(city_id):
			continue
		if not kind.is_empty() and str(route.kind) != kind:
			continue
		out.append(route)
	return out


func add_route(route: TradeRoute) -> void:
	trade_routes.append(route)


func remove_route(route_id: String) -> void:
	for i in range(trade_routes.size()):
		if str(trade_routes[i].route_id) == route_id:
			trade_routes.remove_at(i)
			return


# --- 委托 ---

## 已接的委托，按接受月份与 id 排序。界面与结算都按这个顺序走。
func get_quests() -> Array:
	var out: Array = quests.duplicate()
	out.sort_custom(func(a: Quest, b: Quest) -> bool:
		if a.accepted_month != b.accepted_month:
			return a.accepted_month < b.accepted_month
		return a.quest_id < b.quest_id
	)
	return out


func get_quests_of_city(city_id: String) -> Array:
	var out: Array = []
	for quest in get_quests():
		if quest.city_id == city_id:
			out.append(quest)
	return out


func find_quest(quest_id: String) -> Quest:
	for quest in quests:
		if quest.quest_id == quest_id:
			return quest
	return null


func add_quest(quest: Quest) -> void:
	quests.append(quest)


func remove_quest(quest_id: String) -> void:
	for i in range(quests.size()):
		if str(quests[i].quest_id) == quest_id:
			quests.remove_at(i)
			return


## 进行中的委托条数。上限由 balance 的 quests.maxAccepted 约束——
## 不做上限的话玩家可以把整座城的委托一次全接下来，然后慢慢挑着办。
func active_quest_count() -> int:
	var total: int = 0
	for quest in quests:
		if quest.is_active():
			total += 1
	return total


# --- 城市事件 ---

## 全部事件实例，按触发月份与 id 排序。界面与结算都按这个顺序走。
func get_events() -> Array:
	var out: Array = events.duplicate()
	out.sort_custom(func(a: CityEvent, b: CityEvent) -> bool:
		if a.triggered_month != b.triggered_month:
			return a.triggered_month < b.triggered_month
		return a.event_id < b.event_id
	)
	return out


func find_event(event_id: String) -> CityEvent:
	for event in events:
		if event.event_id == event_id:
			return event
	return null


func add_event(event: CityEvent) -> void:
	events.append(event)


## 进行中的事件条数。城里的告示与地图上的提示都按它判断"这里有活事"。
func active_event_count(city_id: String = "") -> int:
	var total: int = 0
	for event in events:
		if not event.is_active():
			continue
		if not city_id.is_empty() and event.city_id != city_id:
			continue
		total += 1
	return total


# --- 历史 ---

## 记一笔某城当月的六维。由世界模拟在每次月度结算后调用。
func record_history(city: City) -> void:
	var entry: Dictionary = city_history.get(city.city_id, {})
	for dimension in City.ALL_DIMENSIONS:
		var series: Array = entry.get(dimension, [])
		series.append(city.get_dimension(dimension))
		while series.size() > HISTORY_MONTHS:
			series.pop_front()
		entry[dimension] = series
	city_history[city.city_id] = entry


## 某城某维的历史序列，末尾为最近一月。没有记录时返回空数组。
func get_history(city_id: String, dimension: String) -> Array:
	var entry: Dictionary = city_history.get(city_id, {})
	return entry.get(dimension, [])


func get_history_length(city_id: String) -> int:
	var entry: Dictionary = city_history.get(city_id, {})
	if entry.is_empty():
		return 0
	return (entry.get(City.DIM_POPULATION, []) as Array).size()


# --- 序列化 ---

## 世界侧的可变状态。城市只写可变字段，配置字段在读档时由配置合并。
func to_dict() -> Dictionary:
	var city_list: Array = []
	for city_id in get_city_ids():
		city_list.append(cities[city_id].to_dict())

	var npc_list: Array = []
	var npc_ids: Array = npcs.keys()
	npc_ids.sort()
	for npc_id in npc_ids:
		npc_list.append(npcs[npc_id].to_dict())

	var route_list: Array = []
	for route in get_routes_sorted():
		route_list.append(route.to_dict())

	var change_list: Array = []
	for change in pending_changes:
		change_list.append(change.to_dict())

	var quest_list: Array = []
	for quest in get_quests():
		quest_list.append(quest.to_dict())

	var consequence_list: Array = []
	for record in pending_consequences:
		consequence_list.append({
			"dueMonth": int(record.get("dueMonth", 0)),
			"cityId": str(record.get("cityId", "")),
			"dimension": str(record.get("dimension", "")),
			"delta": int(record.get("delta", 0)),
			"text": str(record.get("text", "")),
			"questId": str(record.get("questId", "")),
			"seq": int(record.get("seq", 0)),
		})

	var event_list: Array = []
	for event in get_events():
		event_list.append(event.to_dict())

	var relation_out: Dictionary = {}
	var relation_keys: Array = relations.keys()
	relation_keys.sort()
	for key in relation_keys:
		relation_out[str(key)] = relations[key].duplicate(true)

	var history_out: Dictionary = {}
	var history_keys: Array = city_history.keys()
	history_keys.sort()
	for key in history_keys:
		var entry: Dictionary = city_history[key]
		var series_out: Dictionary = {}
		for dimension in City.ALL_DIMENSIONS:
			series_out[dimension] = (entry.get(dimension, []) as Array).duplicate()
		history_out[str(key)] = series_out

	var buildings_out: Dictionary = {}
	var build_keys: Array = building_investments.keys()
	build_keys.sort()
	for key in build_keys:
		buildings_out[str(key)] = building_investments[key].duplicate()

	var chronicle_out: Array = []
	for entry in chronicle:
		if entry is Dictionary:
			chronicle_out.append((entry as Dictionary).duplicate(true))

	return {
		"worldSeed": world_seed,
		"rngState": rng.get_state() if rng != null else 0,
		"cities": city_list,
		"npcs": npc_list,
		"npcSeq": npc_seq,
		"relations": relation_out,
		"tradeRoutes": route_list,
		"worldFlags": world_flags.duplicate(),
		"cityHistory": history_out,
		"pendingChanges": change_list,
		"quests": quest_list,
		"pendingConsequences": consequence_list,
		"cityEvents": event_list,
		"appliedChanges": applied_changes.duplicate(true),
		"buildingInvestments": buildings_out,
		"chronicle": chronicle_out,
		"chronicleSeq": chronicle_seq,
		"playerAvatar": avatar.to_dict() if avatar != null else {},
	}


## 把存档的可变状态合并到由配置构造好的世界对象上。
## 调用前须先 create() 并用配置填好城市，否则读到的城市会缺少配置字段。
func apply_dict(data: Dictionary) -> void:
	world_seed = int(data.get("worldSeed", world_seed)) & DeterministicRNG.MASK32
	if rng == null:
		rng = DeterministicRNG.new(world_seed)
	rng.set_state(int(data.get("rngState", rng.get_state())))
	for entry in data.get("cities", []):
		var city_id: String = str(entry.get("cityId", ""))
		var city: City = get_city(city_id)
		if city != null:
			city.apply_dict(entry)
			city.npc_ids.clear()

	npcs.clear()
	npc_seq = int(data.get("npcSeq", 1))
	for entry in data.get("npcs", []):
		var npc := SimNpc.from_dict(entry)
		if npc.npc_id.is_empty():
			continue
		npcs[npc.npc_id] = npc
		var owner: City = get_city(npc.city_id)
		if owner != null:
			owner.npc_ids.append(npc.npc_id)

	relations.clear()
	var relation_in: Dictionary = data.get("relations", {})
	for key in relation_in:
		var records: Array = []
		for record in relation_in[key]:
			records.append({
				"toNpcId": str(record.get("toNpcId", "")),
				"type": str(record.get("type", "")),
				"value": int(record.get("value", 0)),
			})
		relations[str(key)] = records

	trade_routes.clear()
	for entry in data.get("tradeRoutes", []):
		trade_routes.append(TradeRoute.from_dict(entry))

	world_flags = data.get("worldFlags", {}).duplicate()

	city_history.clear()
	var history_in: Dictionary = data.get("cityHistory", {})
	for key in history_in:
		var entry_in: Dictionary = history_in[key]
		var entry: Dictionary = {}
		for dimension in City.ALL_DIMENSIONS:
			var series: Array = []
			for value in entry_in.get(dimension, []):
				series.append(int(value))
			entry[dimension] = series
		city_history[str(key)] = entry

	pending_changes.clear()
	for entry in data.get("pendingChanges", []):
		pending_changes.append(StateChange.from_dict(entry))

	quests.clear()
	for entry in data.get("quests", []):
		var quest := Quest.from_dict(entry)
		if not quest.quest_id.is_empty():
			quests.append(quest)

	pending_consequences.clear()
	for entry in data.get("pendingConsequences", []):
		pending_consequences.append({
			"dueMonth": int(entry.get("dueMonth", 0)),
			"cityId": str(entry.get("cityId", "")),
			"dimension": str(entry.get("dimension", "")),
			"delta": int(entry.get("delta", 0)),
			"text": str(entry.get("text", "")),
			"questId": str(entry.get("questId", "")),
			"seq": int(entry.get("seq", 0)),
		})

	events.clear()
	for entry in data.get("cityEvents", []):
		var event := CityEvent.from_dict(entry)
		if not event.event_id.is_empty():
			events.append(event)

	applied_changes.clear()
	var applied: Dictionary = data.get("appliedChanges", {})
	for key in applied:
		var entry: Dictionary = applied[key]
		applied_changes[str(key)] = {
			"sig": str(entry.get("sig", "")),
			"month": int(entry.get("month", 0)),
		}

	building_investments.clear()
	var builds_in: Dictionary = data.get("buildingInvestments", {})
	for city_key in builds_in:
		var per_city: Dictionary = {}
		var city_builds: Dictionary = builds_in[city_key]
		for bkey in city_builds:
			per_city[str(bkey)] = int(city_builds[bkey])
		building_investments[str(city_key)] = per_city

	chronicle.clear()
	chronicle_seq = int(data.get("chronicleSeq", 0))
	for entry in data.get("chronicle", []):
		if entry is Dictionary:
			chronicle.append((entry as Dictionary).duplicate(true))

	var avatar_data: Dictionary = data.get("playerAvatar", {})
	avatar = PlayerAvatar.from_dict(avatar_data) if not avatar_data.is_empty() else null
