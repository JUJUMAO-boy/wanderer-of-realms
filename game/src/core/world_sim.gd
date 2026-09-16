class_name WorldSim
extends RefCounted

## 世界模拟（接口 I-03 至 I-11）。城市六维的**唯一写入口**（技术设计文档 10.1 节）。
##
## 三个必须守住的约束：
##
## 1. 城市状态只有这里能改。任务、事件、玩家的影响一律以 StateChange 提交，
##    入队后等到下一个整月结算才落账。这条约束的价值在出问题时才体现：任何
##    一次城市数值变化都能追到是哪条 change 造成的。
## 2. 结算顺序固定。城市按 cityId 排序、NPC 按 npcId 排序、路线按 routeId 排序，
##    绝不依赖哈希容器的遍历顺序。顺序一变，随机流的消费次序就变，同一份存档
##    会长出不同的世界。
## 3. 时间不由这里持有。settleMonth 的月份由调用方传入而不是自己读时钟——
##    世界模拟里再存一份"当前月份"，就等于让同一件事有两个真相。
##
## 月度结算除了改动数字，还产出一份**逐项归因报告**（cityDeltas）：每个维度
## 本月为什么涨、为什么跌，分别由哪几项贡献了多少。这是"世界演化可被感知"
## 的底层依据——只给一个净变化，玩家永远只能看着数字动而说不出原因。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_CONFLICT: String = "CONFLICT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"
const ERROR_CAPACITY_EXCEEDED: String = "CAPACITY_EXCEEDED"
const ERROR_CONTENT_MISSING: String = "CONTENT_MISSING"

## NPC 池与目标的差距小于这个值就不补。它纯粹是快进的性能取舍：
## 人口每月变动不到 1 点，对应的 NPC 目标每月只差 1–2 人，若每月都重建关系网，
## 快进一百年要在无谓的差异上花掉大量时间。它不影响"补完之后数量等于目标"。
const NPC_SYNC_THRESHOLD: int = 2

## 单月迁出达到这个人数才记入事件流。低于它的零星搬迁是背景噪声，
## 全记下来会把真正值得注意的事淹掉。
const MIGRATION_EVENT_THRESHOLD: int = 8

# 事件类别，供界面按类着色或过滤
const EVENT_TIER: String = "tier"
const EVENT_ROUTE: String = "route"
const EVENT_CONFISCATION: String = "confiscation"
const EVENT_MIGRATION: String = "migration"
const EVENT_NPC: String = "npc"
const EVENT_WORLD: String = "world"
const EVENT_QUEST: String = "quest"
## 城市事件（M7.1）。与委托分开一类：委托是玩家接的活，事件是城里自己出的事。
const EVENT_CITY_EVENT: String = "cityEvent"

var world: WorldState
var evolution: CityEvolution
var economy: Economy
var generator: NpcGenerator
var quests: QuestSystem
var events: EventSystem
## 世界纪年（M16）：把达标城市事件与城市升/降阶沉淀成跨代落盘的历史条目。
var chronicle: Chronicle

var _dim_min: int = 0
var _dim_max: int = 100
var _trade: Dictionary = {}
var _npc_cfg: Dictionary = {}
var _months_per_year: int = 12
## 建筑数值段（balance.buildings）。供等级派生/贡献/投资取数。
var _building_bal: Dictionary = {}
## 建筑配置索引：buildingId -> cfg（来自 buildings.json，经 load_buildings 注入）。
var _buildings_cfg: Dictionary = {}
## 按城的建筑配置：cityId -> [cfg]，每城按 buildingId 排序，保证结算确定性。
var _buildings_by_city: Dictionary = {}
## 玩家自己建的走私航线每月进账（铜）。量化规则 6 章的「垄断贸易路线：该路线
## 收益归玩家」只给了效果没给数值，取值与理由见技术设计文档 9.6 的 D-30。
var _player_smuggling_income: int = 300
## 玩家自建传奇航线的月进账（铜）。传奇航线只有事件奖励才给得出来，且归玩家。
var _legendary_player_income: int = 800


func _init(p_world: WorldState, balance: Dictionary, profession_cfg: Dictionary,
		name_cfg: Dictionary, personality_cfg: Dictionary = {}) -> void:
	world = p_world
	evolution = CityEvolution.new(balance.get("cityEvolution", {}))
	economy = Economy.new(balance)
	generator = NpcGenerator.new(profession_cfg, name_cfg, balance.get("npc", {}),
		personality_cfg)
	quests = QuestSystem.create(p_world)
	events = EventSystem.create(p_world)
	chronicle = Chronicle.create()
	_trade = balance.get("trade", {})
	_npc_cfg = balance.get("npc", {})
	var dim: Dictionary = balance.get("cityDimension", {})
	_dim_min = int(dim.get("min", 0))
	_dim_max = int(dim.get("max", 100))
	_months_per_year = maxi(1, int(balance.get("time", {}).get("monthsPerYear", 12)))
	_player_smuggling_income = int(_trade.get("playerSmugglingIncomeCopper", 300))
	_legendary_player_income = int(_trade.get("legendaryPlayerIncomeCopper", 800))
	_building_bal = balance.get("buildings", {})


## 从 ContentLoader 取配置构造。逻辑类不继承 Node，但配置来源可以是 autoload。
static func create(p_world: WorldState) -> WorldSim:
	var sim := WorldSim.new(
		p_world,
		ContentLoader.get_balance(),
		ContentLoader.get_profession_config(),
		ContentLoader.get_name_pool_config(),
		ContentLoader.get_personality_config()
	)
	sim.load_buildings(ContentLoader.get_building_configs())
	return sim


## 注入建筑配置（buildings.json 的 buildings 数组）。每城按 buildingId 排序建索引，
## 保证结算时遍历顺序确定——建筑贡献折进 deltas 的路子与贸易路线同源。
func load_buildings(cfgs: Array) -> void:
	_buildings_cfg.clear()
	_buildings_by_city.clear()
	for cfg in cfgs:
		var bid: String = str(cfg.get("buildingId", ""))
		var city_id: String = str(cfg.get("cityId", ""))
		if bid.is_empty() or city_id.is_empty():
			continue
		_buildings_cfg[bid] = cfg
		if not _buildings_by_city.has(city_id):
			_buildings_by_city[city_id] = []
		(_buildings_by_city[city_id] as Array).append(cfg)
	for city_id in _buildings_by_city:
		(_buildings_by_city[city_id] as Array).sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("buildingId", "")) < str(b.get("buildingId", "")))


## 新世界的初始化：铺满各城的模拟 NPC，建立预置贸易路线。
## 读档路径不走这里——存档里已经带着 NPC 与路线，重建会与存档打架。
static func bootstrap(p_world: WorldState) -> Array:
	var sim: WorldSim = WorldSim.create(p_world)
	var events: Array = []
	for route in ContentLoader.get_preset_routes():
		var result: Dictionary = sim.establish_route(
			str(route["cityA"]), str(route["cityB"]), str(route["kind"]), 0
		)
		if not result.get("ok", false):
			events.append(event("", 0, EVENT_ROUTE, "预置路线未能建立：%s ↔ %s（%s）" % [
				str(route["cityA"]), str(route["cityB"]), str(result.get("error", ""))
			]))
	for city_id in p_world.get_city_ids():
		sim._sync_city_npcs(str(city_id), true)
		events.append_array(sim._assign_positions(str(city_id), 0))
		p_world.record_history(p_world.get_city(str(city_id)))
	return events


# --- 月度结算 ---

## 结算一个月。调用方在收到 Clock 的月事件后调用它，并把当前月份传进来。
##
## 顺序是刻意的，每一步都依赖上一步的结果：
##   1. 断掉治安崩塌的路线（先断，免得它本月还产生收益）
##   2. 委托的延迟后果与过期委托（在落账之前排队，才能本月生效）
##   3. 城市事件的触发与持续代价（同上；触发当月还要断掉该城的航线）
##   4. 落账上月排队的变更（玩家的干预先于自然演化生效）
##   5. 六维自然演化
##   6. 贸易收益与查抄
##   7. 重算城市阶段，产出建模变化标记
##   8. NPC 池对齐与迁移
##   9. 记录六维历史
##
## detail 由快进传 false。快进一百年要结算 1200 次，而每次的逐项归因字典
## （每城每维一份，含若干项）与历史快照都没人会看：归因是给面板看"本月为什么
## 变了"，历史是给趋势线看，快进只关心终点。实测这两项在快进里会占掉相当
## 比例的时间，而它们产出的数据全被丢掉。
func settle_month(month: int, detail: bool = true) -> Dictionary:
	var notable: Array = []
	var deltas: Dictionary = {}

	# 先记下月初的阶段。放在任何写入之前，否则本月内由变更或演化造成的
	# 跨档就漏报了——而"城市从城镇变成城市"正是玩家最该看到的反馈。
	var tier_before: Dictionary = {}
	for city_id in world.get_city_ids():
		tier_before[str(city_id)] = world.get_city(str(city_id)).get_tier()

	var broken: Array = _break_endangered_routes()
	for entry in broken:
		notable.append(event(str(entry["cityId"]), month, EVENT_ROUTE,
			"%s 与 %s 的%s因治安崩坏中断" % [
				str(entry["cityId"]), str(entry["otherCityId"]),
				route_kind_label(str(entry["kind"])),
			]))

	# 委托的延迟后果（M4.3）。到期的先变成变更请求提交，紧接着的
	# _apply_pending_changes 会在同一个月把它落账——"数月后塌方"不该再多等一个月。
	var due: Dictionary = quests.promote_due_consequences(month)
	for change in due["changes"]:
		var submitted: Dictionary = apply_state_change(change)
		if not bool(submitted.get("ok", false)):
			notable.append(event(str(change.city_id), month, EVENT_QUEST,
				"委托的后续后果没能提交：%s" % str(submitted.get("error", ""))))
	for notice in due["notices"]:
		notable.append(event(str(notice["cityId"]), month, EVENT_QUEST, str(notice["text"])))
	# 过期委托。手上有张欠条却一直不办，城里的耐心会用完。
	for notice in quests.expire_overdue(month):
		notable.append(event(str(notice["cityId"]), month, EVENT_QUEST, str(notice["text"])))

	# 城市事件（M7.1）。两道钩子都排在落账之前，理由各不相同：
	#   触发在前——封港的瞬时冲击要在触发当月就落下来，排到落账之后就晚了一个月；
	#   持续在后——它要跳过触发当月（那个月已经吃了 -30），所以不能在触发里一起做。
	# 排在委托之后：两者都往同一个队列里排变更，先来后到不该影响内容。
	var triggered: Dictionary = events.check_triggers(month)
	var city_events: Array = triggered.get("events", [])
	for change in triggered["changes"]:
		var submitted: Dictionary = apply_state_change(change)
		if not bool(submitted.get("ok", false)):
			notable.append(event(str(change.city_id), month, EVENT_CITY_EVENT,
				"事件的冲击没能提交：%s" % str(submitted.get("error", ""))))
	for notice in triggered["notices"]:
		notable.append(event(str(notice["cityId"]), month, EVENT_CITY_EVENT, str(notice["text"])))

	var drained: Dictionary = events.apply_monthly_drain(month)
	for change in drained["changes"]:
		var submitted_drain: Dictionary = apply_state_change(change)
		if not bool(submitted_drain.get("ok", false)):
			notable.append(event(str(change.city_id), month, EVENT_CITY_EVENT,
				"事件的持续代价没能提交：%s" % str(submitted_drain.get("error", ""))))
	for notice in drained["notices"]:
		notable.append(event(str(notice["cityId"]), month, EVENT_CITY_EVENT, str(notice["text"])))

	# 世界纪年（M16）：本月触发的城市事件里够格的（模板 chronicleBp ≥ 阈值）沉淀成
	# 一条纪年。事件流留的是单城窗口，史书要的是跨代还能翻的大事——阈值过滤防刷屏。
	for ce in city_events:
		var ce_cfg: Dictionary = ContentLoader.get_event_template(ce.template_id)
		if chronicle.is_notable(ce_cfg):
			chronicle.record(world, chronicle.event_entry(world, ce))

	var applied: int = _apply_pending_changes(month, deltas, detail)

	for city_id in world.get_city_ids():
		_evolve_city(str(city_id), deltas, detail)

	# 封港中的城市：这些城相关的航线本月收益整条中断（不注销，解封即恢复）。
	# 集合取自上面刚跑完的触发与了结，所以"这个月刚封上的港口"当月就断航。
	var settlements: Dictionary = economy.settle_routes(
		world, month, world.rng, events.blockade_cities()
	)
	_apply_route_yields(settlements, deltas, detail)
	# 建筑月度贡献（D-69~D-72）：折各城本月维度 milli，路子与贸易路线同源。
	_apply_building_contributions(deltas, detail)
	var building_income: int = _apply_player_building_income()
	var confiscations: Array = settlements.get("confiscations", [])
	for entry in confiscations:
		notable.append(event(str(entry["cityId"]), month, EVENT_CONFISCATION,
			"%s 的走私航线被查抄，本月收益归零，声誉 -%d、善恶 -%d" % [
				_city_label(str(entry["cityId"])), int(entry["reputationLoss"]),
				int(entry["karmaLoss"]),
			]))

	var tier_changes: Array = []
	var city_tiers: Dictionary = {}
	for city_id in world.get_city_ids():
		var city: City = world.get_city(str(city_id))
		var now_tier: int = city.get_tier()
		city_tiers[str(city_id)] = now_tier
		if now_tier != int(tier_before[str(city_id)]):
			tier_changes.append({
				"cityId": str(city_id),
				"from": int(tier_before[str(city_id)]),
				"to": now_tier,
				"fromLabel": str(City.TIER_LABELS[int(tier_before[str(city_id)])]),
				"label": city.get_tier_label(),
			})
			notable.append(event(str(city_id), month, EVENT_TIER,
				"%s 的建模变为%s（原为%s）" % [
					city.display_name, city.get_tier_label(),
					str(City.TIER_LABELS[int(tier_before[str(city_id)])]),
				]))

	# 世界纪年（M16）：城市跨档（升阶或降阶）是史书重头戏，逐条沉淀。
	for tchange in tier_changes:
		chronicle.record(world, chronicle.tier_entry(
			world, str(tchange["cityId"]), str(tchange["fromLabel"]),
			str(tchange["label"]), month))

	for city_id in world.get_city_ids():
		_sync_city_npcs(str(city_id), false)

	var migration: Dictionary = _settle_migration()
	for city_id in migration:
		var moved: int = int(migration[city_id]["out"])
		if moved >= MIGRATION_EVENT_THRESHOLD:
			notable.append(event(str(city_id), month, EVENT_MIGRATION,
				"%s 有 %d 名居民迁往他乡" % [_city_label(str(city_id)), moved]))

	# 随从契约月结（M18）：每个月契约少一月，期满自动解除并记纪年。
	var expired_hires: Array = []
	for hire_id in world.active_hires.keys():
		var hire: Dictionary = world.active_hires[str(hire_id)]
		hire["monthsLeft"] = maxi(0, int(hire["monthsLeft"]) - 1)
		if int(hire["monthsLeft"]) <= 0:
			expired_hires.append(str(hire_id))
	for hire_id in expired_hires:
		var npc: SimNpc = world.get_npc(hire_id)
		var name: String = npc.given_name if npc != null else str(world.active_hires[hire_id].get("name", "随从"))
		if npc != null:
			chronicle.record(world, chronicle.fallen_entry(world, npc, "随从%s的契约期满，好聚好散。" % npc.given_name, month))
		world.active_hires.erase(hire_id)
		notable.append(event("", month, EVENT_NPC, "随从%s解约离队" % name))

	if detail:
		_record_history()

	_prune_applied_changes(month)

	return {
		"month": month,
		"appliedChanges": applied,
		"cityDeltas": deltas,
		"cityTiers": city_tiers,
		"tierChanges": tier_changes,
		"notableEvents": notable,
		"regularYields": settlements.get("regular", []),
		"smugglingYields": settlements.get("smuggling", []),
		"confiscations": confiscations,
		## 封港中断的航线（本月收益整条跳过，不是被查抄也不是断了）
		"haltedRoutes": settlements.get("halted", []),
		## 本月触发/了结的城市事件实例（CityEvent）。快进里也只用来记事件流，
		## 但面板会拿它说"城里现在有一件大事"。
		"cityEvents": city_events,
		"migration": migration,
		"brokenRoutes": broken,
		## 玩家自己建的走私航线本月进账（铜）。世界航线不给他钱，两者都不进这里。
		"playerSmugglingIncome": int(settlements.get("playerIncome", 0)),
		## 玩家建筑投资的月收益（铜）。按投资级结算，与走私营收并行。
		"buildingIncome": int(building_income),
	}


## 快进若干月（接口 I-04，转生沉眠用）。起始月份由调用方给出，
## 返回里带上结束月份，调用方据此推进自己的时钟。
func fast_forward(start_month: int, months: int, stop_at: Callable = Callable()) -> Dictionary:
	if months <= 0:
		return {
			"monthsAdvanced": 0,
			"endMonth": start_month,
			"cityHistory": {},
			"notableEvents": [],
			"stopped": false,
		}

	var history: Dictionary = {}
	for city_id in world.get_city_ids():
		history[str(city_id)] = []
	var notable: Array = []
	var advanced: int = 0
	var month: int = start_month

	for _i in range(months):
		month += 1
		advanced += 1
		var report: Dictionary = settle_month(month, false)
		notable.append_array(report["notableEvents"])
		for city_id in world.get_city_ids():
			var city: City = world.get_city(str(city_id))
			var snapshot: Dictionary = {}
			for dimension in City.ALL_DIMENSIONS:
				snapshot[dimension] = city.get_dimension(dimension)
			history[str(city_id)].append(snapshot)
		if month % _months_per_year == 0:
			var yearly: Dictionary = settle_year(month)
			notable.append_array(yearly["notableEvents"])
		if stop_at.is_valid() and bool(stop_at.call(month)):
			break

	_record_history()

	return {
		"monthsAdvanced": advanced,
		"endMonth": month,
		"cityHistory": history,
		"notableEvents": notable,
		"stopped": advanced < months,
	}


## 年度结算：NPC 增龄与死亡（5.2 节）。年龄以年为单位，不按月推进。
func settle_year(month: int = 0) -> Dictionary:
	var notable: Array = []
	var deaths: int = 0

	for city_id in world.get_city_ids():
		var city: City = world.get_city(str(city_id))
		var npcs: Array = world.get_city_npcs(str(city_id))
		for npc in npcs:
			npc.age += 1
			if not npc.is_at_lifespan():
				continue
			if not str(npc.position_id).is_empty():
				notable.append(event(str(city_id), month, EVENT_NPC,
					"%s 的%s %s 逝世，职位空缺" % [
						city.display_name,
						generator.position_display_name(str(npc.position_id)),
						npc.display_name(),
					]))
			world.remove_npc(str(npc.npc_id))
			deaths += 1
		notable.append_array(_assign_positions(str(city_id), month))

	return {"deaths": deaths, "notableEvents": notable}


# --- 读取 ---

func get_city(city_id: String) -> Dictionary:
	var city: City = world.get_city(city_id)
	if city == null:
		return {}
	return _city_view(city)


func get_cities() -> Array:
	var out: Array = []
	for city_id in world.get_city_ids():
		out.append(_city_view(world.get_city(str(city_id))))
	return out


## 按条件查询模拟 NPC。filter 可含 cityId / professionId / isNamed / ageRange。
func query_npcs(filter: Dictionary = {}) -> Array:
	var city_id: String = str(filter.get("cityId", ""))
	if not city_id.is_empty() and world.get_city(city_id) == null:
		return []
	var profession: String = str(filter.get("professionId", ""))
	var named_only: bool = bool(filter.get("isNamed", false))
	var age_range: Array = filter.get("ageRange", [])
	var age_min: int = int(age_range[0]) if age_range.size() >= 2 else -1
	var age_max: int = int(age_range[1]) if age_range.size() >= 2 else -1

	var source_ids: Array = []
	if city_id.is_empty():
		source_ids = world.get_city_ids()
	else:
		source_ids = [city_id]

	var out: Array = []
	for cid in source_ids:
		var npcs: Array = world.get_city_npcs(str(cid))
		for npc in npcs:
			if not profession.is_empty() and str(npc.profession_id) != profession:
				continue
			if named_only and not npc.is_named:
				continue
			if age_min >= 0 and (npc.age < age_min or npc.age > age_max):
				continue
			out.append(_npc_view(npc))
	return out


func get_relations(npc_id: String, direction: String = "both") -> Array:
	if world.get_npc(npc_id) == null:
		return []
	return world.get_relations(npc_id, direction)


func get_npc(npc_id: String) -> Dictionary:
	var npc: SimNpc = world.get_npc(npc_id)
	if npc == null:
		return {}
	return _npc_view(npc)


## 某城某维的历史序列，末尾为最近一月。
func get_history(city_id: String, dimension: String) -> Array:
	return world.get_history(city_id, dimension)


# --- 写入 ---

## 提交一条城市状态变更（接口 I-07）。只入队，落账在下一次 settleMonth。
##
## changeId 重复提交时返回 applied=false 而非报错：这是幂等，不是错误。
## 只有同一 changeId 带着不同载荷时才算真冲突（CONFLICT），因为那说明调用方
## 复用了幂等键，两条不同的变更会被静默吞掉一条。
func apply_state_change(change: StateChange) -> Dictionary:
	var invalid: String = change.validate()
	if not invalid.is_empty():
		return _fail(ERROR_INVALID_ARGUMENT, invalid)
	var city: City = world.get_city(change.city_id)
	if city == null:
		return _fail(ERROR_NOT_FOUND, "城市不存在：%s" % change.city_id)

	var signature: String = change.signature()
	if world.applied_changes.has(change.change_id):
		var recorded: Dictionary = world.applied_changes[change.change_id]
		if str(recorded.get("sig", "")) != signature:
			return _fail(ERROR_CONFLICT, "changeId %s 已用于另一条变更" % change.change_id)
		return _duplicate_result(city, change)
	for queued in world.pending_changes:
		if str(queued.change_id) == change.change_id:
			if queued.signature() != signature:
				return _fail(ERROR_CONFLICT, "changeId %s 已用于另一条变更" % change.change_id)
			return _duplicate_result(city, change)

	world.pending_changes.append(change)
	var preview: int = _preview_value(change.city_id, change.dimension)
	var projected: int = city.get_dimension(change.dimension) + _queued_delta(change)
	return {
		"ok": true,
		"applied": true,
		"duplicate": false,
		"clamped": preview != projected,
		"newValue": preview,
		"errorCode": ERROR_NONE,
		"error": "",
	}


## 生成一个模拟 NPC（接口 I-09）。缺省字段按 11.4 节规则补齐。
func create_npc(spec: Dictionary) -> Dictionary:
	var city_id: String = str(spec.get("cityId", ""))
	var city: City = world.get_city(city_id)
	if city == null:
		return _fail(ERROR_NOT_FOUND, "城市不存在：%s" % city_id)
	var cap: int = int(_npc_cfg.get("simulatedCap", 200))
	if city.npc_ids.size() >= cap:
		return _fail(ERROR_CAPACITY_EXCEEDED, "%s 的模拟 NPC 已达上限 %d" % [city_id, cap])

	var spawned: Dictionary = generator.spawn_batch(city, 1, world.npc_seq, world.rng)
	world.npc_seq = int(spawned["nextSeq"])
	var batch: Array = spawned["npcs"]
	if batch.is_empty():
		return _fail(ERROR_CONTENT_MISSING, "姓名池为空，无法生成 NPC")
	var npc: SimNpc = batch[0]
	if spec.has("raceId"):
		npc.race_id = str(spec["raceId"])
		npc.lifespan = generator.lifespan_of(npc.race_id)
	if spec.has("age"):
		npc.age = maxi(1, int(spec["age"]))
	npc.is_named = bool(spec.get("isNamed", false))
	if spec.has("professionId"):
		npc.profession_id = str(spec["professionId"])
	world.add_npc(npc)
	return {"ok": true, "npcId": npc.npc_id, "errorCode": ERROR_NONE, "error": ""}


## 建立贸易路线（接口 I-11）。正规商路与走私航线的判定条件见 9.3 / 9.4 节。
##
## owner_id 缺省是世界的航线；玩家自己建的传 TradeRoute.OWNER_PLAYER，
## 只有那种航线被查抄才扣玩家的声誉与善恶。
func establish_route(
	city_x: String, city_y: String, kind: String, month: int = 0,
	owner_id: String = TradeRoute.OWNER_WORLD
) -> Dictionary:
	if not TradeRoute.ALL_KINDS.has(kind):
		return _fail(ERROR_INVALID_ARGUMENT, "未知路线类型：%s" % kind)
	var a: City = world.get_city(city_x)
	var b: City = world.get_city(city_y)
	if a == null:
		return _fail(ERROR_NOT_FOUND, "城市不存在：%s" % city_x)
	if b == null:
		return _fail(ERROR_NOT_FOUND, "城市不存在：%s" % city_y)
	if a.city_id == b.city_id:
		return _fail(ERROR_INVALID_ARGUMENT, "两端不能是同一座城市")
	if world.find_route(city_x, city_y) != null:
		return _fail(ERROR_CONFLICT, "该路线已存在")

	var distance: int = a.distance_to(b)
	var label: String = "正规商路"
	if kind == TradeRoute.KIND_LEGENDARY:
		# 传奇航线不谈条件：它是事件奖励，买到的正是"不受 9.3 / 9.4 那套门槛约束"。
		# 但上限要留——否则同一条传奇航线可以被同一个事件反复解锁。
		label = route_kind_label(kind)
		var legendary_cap: int = int(_trade.get("legendaryMaxPerCity", 1))
		var held_legend: int = maxi(
			world.get_routes_of_city(a.city_id, TradeRoute.KIND_LEGENDARY).size(),
			world.get_routes_of_city(b.city_id, TradeRoute.KIND_LEGENDARY).size()
		)
		if held_legend >= legendary_cap:
			return _fail(ERROR_CAPACITY_EXCEEDED, "每城最多 %d 条传奇航线" % legendary_cap)
	elif kind == TradeRoute.KIND_REGULAR:
		var bonus_min_dev: int = int(_trade.get("regularBonusMinDevelopment", 60))
		var limit: int = int(_trade.get("regularMaxDistance", 40))
		if a.development >= bonus_min_dev and b.development >= bonus_min_dev:
			limit = int(_trade.get("regularBonusMaxDistance", 60))
		if distance > limit:
			return _fail(ERROR_PRECONDITION_FAILED, "距离 %d 超出上限 %d" % [distance, limit])
		var min_security: int = int(_trade.get("regularMinSecurity", 40))
		if a.security < min_security or b.security < min_security:
			return _fail(ERROR_PRECONDITION_FAILED, "双方治安需 ≥ %d（当前 %d/%d）" % [
				min_security, a.security, b.security
			])
		var cap: int = int(_trade.get("regularMaxPerCity", 3))
		var multi_dev: int = int(_trade.get("regularMultiRouteMinDevelopment", 60))
		var held_a: int = world.get_routes_of_city(a.city_id, TradeRoute.KIND_REGULAR).size()
		var held_b: int = world.get_routes_of_city(b.city_id, TradeRoute.KIND_REGULAR).size()
		if held_a >= cap or held_b >= cap:
			return _fail(ERROR_CAPACITY_EXCEEDED, "每城最多 %d 条正规商路" % cap)
		if (held_a >= 1 and a.development < multi_dev) or (held_b >= 1 and b.development < multi_dev):
			return _fail(ERROR_PRECONDITION_FAILED, "已有商路的城市建新路线需发展度 ≥ %d" % multi_dev)
	else:
		label = "走私航线"
		var check: Dictionary = smuggling_check(a, b)
		if not bool(check["ok"]):
			return _fail(str(check["errorCode"]), str(check["reason"]))

	var route: TradeRoute = TradeRoute.make(a.city_id, b.city_id, kind, month, owner_id)
	world.add_route(route)
	return {
		"ok": true, "routeId": route.route_id, "kind": kind,
		"label": label, "errorCode": ERROR_NONE, "error": "",
	}


## 走私航线的准入判定（9.4 节的条件表）。抽成独立方法是为了让界面在建立之前
## 就能说出"这条为什么不行"——让界面先调 establish_route 试一次再看要不要回滚，
## 等于把有副作用的操作当查询用。
func smuggling_check(a: City, b: City) -> Dictionary:
	var limit: int = int(_trade.get("smugglingMaxDistance", 60))
	var distance: int = a.distance_to(b)
	if distance > limit:
		return _check_fail(ERROR_PRECONDITION_FAILED, "距离 %d 超出上限 %d" % [distance, limit])
	if not (a.has_black_market or b.has_black_market):
		return _check_fail(ERROR_PRECONDITION_FAILED, "两端都没有黑市渠道")
	var cap: int = int(_trade.get("smugglingMaxPerCity", 2))
	var held_a: int = world.get_routes_of_city(a.city_id, TradeRoute.KIND_SMUGGLING).size()
	var held_b: int = world.get_routes_of_city(b.city_id, TradeRoute.KIND_SMUGGLING).size()
	if held_a >= cap or held_b >= cap:
		return _check_fail(ERROR_CAPACITY_EXCEEDED, "每城最多 %d 条走私航线（现 %d/%d）" % [
			cap, maxi(held_a, held_b), cap
		])
	return {"ok": true, "errorCode": ERROR_NONE, "reason": "", "distance": distance}


## 取消一条航线。玩家只能撤掉自己建的——世界的航线是 NPC 商旅的生意，
## 玩家没有权力替他们停掉。
func cancel_route(route_id: String) -> Dictionary:
	for route in world.get_routes_sorted():
		if str(route.route_id) != route_id:
			continue
		if not route.is_player_owned():
			return _fail(ERROR_PRECONDITION_FAILED, "这条航线不是你的，撤不掉")
		world.remove_route(route_id)
		return {
			"ok": true, "routeId": route_id, "kind": str(route.kind),
			"errorCode": ERROR_NONE, "error": "",
		}
	return _fail(ERROR_NOT_FOUND, "没有这条航线：%s" % route_id)


## 玩家自己在某城参与的走私航线。
func player_smuggling_routes(city_id: String = "") -> Array:
	var out: Array = []
	for route in world.get_routes_sorted():
		if not route.is_smuggling() or not route.is_player_owned():
			continue
		if not city_id.is_empty() and not route.involves(city_id):
			continue
		out.append(route)
	return out


## 从 city_id 出发的走私候选清单。建不了的那些也返回，并带上原因——
## 界面要回答的是"能连哪几座城"，只列能建的就等于让玩家自己试。
func smuggling_options(city_id: String) -> Array:
	var a: City = world.get_city(city_id)
	if a == null:
		return []
	var out: Array = []
	for other_id in world.get_city_ids():
		var other: City = world.get_city(str(other_id))
		if other == null or other.city_id == a.city_id:
			continue
		var exists: bool = world.find_route(a.city_id, other.city_id) != null
		var check: Dictionary = {"ok": false, "reason": "这两座城之间已有航线"}
		if not exists:
			check = smuggling_check(a, other)
		out.append({
			"cityId": other.city_id,
			"distance": a.distance_to(other),
			"security": other.security,
			"exists": exists,
			"ok": bool(check.get("ok", false)) and not exists,
			"reason": str(check.get("reason", "")),
		})
	return out


# --- 事件记录 ---

## 事件统一成结构而不是裸字符串：界面要按城市过滤、按类别着色，
## 裸字符串会让界面被迫去解析文本，等文案一改就崩。
static func event(city_id: String, month: int, kind: String, text: String) -> Dictionary:
	return {"cityId": city_id, "month": month, "kind": kind, "text": text}


# --- 内部：结算 ---

func _evolve_city(city_id: String, deltas: Dictionary, collect: bool) -> void:
	var city: City = world.get_city(city_id)
	if city == null:
		return
	var breakdown: Dictionary = evolution.monthly_breakdown(city)
	for dimension in City.ALL_DIMENSIONS:
		var items: Array = breakdown.get(dimension, [])
		var total_milli: int = CityEvolution.sum_items(items)
		var result: Dictionary = CityEvolution.apply_milli(
			city, dimension, total_milli, _dim_min, _dim_max
		)
		if collect:
			_add_delta(deltas, city_id, dimension, int(result["whole"]), total_milli, items)


## 落账上月排队的变更。同一 (城, 维度) 的增量先合并再钳制一次——若逐条钳制，
## 前一条触顶会吃掉后一条的效果，而两者本可以叠加。
func _apply_pending_changes(month: int, deltas: Dictionary, collect: bool) -> int:
	if world.pending_changes.is_empty():
		return 0
	var totals: Dictionary = {}
	var by_source: Dictionary = {}
	var count: int = 0
	for change in world.pending_changes:
		var key: String = "%s|%s" % [change.city_id, change.dimension]
		totals[key] = int(totals.get(key, 0)) + change.delta
		if collect:
			if not by_source.has(key):
				by_source[key] = {}
			var source_map: Dictionary = by_source[key]
			source_map[change.source] = int(source_map.get(change.source, 0)) + change.delta
		world.applied_changes[change.change_id] = {
			"sig": change.signature(),
			"month": month,
		}
		count += 1
	world.pending_changes.clear()

	var keys: Array = totals.keys()
	keys.sort()
	for key in keys:
		var parts: PackedStringArray = str(key).split("|")
		var city: City = world.get_city(parts[0])
		if city == null:
			continue
		var dimension: String = parts[1]
		var before: int = city.get_dimension(dimension)
		var requested: int = int(totals[key])
		city.set_dimension(dimension, clampi(before + requested, _dim_min, _dim_max))
		if not collect:
			continue

		var items: Array = []
		var source_map: Dictionary = by_source[key]
		var sources: Array = source_map.keys()
		sources.sort()
		for source in sources:
			items.append({
				"key": "change-" + str(source),
				"label": _source_label(str(source)),
				"milli": int(source_map[source]) * CityEvolution.SCALE,
			})
		var applied: int = city.get_dimension(dimension) - before
		_add_delta(deltas, parts[0], dimension, applied, requested * CityEvolution.SCALE, items)
	return count


## 断掉任一端治安低于门槛的路线（2.4 节的「路线中断」）。
##
## 只管正规商路。2.4 节那张门槛表明确写着"上表描述的是正规商路"，而 9.4 节给
## 走私航线的条件里根本没有治安这一项——它存在的意义正是规避那道门槛。
## 原先这里一视同仁，结果十字路（治安 20）的两条走私航线在开局第一个月就被系统
## 自己断光，而设定里它恰恰是"全大陆最适合走私的城市"。
##
## 传奇航线同样豁免：它买到的是"不受这套规则约束"（《城市事件剧本》EV-02）。
func _break_endangered_routes() -> Array:
	var threshold: int = int(_trade.get("routeBreakSecurityThreshold", 30))
	var broken: Array = []
	var doomed: Array = []
	for route in world.get_routes_sorted():
		if route.is_smuggling() or route.is_legendary():
			continue
		var a: City = world.get_city(str(route.city_a))
		var b: City = world.get_city(str(route.city_b))
		if a == null or b == null:
			continue
		if a.security >= threshold and b.security >= threshold:
			continue
		var culprit: City = a if a.security < b.security else b
		var other: City = b if culprit == a else a
		doomed.append(str(route.route_id))
		broken.append({
			"routeId": str(route.route_id),
			"cityId": culprit.city_id,
			"otherCityId": other.city_id,
			"kind": str(route.kind),
		})
	for route_id in doomed:
		world.remove_route(route_id)
	return broken


func _apply_route_yields(settlements: Dictionary, deltas: Dictionary, collect: bool) -> void:
	var groups: Array = [
		{"key": "regular", "label": "正规商路"},
		{"key": "smuggling", "label": "走私航线"},
		{"key": "legendary", "label": "传奇航线"},
	]
	for group in groups:
		var group_key: String = str(group["key"])
		var label: String = str(group["label"])
		for entry in settlements.get(group_key, []):
			var city: City = world.get_city(str(entry["cityId"]))
			if city == null:
				continue
			var wealth_milli: int = int(entry["wealthMilli"])
			var culture_milli: int = int(entry["cultureMilli"])
			if wealth_milli == 0 and culture_milli == 0:
				# 被查抄的那一条：记一笔零额度的说明，否则玩家只会看到
				# "这个月商路收益没了"，却不知道是被查抄还是路线断了
				if collect:
					_add_delta(deltas, city.city_id, City.DIM_WEALTH, 0, 0,
						[{"key": group_key + "-seized", "label": label + "（被查抄）", "milli": 0}])
				continue
			var wealth_result: Dictionary = CityEvolution.apply_milli(
				city, City.DIM_WEALTH, wealth_milli, _dim_min, _dim_max
			)
			if collect:
				_add_delta(deltas, city.city_id, City.DIM_WEALTH, int(wealth_result["whole"]),
					wealth_milli, [{"key": group_key, "label": label, "milli": wealth_milli}])
			var culture_result: Dictionary = CityEvolution.apply_milli(
				city, City.DIM_CULTURE, culture_milli, _dim_min, _dim_max
			)
			if collect:
				_add_delta(deltas, city.city_id, City.DIM_CULTURE, int(culture_result["whole"]),
					culture_milli, [{"key": group_key, "label": label, "milli": culture_milli}])

	for entry in settlements.get("halted", []):
		# 封港中断的航线也记一笔零额度：否则玩家只看到"本月商路收益没了"，
		# 分不清是被查抄还是港口封着。与上面被查抄那条同一个道理。
		if collect:
			_add_delta(deltas, str(entry["cityId"]), City.DIM_WEALTH, 0, 0,
				[{"key": "halted", "label": "封港（航运中断）", "milli": 0}])

	var income: int = _apply_player_route_income(settlements)
	_apply_confiscation_penalties(settlements)
	settlements["playerIncome"] = income


## 建筑月度维度贡献（D-69~D-72）：按生效等级把各城每个建筑的 dimensionBonus
## 折成该城某维的 milli，像贸易路线一样折进 deltas。遍历走 get_city_ids + 每城
## 按 buildingId 排序，保证结算顺序确定（同一份存档每次运行产出完全相同）。
func _apply_building_contributions(deltas: Dictionary, collect: bool) -> void:
	if _buildings_by_city.is_empty() or _building_bal.is_empty():
		return
	for city_id in world.get_city_ids():
		var city: City = world.get_city(str(city_id))
		if city == null:
			continue
		var list: Array = _buildings_by_city.get(str(city_id), [])
		for b in list:
			var bid: String = str(b.get("buildingId", ""))
			var effective: int = CityBuildings.effective_level(
				b, city,
				CityBuildings.invested_level(world, str(city_id), bid),
				_building_bal
			)
			if effective <= 0:
				continue
			var contrib: Dictionary = CityBuildings.monthly_contribution(b, effective)
			for dim in contrib:
				var milli: int = int(contrib[dim])
				if milli <= 0:
					continue
				var result: Dictionary = CityEvolution.apply_milli(
					city, str(dim), milli, _dim_min, _dim_max
				)
				if collect:
					_add_delta(deltas, str(city_id), str(dim), int(result["whole"]),
						milli, [{
							"key": "building-" + bid,
							"label": str(b.get("displayName", bid)) + "（经营）",
							"milli": milli,
						}])


## 玩家建筑投资的月收益（铜）。只算玩家亲手投的部分——城市自然等级不白给玩家
## 钱，否则没投过钱的城也会按月发钱，玩家收益与经营行为就脱钩了。投资即时结清
## 已扣 avatar.money，这里只是每月返钱，并入 avatar.money。
func _apply_player_building_income() -> int:
	var avatar: PlayerAvatar = world.avatar
	if avatar == null or _building_bal.is_empty():
		return 0
	var total: int = 0
	for city_id in world.get_city_ids():
		var invested_map: Dictionary = world.building_investments.get(str(city_id), {})
		for bid in invested_map:
			var invested: int = int(invested_map[bid])
			if invested <= 0:
				continue
			total += CityBuildings.player_income(invested, _building_bal)
	if total > 0:
		avatar.money += total
	return total


## 查抄的代价（9.4 节）：该城声誉 -5、善恶值 -2。
##
## 只算**玩家自己建的**航线。原先这里不看到底是谁的航线，于是玩家替全世界
## 的走私航线背锅：他既没有参与、也没有收益，名声却在挂机时一路掉，而且
## 声誉当时既没有回升路径也没有下限钳制。世界航线被查抄的代价落在城市身上
## ——该端本月收益归零，那条事件照旧进事件流。
func _apply_confiscation_penalties(settlements: Dictionary) -> void:
	var avatar: PlayerAvatar = world.avatar
	if avatar == null:
		return
	for entry in settlements.get("confiscations", []):
		if not bool(entry.get("playerOwned", false)):
			continue
		var city_id: String = str(entry["cityId"])
		avatar.set_reputation(city_id, avatar.get_reputation(city_id) - int(entry["reputationLoss"]))
		avatar.karma -= int(entry["karmaLoss"])


## 玩家自己名下的航线本月进账（量化规则 6 章「垄断贸易路线：该路线收益归
## 玩家」）。按**航线**算一次而不是按端点算两次——一条航线每个月只有一趟货，
## 两端各付一次钱就成了凭空翻倍。任一端被查抄即视为这批货丢了，当月不进账。
##
## 走私与传奇两类都算：传奇航线归玩家是《城市事件剧本》EV-02 给讨伐的报酬
## （「解锁传奇航线」），既然是给玩家的，进账就不能绕开他。
##
## 返回本月进账总额（铜），供状态行反馈。
func _apply_player_route_income(settlements: Dictionary) -> int:
	var avatar: PlayerAvatar = world.avatar
	if avatar == null:
		return 0
	var seized: Dictionary = {}
	for entry in settlements.get("confiscations", []):
		seized[str(entry["routeId"])] = true
	var groups: Array = [
		{"key": "smuggling", "copper": _player_smuggling_income},
		{"key": "legendary", "copper": _legendary_player_income},
	]
	var paid: Dictionary = {}
	var total: int = 0
	for group in groups:
		for entry in settlements.get(str(group["key"]), []):
			if not bool(entry.get("playerOwned", false)):
				continue
			var route_id: String = str(entry["routeId"])
			if paid.has(route_id) or seized.has(route_id):
				continue
			paid[route_id] = true
			total += int(group["copper"])
	if total > 0:
		avatar.money += total
	return total


static func _delta_slot(target: Dictionary, city_id: String, dimension: String) -> Dictionary:
	if not target.has(city_id):
		target[city_id] = {}
	var per_city: Dictionary = target[city_id]
	if not per_city.has(dimension):
		per_city[dimension] = {"applied": 0, "milli": 0, "items": []}
	return per_city[dimension]


static func _add_delta(
	target: Dictionary, city_id: String, dimension: String,
	applied: int, milli: int, items: Array
) -> void:
	var slot: Dictionary = _delta_slot(target, city_id, dimension)
	slot["applied"] = int(slot["applied"]) + applied
	slot["milli"] = int(slot["milli"]) + milli
	for item in items:
		(slot["items"] as Array).append(item)


func _record_history() -> void:
	for city_id in world.get_city_ids():
		world.record_history(world.get_city(str(city_id)))


# --- 内部：NPC ---

## 把某城的 NPC 池拉向 min(人口 × 3, 200)。force 为 true 时严格对齐，
## 用于新世界开局（M2.3 的验收标准）。
##
## 非强制时两个方向的门槛不一样，这不是随手定的：
##   - 缺口小就不补。人口每月只动不到 1 点，对应的目标每月只差 1–2 人，
##     每月重建一批人与关系网，快进一百年要在这点零头上耗费大量时间。
##   - 只有大幅超出才裁。因为迁移会让人口吸引力强的城市积起超出目标的居民，
##     若一超标就裁，迁移刚搬进来的人下个月就被削掉，等于白搬。
func _sync_city_npcs(city_id: String, force: bool) -> void:
	var city: City = world.get_city(city_id)
	if city == null:
		return
	var target: int = generator.target_count(city.population)
	# 只取人数时用 city.npc_ids，不走 get_city_npcs——后者会排序并构造一份
	# 对象数组，而这里每月每城都要问一次，快进一百年是近万次调用。
	var gap: int = target - city.npc_ids.size()
	if gap == 0:
		return
	if not force:
		if gap > 0 and gap < NPC_SYNC_THRESHOLD:
			return
		if gap < 0 and -gap <= _trim_slack(target):
			return

	if gap > 0:
		var spawned: Dictionary = generator.spawn_batch(city, gap, world.npc_seq, world.rng)
		world.npc_seq = int(spawned["nextSeq"])
		var batch: Array = spawned["npcs"]
		for npc in batch:
			world.add_npc(npc)
		var peers: Array = world.get_city_npcs(city_id)
		world.add_relations(generator.link_relations(batch, peers, city, world.rng))
		return

	# 超出目标：从 npcId 最大（最新）的一端裁掉，一次批量处理。
	# 逐条裁会为每个人扫一遍关系表，批量裁只扫一次。
	var npcs: Array = world.get_city_npcs(city_id)
	var excess: int = -gap
	var victims: Array = []
	for i in range(npcs.size() - 1, npcs.size() - 1 - excess, -1):
		if i < 0:
			break
		victims.append(str(npcs[i].npc_id))
	if victims.is_empty():
		return
	world.purge_npcs(victims)


func _trim_slack(target: int) -> int:
	@warning_ignore("integer_division")
	var half: int = target / 2
	return maxi(20, half)


## 迁移决策（5.4 节）。比较的是城市吸引力向量，不是 NPC 两两比较——
## 后者会让快进的复杂度从线性升到平方（设计文档 5.2 节）。
##
## 两处工程处理：一是目标城按吸引力降序列一张表，NPC 只做一次查表；
## 二是每座城的 NPC 列表只从头扫一遍（游标单调前进），不因换目标城而重扫。
## 缺少这两点，快进一百年会在迁移上耗掉与整套城市结算相当的算力。
func _settle_migration() -> Dictionary:
	var threshold: int = int(round(float(_npc_cfg.get("migrationThreshold", 0.3)) * 1000.0))
	var cap_ratio: float = float(_npc_cfg.get("migrationMonthlyCapRatio", 0.1))
	var margin: int = int(_npc_cfg.get("elderAgeMargin", 15))

	var attraction: Dictionary = {}
	var room: Dictionary = {}
	var report: Dictionary = {}
	var npc_cap: int = int(_npc_cfg.get("simulatedCap", 200))
	for city_id in world.get_city_ids():
		var cid: String = str(city_id)
		var city: City = world.get_city(cid)
		attraction[cid] = evolution.attractiveness(city)
		# 「有合适职业空缺」按硬上限衡量，而不是按 min(人口×3, 200) 的目标。
		# 若按目标衡量，池子常年贴着目标，room 恒为 0，迁移永远不会发生——
		# 那样 5.4 节的整条规则就是死代码。
		room[cid] = maxi(0, npc_cap - city.npc_ids.size())
		report[cid] = {"in": 0, "out": 0}

	var ranked: Array = _rank_by_attraction(attraction)

	for city_id in world.get_city_ids():
		var from_id: String = str(city_id)
		var npcs: Array = world.get_city_npcs(from_id)
		if npcs.size() <= 1:
			continue
		var cap: int = maxi(1, int(float(npcs.size()) * cap_ratio))
		var moved: int = 0
		var cursor: int = 0
		for candidate in ranked:
			if moved >= cap:
				break
			var to_id: String = str(candidate)
			if to_id == from_id:
				continue
			# ranked 是降序的：一旦连最高吸引力的城都不够诱人，后面的更不必看
			if int(attraction[to_id]) - int(attraction[from_id]) <= threshold:
				break
			while cursor < npcs.size() and moved < cap and int(room[to_id]) > 0:
				var npc: SimNpc = npcs[cursor]
				cursor += 1
				if npc.is_named:
					continue  # 具名 NPC 锚定在出生城（5.4 节）
				if npc.is_elder(margin):
					continue
				world.move_npc(str(npc.npc_id), to_id)
				room[to_id] = int(room[to_id]) - 1
				moved += 1
				report[from_id]["out"] = int(report[from_id]["out"]) + 1
				report[to_id]["in"] = int(report[to_id]["in"]) + 1
	return report


## 按吸引力降序排列城市 ID，同分时按 ID 升序——排序必须完全确定，
## 否则同一份存档的迁移结果会随哈希顺序漂移。
func _rank_by_attraction(attraction: Dictionary) -> Array:
	var ids: Array = attraction.keys()
	ids.sort()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var va: int = int(attraction[a])
		var vb: int = int(attraction[b])
		if va == vb:
			return str(a) < str(b)
		return va > vb)
	return ids


func _assign_positions(city_id: String, month: int) -> Array:
	var raw: Array = generator.assign_positions(world.get_city_npcs(city_id))
	var out: Array = []
	for text in raw:
		out.append(event(city_id, month, EVENT_NPC, str(text)))
	return out


## 航线类型的中文名。事件分支预览也要用它（"解锁传奇航线"），所以是公开的。
static func route_kind_label(kind: String) -> String:
	match kind:
		TradeRoute.KIND_SMUGGLING:
			return "走私航线"
		TradeRoute.KIND_LEGENDARY:
			return "传奇航线"
	return "商路"


static func _source_label(source: String) -> String:
	match source:
		StateChange.SOURCE_QUEST:
			return "委托"
		StateChange.SOURCE_EVENT:
			return "事件"
		StateChange.SOURCE_PLAYER:
			return "玩家"
		StateChange.SOURCE_DECAY:
			return "自然衰减"
	return source


# --- 内部：其他 ---

func _city_label(city_id: String) -> String:
	var city: City = world.get_city(city_id)
	return city.display_name if city != null else city_id


func _duplicate_result(city: City, change: StateChange) -> Dictionary:
	return {
		"ok": true, "applied": false, "duplicate": true, "clamped": false,
		"newValue": city.get_dimension(change.dimension),
		"errorCode": ERROR_NONE, "error": "",
	}


func _preview_value(city_id: String, dimension: String) -> int:
	var city: City = world.get_city(city_id)
	if city == null:
		return 0
	return clampi(
		city.get_dimension(dimension) + _queued_delta_for(city_id, dimension), _dim_min, _dim_max
	)


func _queued_delta(change: StateChange) -> int:
	return _queued_delta_for(change.city_id, change.dimension)


func _queued_delta_for(city_id: String, dimension: String) -> int:
	var total: int = 0
	for change in world.pending_changes:
		if change.city_id == city_id and change.dimension == dimension:
			total += change.delta
	return total


## 清掉过期的幂等记录。留 12 个月足够覆盖"读档重试同一批交付"，
## 又不至于让这张表随游玩时长无界增长。
func _prune_applied_changes(month: int) -> void:
	var cutoff: int = month - WorldState.APPLIED_CHANGE_RETENTION_MONTHS
	var expired: Array = []
	for change_id in world.applied_changes:
		if int(world.applied_changes[change_id]["month"]) < cutoff:
			expired.append(change_id)
	for change_id in expired:
		world.applied_changes.erase(change_id)


func _city_view(city: City) -> Dictionary:
	var view: Dictionary = {
		"cityId": city.city_id,
		"displayName": city.display_name,
		"tier": city.get_tier(),
		"tierLabel": city.get_tier_label(),
		"coordX": city.coord_x,
		"coordY": city.coord_y,
		"dominantFactionId": city.dominant_faction_id,
		"hasBlackMarket": city.has_black_market,
		"npcCount": city.npc_ids.size(),
		"regularRoutes": world.get_routes_of_city(city.city_id, TradeRoute.KIND_REGULAR).size(),
		"smugglingRoutes": world.get_routes_of_city(city.city_id, TradeRoute.KIND_SMUGGLING).size(),
		"legendaryRoutes": world.get_routes_of_city(city.city_id, TradeRoute.KIND_LEGENDARY).size(),
		"activeEvents": world.active_event_count(city.city_id),
	}
	for dimension in City.ALL_DIMENSIONS:
		view[dimension] = city.get_dimension(dimension)
	return view


func _npc_view(npc: SimNpc) -> Dictionary:
	return {
		"npcId": npc.npc_id,
		"cityId": npc.city_id,
		"displayName": npc.display_name(),
		"gender": npc.gender,
		"raceId": npc.race_id,
		"age": npc.age,
		"lifespan": npc.lifespan,
		"professionId": npc.profession_id,
		"isNamed": npc.is_named,
		"positionId": npc.position_id,
		"positionLabel": generator.position_display_name(str(npc.position_id))
			if not str(npc.position_id).is_empty() else "",
		"familyId": npc.family_id,
	}


static func _fail(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false, "applied": false, "duplicate": false, "clamped": false,
		"newValue": 0, "errorCode": error_code, "error": message,
	}


## 准入判定用的失败结果。与 _fail 分开是因为它不参与落账——那些 applied /
## duplicate / newValue 字段在这里没有任何含义，填上只会让人以为它落过账。
static func _check_fail(error_code: String, reason: String) -> Dictionary:
	return {"ok": false, "errorCode": error_code, "reason": reason}
