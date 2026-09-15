extends Node

## 内容加载器（接口 I-26 / I-27 / I-28）。
##
## 启动期把 JSON 配置读进来并校验。校验的原则是**失败得早、失败得准**：
## 配置错误若延迟到运行时才爆发，表现是"某个技能没效果""某座城数据不对"
## 这类间接症状，排查成本远高于启动期直接报出字段路径。
##
## 注意 autoload 顺序：本节点必须排在 Clock 之前（见 project.godot），
## 因为 Clock 在 _ready 里就要读 time 段的时间刻度。

const DATA_DIR: String = "res://data/"
const CITY_FILE: String = "cities.json"
const BALANCE_FILE: String = "balance.json"
const PROFESSION_FILE: String = "professions.json"
const NAME_POOL_FILE: String = "name_pools.json"
const TRADE_ROUTE_FILE: String = "trade_routes.json"
const SKILL_FILE: String = "skills.json"
const ITEM_FILE: String = "items.json"
const TALENT_FILE: String = "talents.json"
const BACKGROUND_FILE: String = "backgrounds.json"
const QUEST_FILE: String = "quests.json"
const EVENT_FILE: String = "events.json"
const AFFIX_FILE: String = "affixes.json"

## 允许的城市六维范围，由 balance.json 覆盖
const DEFAULT_DIM_MIN: int = 0
const DEFAULT_DIM_MAX: int = 100

## 11.3 节的职业分类。职业配置里的 category 必须是其中之一。
const PROFESSION_CATEGORIES: Array = [
	"production", "processing", "commerce", "knowledge", "military", "gray",
]

## 技能分类（《技术设计文档》8.5 节的裁剪范围）
const SKILL_CATEGORIES: Array = ["weapon", "spell", "technique", "passive"]
## 技能阶位（《技能库》1.3 节）
const SKILL_TIERS: Array = ["novice", "skilled", "expert", "master", "grandmaster", "passive"]
## 伤害类型（《数值框架》6.5 节元素克制表）
const DAMAGE_TYPES: Array = ["physical", "fire", "water", "holy", "dark", "soul", "none"]

## 物品分类与稀有度（《数值框架》8 节）
const ITEM_CATEGORIES: Array = ["weapon", "armor", "consumable"]
const ITEM_RARITIES: Array = [
	"common", "fine", "rare", "epic", "legendary", "dragonforged",
]

## 会占装备槽的类别（其余类别不得声明 slot）。槽位名本身来自
## balance.equipment.slots，不在这里写死——见 D-50。
const ITEM_EQUIP_CATEGORIES: Array = ["weapon", "armor"]

## 词缀的作用目标（《技术设计文档》3.3 节 Modifier[]）。前三个加在装备自身
## 的数值上，后七个是七维、加在佩戴者身上。这张表是词缀配置与
## balance.itemInstance.affixPricePerPoint 两处键名的唯一来源——见 D-54。
const AFFIX_TARGETS: Array = [
	"attack", "armor", "magicResist",
	"strength", "dexterity", "constitution",
	"intelligence", "perception", "charisma", "soul",
]

## 天赋与缺陷的分类（《数值框架》7 节，当量正负即分类）
const TALENT_CATEGORIES: Array = ["talent", "flaw"]

## 技能熟练度上限（《数值框架》1 节核心标尺：技能熟练度 0–100）
const SKILL_LEVEL_MAX: int = 100

var _city_configs: Array = []
var _balance: Dictionary = {}
var _professions: Dictionary = {}
var _name_pools: Dictionary = {}
var _trade_routes: Array = []
var _skills: Dictionary = {}
var _items: Dictionary = {}
var _talents: Dictionary = {}
var _backgrounds: Dictionary = {}
var _quests: Dictionary = {}
var _events: Dictionary = {}
var _affixes: Dictionary = {}
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _loaded: bool = false


func _ready() -> void:
	var report: Dictionary = load_all()
	if report.get("ok", false):
		var loaded: Dictionary = report.get("loaded", {})
		print("[ContentLoader] 配置装载完成：城市 %d 座，数值段 %d 个，职业 %d 个，种族 %d 个，预置路线 %d 条，技能 %d 个，物品 %d 件，词缀 %d 条，天赋 %d 个，出身 %d 个" % [
			_city_configs.size(), _balance.size(), int(loaded.get("professions", 0)),
			int(loaded.get("races", 0)), _trade_routes.size(),
			int(loaded.get("skills", 0)), int(loaded.get("items", 0)),
			int(loaded.get("affixes", 0)),
			int(loaded.get("talents", 0)), int(loaded.get("backgrounds", 0)),
		])
	else:
		for err in _errors:
			push_error("[ContentLoader] " + err)
		push_error("[ContentLoader] 配置装载失败，共 %d 项错误" % _errors.size())


## 装载全部配置。返回 {ok, loaded, errors, warnings}。
func load_all() -> Dictionary:
	_errors.clear()
	_warnings.clear()
	_city_configs.clear()
	_balance.clear()
	_professions = {}
	_name_pools = {}
	_trade_routes.clear()
	_skills = {}
	_items = {}
	_talents = {}
	_backgrounds = {}
	_quests = {}
	_events = {}
	_affixes = {}
	_loaded = false

	# 先读 balance：城市校验要用到世界网格尺寸与六维范围
	_balance = _read_json(BALANCE_FILE, "数值配置")
	if not _balance.is_empty():
		_validate_balance()
	else:
		_errors.append("数值配置为空或读取失败，后续校验无法进行")

	var cities_root: Dictionary = _read_json(CITY_FILE, "城市配置")
	if not cities_root.is_empty():
		_validate_cities(cities_root)
	else:
		_errors.append("城市配置为空或读取失败")

	# 职业与姓名池：先于预置路线校验，后者要用到城市列表
	var profession_root: Dictionary = _read_json(PROFESSION_FILE, "职业配置")
	if not profession_root.is_empty():
		_validate_professions(profession_root)
	else:
		_errors.append("职业配置为空或读取失败")

	var name_root: Dictionary = _read_json(NAME_POOL_FILE, "姓名池配置")
	if not name_root.is_empty():
		_validate_name_pools(name_root)
	else:
		_errors.append("姓名池配置为空或读取失败")

	var route_root: Dictionary = _read_json(TRADE_ROUTE_FILE, "贸易路线配置")
	if not route_root.is_empty():
		_validate_trade_routes(route_root)
	else:
		_errors.append("贸易路线配置为空或读取失败")

	# 技能与物品：先于出身校验，出身的初始物品与初始技能要引用它们
	var skill_root: Dictionary = _read_json(SKILL_FILE, "技能配置")
	if not skill_root.is_empty():
		_validate_skills(skill_root)
	else:
		_errors.append("技能配置为空或读取失败")

	var item_root: Dictionary = _read_json(ITEM_FILE, "物品配置")
	if not item_root.is_empty():
		_validate_items(item_root)
	else:
		_errors.append("物品配置为空或读取失败")

	var affix_root: Dictionary = _read_json(AFFIX_FILE, "词缀配置")
	if not affix_root.is_empty():
		_validate_affixes(affix_root)
	else:
		_errors.append("词缀配置为空或读取失败")

	var talent_root: Dictionary = _read_json(TALENT_FILE, "天赋配置")
	if not talent_root.is_empty():
		_validate_talents(talent_root)
	else:
		_errors.append("天赋配置为空或读取失败")

	var background_root: Dictionary = _read_json(BACKGROUND_FILE, "出身配置")
	if not background_root.is_empty():
		_validate_backgrounds(background_root)
	else:
		_errors.append("出身配置为空或读取失败")

	var quest_root: Dictionary = _read_json(QUEST_FILE, "委托任务配置")
	if not quest_root.is_empty():
		_validate_quests(quest_root)
	else:
		_errors.append("委托任务配置为空或读取失败")

	var event_root: Dictionary = _read_json(EVENT_FILE, "城市事件配置")
	if not event_root.is_empty():
		_validate_events(event_root)
	else:
		_errors.append("城市事件配置为空或读取失败")

	_loaded = _errors.is_empty()
	return {
		"ok": _loaded,
		"loaded": {
			"cities": _city_configs.size(),
			"balanceSections": _balance.size(),
			"professions": _professions.get("professions", []).size(),
			"races": _name_pools.get("races", []).size(),
			"presetRoutes": _trade_routes.size(),
			"skills": _skills.get("skills", []).size(),
			"items": _items.get("items", []).size(),
			"talents": _talents.get("talents", []).size(),
			"backgrounds": _backgrounds.get("backgrounds", []).size(),
			"questTypes": _quests.get("quests", []).size(),
			"events": _events.get("events", []).size(),
			"affixes": _affixes.get("affixes", []).size(),
		},
		"errors": _errors.duplicate(),
		"warnings": _warnings.duplicate(),
	}


func is_loaded() -> bool:
	return _loaded


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_warnings() -> Array[String]:
	return _warnings.duplicate()


func get_balance() -> Dictionary:
	return _balance


## 读一个数值段，如 "time"、"trade"、"npc"。段不存在时返回空字典。
func get_balance_section(section: String) -> Dictionary:
	return _balance.get(section, {})


func get_city_configs() -> Array:
	return _city_configs


func get_city_config(city_id: String) -> Dictionary:
	for cfg in _city_configs:
		if str(cfg.get("cityId", "")) == city_id:
			return cfg
	return {}


func get_profession_config() -> Dictionary:
	return _professions


func get_name_pool_config() -> Dictionary:
	return _name_pools


func get_preset_routes() -> Array:
	return _trade_routes


func get_skill_config() -> Dictionary:
	return _skills


func get_skills() -> Array:
	return _skills.get("skills", [])


func get_skill(skill_id: String) -> Dictionary:
	for entry in get_skills():
		if str(entry.get("skillId", "")) == skill_id:
			return entry
	return {}


func get_item_config() -> Dictionary:
	return _items


func get_items() -> Array:
	return _items.get("items", [])


func get_item(template_id: String) -> Dictionary:
	for entry in get_items():
		if str(entry.get("templateId", "")) == template_id:
			return entry
	return {}


## 词缀表（《技术设计文档》3.3 节 ITEM_INSTANCE 的 Modifier[]）。
## 表中的书写次序就是抽词缀时的池中次序，因此配置里调整顺序会改变
## 同一件货摇出什么词缀——顺序是内容的一部分，不是排版。
func get_affix_config() -> Dictionary:
	return _affixes


func get_affixes() -> Array:
	return _affixes.get("affixes", [])


func get_affix(affix_id: String) -> Dictionary:
	for entry in get_affixes():
		if str(entry.get("affixId", "")) == affix_id:
			return entry
	return {}


func get_talent_config() -> Dictionary:
	return _talents


func get_talents() -> Array:
	return _talents.get("talents", [])


func get_talent(talent_id: String) -> Dictionary:
	for entry in get_talents():
		if str(entry.get("talentId", "")) == talent_id:
			return entry
	return {}


func get_background_config() -> Dictionary:
	return _backgrounds


func get_backgrounds() -> Array:
	return _backgrounds.get("backgrounds", [])


func get_background(background_id: String) -> Dictionary:
	for entry in get_backgrounds():
		if str(entry.get("backgroundId", "")) == background_id:
			return entry
	return {}


func get_quest_config() -> Dictionary:
	return _quests


func get_quest_tiers() -> Array:
	return _quests.get("tiers", [])


func get_quest_tier(tier_id: String) -> Dictionary:
	for entry in get_quest_tiers():
		if str(entry.get("tierId", "")) == tier_id:
			return entry
	return {}


func get_quest_types() -> Array:
	return _quests.get("quests", [])


func get_quest_type(quest_type_id: String) -> Dictionary:
	for entry in get_quest_types():
		if str(entry.get("questTypeId", "")) == quest_type_id:
			return entry
	return {}


## 城市事件配置（《城市事件剧本》EV-01~08、《世界模拟量化规则》4 章、
## 《数值框架》10 章的触发阈值）。
##
## 校验的重点和委托不同：事件的后果分三个时间（触发冲击、每月持续、了结分支），
## 而这三处填错的表现都很安静——触发阈值写反了事件永远不来；drain 的 delta 写成 0
## 会让封港"封了却不少一点"；分支的 changes 维度拼错会让交付悄无声息地不生效。
## 还有一处最隐蔽：带战斗的分支若少了 victory 或 defeat，玩家打完那一仗会拿到一个
## 空的结局。
func _validate_events(root: Dictionary) -> void:
	var dim_min: int = int(_balance.get("cityDimension", {}).get("min", DEFAULT_DIM_MIN))
	var dim_max: int = int(_balance.get("cityDimension", {}).get("max", DEFAULT_DIM_MAX))

	var list: Variant = root.get("events", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("城市事件配置缺少非空的 events 数组")
		return

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "events[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("城市事件配置 %s 必须是对象" % path)
			continue
		var config: Dictionary = entry

		var template_id: String = str(config.get("templateId", ""))
		if template_id.is_empty():
			_errors.append("城市事件配置缺少字段：%s.templateId" % path)
		elif seen.has(template_id):
			_errors.append("城市事件配置 templateId 重复：%s" % template_id)
		else:
			seen[template_id] = true
			path = "events[%s]" % template_id

		if str(config.get("displayName", "")).is_empty():
			_errors.append("城市事件配置缺少字段：%s.displayName" % path)
		if str(config.get("summary", "")).is_empty():
			_errors.append("城市事件配置缺少字段：%s.summary" % path)

		var city_id: String = str(config.get("cityId", ""))
		if city_id.is_empty():
			_errors.append("城市事件配置缺少字段：%s.cityId" % path)
		elif get_city_config(city_id).is_empty():
			_errors.append("城市事件配置指向不存在的城市：%s.cityId = %s" % [path, city_id])

		var dialogue: Variant = config.get("dialogue", null)
		if not (dialogue is Array) or (dialogue as Array).is_empty():
			_errors.append("城市事件配置缺少非空的 dialogue：%s" % path)

		_validate_event_trigger(config, path, dim_min, dim_max)
		_validate_event_blockade(config, path)
		_validate_event_branches(config, path, city_id)
		_validate_event_combat(config, path)

	_events = root


## 触发条件。维度名与阈值都查——"城里的财富 ≥ 75"这句话里，两个词各自都可能写错。
func _validate_event_trigger(
	config: Dictionary, path: String, dim_min: int, dim_max: int
) -> void:
	var trigger: Variant = config.get("trigger", null)
	if not (trigger is Dictionary):
		_errors.append("城市事件配置缺少 trigger：%s" % path)
		return
	var spec: Dictionary = trigger
	var dimension: String = str(spec.get("dimension", ""))
	if not City.ALL_DIMENSIONS.has(dimension):
		_errors.append("城市事件触发维度非法：%s.trigger.dimension = %s（应为 %s 之一）" % [
			path, dimension, ", ".join(PackedStringArray(City.ALL_DIMENSIONS))
		])
	var at_least: int = int(spec.get("atLeast", -1))
	if at_least < dim_min or at_least > dim_max:
		_errors.append("城市事件触发阈值越界（%d-%d）：%s.trigger.atLeast = %d" % [
			dim_min, dim_max, path, at_least
		])
	for key in ["smellSmugglingRoutes", "smellCombatFlags"]:
		if int(spec.get(key, 0)) < 0:
			_errors.append("城市事件的血腥味条件不能为负：%s.trigger.%s" % [path, key])


## 封港段：瞬时冲击、是否断航、每月的持续代价。
func _validate_event_blockade(config: Dictionary, path: String) -> void:
	var raw: Variant = config.get("blockade", null)
	if not (raw is Dictionary):
		_errors.append("城市事件配置缺少 blockade：%s" % path)
		return
	var blockade: Dictionary = raw
	if str(blockade.get("text", "")).is_empty():
		_errors.append("城市事件配置缺少冲击文案：%s.blockade.text" % path)
	if not (blockade.get("haltRoutes", false) is bool):
		_errors.append("城市事件配置 haltRoutes 必须是布尔：%s.blockade.haltRoutes" % path)
	if not blockade.has("changes"):
		_errors.append("城市事件配置缺少瞬时冲击：%s.blockade.changes" % path)
	else:
		_validate_event_changes(blockade["changes"], "%s.blockade.changes" % path)
	var drain: Variant = blockade.get("drainPerMonth", null)
	if drain == null:
		return
	if not (drain is Dictionary):
		_errors.append("城市事件的每月持续代价必须是对象：%s.blockade.drainPerMonth" % path)
		return
	var per_month: Dictionary = drain
	if not City.ALL_DIMENSIONS.has(str(per_month.get("dimension", ""))):
		_errors.append("城市事件持续代价的维度非法：%s.blockade.drainPerMonth.dimension = %s" % [
			path, str(per_month.get("dimension", ""))
		])
	if int(per_month.get("delta", 0)) == 0:
		# 0 就是"封着港口却一点都不少"，玩家永远等不到"该管一管了"的信号
		_errors.append("城市事件持续代价的 delta 不能为 0：%s.blockade.drainPerMonth.delta" % path)


## 三维度增量表：键必须是合法的维度，值不能是 0（0 会被 StateChange 拒绝，
## 而配置里看不出任何异常）。
func _validate_event_changes(raw: Variant, path: String) -> void:
	if not (raw is Dictionary):
		_errors.append("城市事件的增量必须是对象（维度 → 整数）：%s" % path)
		return
	for key in (raw as Dictionary):
		if not City.ALL_DIMENSIONS.has(str(key)):
			_errors.append("城市事件的增量维度非法：%s.%s" % [path, str(key)])
		elif int((raw as Dictionary)[key]) == 0:
			_errors.append("城市事件的增量不能为 0：%s.%s" % [path, str(key)])


## 分支。三条分支各给一套后果；带战斗的那条不直接给后果，而是给胜负两套。
func _validate_event_branches(config: Dictionary, path: String, city_id: String) -> void:
	var branches: Variant = config.get("branches", null)
	if not (branches is Array) or (branches as Array).is_empty():
		_errors.append("城市事件配置缺少非空的 branches：%s" % path)
		return
	var seen: Dictionary = {}
	for i in range((branches as Array).size()):
		var bpath: String = "%s.branches[%d]" % [path, i]
		var entry: Variant = (branches as Array)[i]
		if not (entry is Dictionary):
			_errors.append("城市事件分支 %s 必须是对象" % bpath)
			continue
		var branch: Dictionary = entry
		var branch_id: String = str(branch.get("branchId", ""))
		if branch_id.is_empty():
			_errors.append("城市事件分支缺少字段：%s.branchId" % bpath)
		elif seen.has(branch_id):
			_errors.append("城市事件分支重复：%s.%s" % [path, branch_id])
		else:
			seen[branch_id] = true
			bpath = "%s.branches[%s]" % [path, branch_id]
		if str(branch.get("label", "")).is_empty():
			_errors.append("城市事件分支缺少选项文字：%s.label" % bpath)

		if bool(branch.get("isCombat", false)):
			_validate_event_outcomes(branch, bpath, city_id)
			continue
		if not branch.has("changes"):
			_errors.append("城市事件分支缺少 changes：%s" % bpath)
		else:
			_validate_event_changes(branch["changes"], "%s.changes" % bpath)
		_validate_event_rewards(branch, bpath, city_id)


## 战斗分支的胜负两套后果。缺任何一套的后果是"玩家打完那一仗，世界什么都没发生"。
func _validate_event_outcomes(branch: Dictionary, path: String, city_id: String) -> void:
	var raw: Variant = branch.get("outcomes", null)
	if not (raw is Dictionary):
		_errors.append("城市事件战斗分支缺少 outcomes：%s" % path)
		return
	var outcomes: Dictionary = raw
	for key in [EventSystem.OUTCOME_VICTORY, EventSystem.OUTCOME_DEFEAT]:
		var entry: Variant = outcomes.get(key, null)
		if not (entry is Dictionary):
			_errors.append("城市事件战斗分支缺少 %s 结局：%s.outcomes" % [key, path])
			continue
		var outcome_path: String = "%s.outcomes.%s" % [path, key]
		if str((entry as Dictionary).get("label", "")).is_empty():
			_errors.append("城市事件结局缺少文字：%s.label" % outcome_path)
		if (entry as Dictionary).has("changes"):
			_validate_event_changes((entry as Dictionary)["changes"], "%s.changes" % outcome_path)
		_validate_event_rewards(entry, outcome_path, city_id)


## 一套后果里的玩家侧奖励与世界侧解锁。
func _validate_event_rewards(spec: Dictionary, path: String, city_id: String) -> void:
	if spec.has("flags") and not (spec["flags"] is Array):
		_errors.append("城市事件后果的 flags 必须是数组：%s.flags" % path)
	if spec.has("recurrence") and not (spec["recurrence"] is bool):
		_errors.append("城市事件后果的 recurrence 必须是布尔：%s.recurrence" % path)
	if spec.has("resolved") and not (spec["resolved"] is bool):
		_errors.append("城市事件后果的 resolved 必须是布尔：%s.resolved" % path)
	var unlock: Variant = spec.get("unlockRoute", null)
	if unlock == null:
		return
	if not (unlock is Dictionary):
		_errors.append("城市事件的 unlockRoute 必须是对象：%s.unlockRoute" % path)
		return
	var route: Dictionary = unlock
	var kind: String = str(route.get("kind", ""))
	if not TradeRoute.ALL_KINDS.has(kind):
		_errors.append("城市事件解锁的航线类型非法：%s.unlockRoute.kind = %s" % [path, kind])
	var other: String = str(route.get("otherCity", ""))
	if other.is_empty():
		_errors.append("城市事件解锁的航线缺少另一端：%s.unlockRoute.otherCity" % path)
	elif get_city_config(other).is_empty():
		_errors.append("城市事件解锁的航线指向不存在的城市：%s.unlockRoute.otherCity = %s" % [
			path, other
		])
	elif other == city_id:
		_errors.append("城市事件解锁的航线两端是同一座城市：%s.unlockRoute.otherCity" % path)


## 战斗段：对手的属性必须齐全，否则战斗开始的那一刻才会报"缺少维度"。
func _validate_event_combat(config: Dictionary, path: String) -> void:
	var raw: Variant = config.get("combat", null)
	if raw == null:
		return
	if not (raw is Dictionary):
		_errors.append("城市事件战斗段必须是对象：%s.combat" % path)
		return
	var combat: Dictionary = raw
	if str(combat.get("label", "")).is_empty():
		_errors.append("城市事件战斗段缺少选项文字：%s.combat.label" % path)
	var opponent: Variant = combat.get("opponent", null)
	if not (opponent is Dictionary):
		_errors.append("城市事件战斗段缺少对手：%s.combat.opponent" % path)
		return
	var unit: Dictionary = opponent
	if str(unit.get("name", "")).is_empty():
		_errors.append("城市事件战斗段缺少对手名字：%s.combat.opponent.name" % path)
	var attributes: Variant = unit.get("attributes", null)
	if not (attributes is Dictionary):
		_errors.append("城市事件战斗段缺少对手属性：%s.combat.opponent.attributes" % path)
	else:
		for attr in PlayerAvatar.ALL_ATTRIBUTES:
			if not (attributes as Dictionary).has(attr):
				_errors.append("城市事件对手属性缺少维度：%s.combat.opponent.attributes.%s" % [path, attr])
	if int(unit.get("hp", 0)) <= 0 or int(unit.get("maxHp", 0)) <= 0:
		_errors.append("城市事件对手的血量必须为正：%s.combat.opponent.hp / maxHp" % path)
	if int(unit.get("armor", 0)) < 0:
		_errors.append("城市事件对手的护甲不能为负：%s.combat.opponent.armor" % path)


## 城市事件配置（《城市事件剧本》EV-01~08 + 《世界模拟量化规则》4 章）。
func get_event_config() -> Dictionary:
	return _events


## 全部事件模板。EventSystem 的触发判定按它逐个过一遍。
func get_events() -> Array:
	return _events.get("events", [])


func get_event_template(template_id: String) -> Dictionary:
	for entry in get_events():
		if str(entry.get("templateId", "")) == template_id:
			return entry
	return {}


## 可玩种族（name_pools.json 里 playable 为 true 的）。M3.1 自由生成的可选范围。
func get_playable_races() -> Array:
	var out: Array = []
	for entry in _name_pools.get("races", []):
		if bool(entry.get("playable", false)):
			out.append(entry)
	return out


## 全部种族。
func get_races() -> Array:
	return _array_of(_name_pools.get("races", []))


## raceId -> 寿命。寿命只有这一处来源（《数值框架》2.2 节的种族表），
## 所以 Lifecycle 不在自己那边再抄一份表。
func race_lifespans() -> Dictionary:
	var out: Dictionary = {}
	for entry in get_races():
		out[str(entry.get("raceId", ""))] = int(entry.get("lifespan", 0))
	return out


func get_race(race_id: String) -> Dictionary:
	for entry in _name_pools.get("races", []):
		if str(entry.get("raceId", "")) == race_id:
			return entry
	return {}


## 校验一组存档引用是否都能在配置里找到（接口 I-28）。
##
## 不抛错而返回完整缺失清单：它同时服务启动期与读档两条路径，两处都需要
## 拿到全部问题再决定怎么提示，而不是在第一个缺失处中断。
func validate_save_refs(refs: Dictionary) -> Dictionary:
	var missing: Array = []
	for city_id in refs.get("cityIds", []):
		if get_city_config(str(city_id)).is_empty():
			missing.append({"kind": "city", "id": str(city_id)})
	for skill_id in refs.get("skillIds", []):
		if get_skill(str(skill_id)).is_empty():
			missing.append({"kind": "skill", "id": str(skill_id)})
	for template_id in refs.get("templateIds", []):
		if get_item(str(template_id)).is_empty():
			missing.append({"kind": "item", "id": str(template_id)})
	for talent_id in refs.get("talentIds", []):
		if get_talent(str(talent_id)).is_empty():
			missing.append({"kind": "talent", "id": str(talent_id)})
	var background_id: String = str(refs.get("backgroundId", ""))
	if not background_id.is_empty() and get_background(background_id).is_empty():
		missing.append({"kind": "background", "id": background_id})
	return {"ok": missing.is_empty(), "missing": missing}


# --- 内部实现 ---

## 取一个数组字段。配置里显式写 null 时 Dictionary.get 的缺省值不生效，而类型不符时
## 直接赋给 Array 变量会抛错——所以在边界处统一转一次，缺省与判型合成一步。
static func _array_of(value: Variant) -> Array:
	return value if value is Array else []


func _read_json(file_name: String, label: String) -> Dictionary:
	var path: String = DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		_errors.append("%s缺少文件：%s" % [label, path])
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("%s无法打开：%s（错误码 %d）" % [label, path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parser := JSON.new()
	var err: int = parser.parse(text)
	if err != OK:
		_errors.append("%s JSON 语法错误：%s 第 %d 行 —— %s" % [
			label, path, parser.get_error_line(), parser.get_error_message()
		])
		return {}
	if not (parser.data is Dictionary):
		_errors.append("%s根节点必须是对象：%s" % [label, path])
		return {}
	return parser.data


func _validate_balance() -> void:
	var required_sections: Dictionary = {
		"time": ["ticksPerDay", "daysPerMonth", "monthsPerYear"],
		"worldGrid": ["width", "height"],
		"cityDimension": ["min", "max"],
		"cityEvolution": [
			"birthRate", "baseDeathRate", "deathSecurityFactor",
			"migrationWealthWeight", "migrationSecurityWeight",
			"industryOutput", "consumptionRate",
			"constructionRate", "developmentDecay",
			"governanceWealthWeight", "governanceFactionWeight", "crimeWeight",
			"cultureInvestment", "cultureMisfortune",
		],
		"trade": [
			"regularMaxDistance", "regularBonusMaxDistance", "regularBonusMinDevelopment",
			"regularMinSecurity", "regularMaxPerCity", "regularMultiRouteMinDevelopment",
			"smugglingMaxDistance", "smugglingMaxPerCity",
			"smugglingConfiscationSecurityFactor",
		],
		"economy": [
			"shortageAt", "surplusAt",
			"shortageFactorAtZero", "shortageFactorAtEdge",
			"surplusFactorAtEdge", "surplusFactorAtMax",
			"securityFactorScale",
			"reputationRespectThreshold", "reputationRespectPriceFactor",
			"reputationWaryThreshold", "reputationWaryPriceFactor", "reputationRefuseAt",
			"sellPriceRatio",
			"blackMarketBuyFactor", "blackMarketSellFactor", "blackMarketRarityBonus",
		],
		# 装备段全是列表与名字表，没有数字项——这里只要求它存在，
		# 内容由 _validate_equipment 逐项校验
		"equipment": [],
		# 同理：这一段的主体是两张键名即规则的表（词缀条数、词缀折价），
		# 数字项只有下面三个，其余由 _validate_item_instance 校验
		"itemInstance": ["durabilityMax", "enhancementMax", "enhancementPerLevelRatio"],
		"npc": [
			"simulatedPerPopulationPoint", "simulatedCap", "familyMinSize", "familyMaxSize",
			"ageMeanLifespanRatio", "ageJitterHalfRange",
			"colleagueProbability", "friendProbability", "enemySecurityFactor",
			"kinRelationMin", "kinRelationMax",
			"colleagueRelationMin", "colleagueRelationMax",
			"friendRelationMin", "friendRelationMax",
			"enemyRelationMin", "enemyRelationMax",
			"relationSampleLimit",
			"attractionWealthWeight", "attractionSecurityWeight", "attractionCultureWeight",
			"migrationThreshold", "migrationMonthlyCapRatio", "elderAgeMargin",
		],
		"reincarnation": [
		"baseRetention", "retentionPerSoul", "retentionCap", "attributeInheritFactor",
		"sleepMonthsBaseYears", "sleepMonthsPerSoul", "sleepMonthsJitterYears",
		"sleepMonthsMinYears", "sleepMonthsMaxYears",
		"hostMinAge", "hostMaxAgeMargin", "hostLuckWeightFactor",
		"hostDebtChancePerMille", "hostDebtMinCopper", "hostDebtMaxCopper",
	],
	# 寿命与年龄（D-58）。主体是两个系数与两条界线，逐个校验放在 _validate_lifecycle
	"lifecycle": [
		"soulFactorBase", "soulFactorPerPoint", "soulFactorMin", "soulFactorMax",
		"elderRatio", "fallbackLifespan", "recordSkillCount", "recordReputationCount",
	],
	"characterCreation": [
		"baseAttribute", "allocatablePoints", "creationMaxAttribute",
		"attributeMin", "attributeMax",
	],
	"derivedStats": [
		"hpBase", "hpPerConstitution", "hpPerPowerLevel",
		"mpBase", "mpPerIntelligence", "mpPerSoul",
		"spBase", "spPerConstitution", "spPerStrength",
		"powerLevelAttributeSumBase", "powerLevelAttributeDivisor",
		"powerLevelSkillCount", "powerLevelSkillDivisor",
	],
	"combat": [
		"apBase", "dexPerAp", "tuBase", "tuPerDex",
		"hitBaseBp", "hitPerSkillBp", "hitPerPerceptionBp", "hitPerDexBp",
		"dodgePerDexBp", "hitMinBp", "hitMaxBp",
		"aimHeadHitPenaltyBp", "aimTorsoHitPenaltyBp", "aimLimbHitPenaltyBp",
		"aimHeadDamageFactor", "aimTorsoDamageFactor", "aimLimbDamageFactor",
		"critBaseBp", "critPerDexBp", "critDamageBaseBp",
		"skillPowerBase", "skillPowerPerLevel",
		"strengthDamageFactor", "intelligenceDamageFactor",
		"soulDamageFactor", "soulDamageExtraFactor", "minDamage",
		"stunChancePerMille", "maxInjurySeverity",
		"armHitPenaltyBpPerSeverity", "legMoveCostPerSeverity", "healDaysPerSeverity",
		"lootBaseChanceBp", "lootPerThreatLevelBp", "lootLuckDivisor",
		"lootChanceMinBp", "lootChanceMaxBp", "luckPerRarityStep",
	],
}
	for section in required_sections:
		if not _balance.has(section):
			_errors.append("数值配置缺少段：%s" % section)
			continue
		var block: Dictionary = _balance[section]
		for key in required_sections[section]:
			if not block.has(key):
				_errors.append("数值配置缺少字段：%s.%s" % [section, key])
			elif not (block[key] is float or block[key] is int):
				_errors.append("数值配置字段必须是数字：%s.%s" % [section, key])

	# 时间刻度的取值必须为正，否则 ClockCore 会退化
	var time_block: Dictionary = _balance.get("time", {})
	for key in ["ticksPerDay", "daysPerMonth", "monthsPerYear"]:
		if int(time_block.get(key, 0)) <= 0:
			_errors.append("数值配置字段必须为正整数：time.%s" % key)

	# 六维范围必须 min < max，否则钳制无意义
	var dim: Dictionary = _balance.get("cityDimension", {})
	if int(dim.get("min", 0)) >= int(dim.get("max", 0)):
		_errors.append("数值配置 cityDimension.min 必须小于 max")

	# 创建期上限必须高于起点，否则「可分配点数」永远用不掉
	var creation: Dictionary = _balance.get("characterCreation", {})
	if int(creation.get("creationMaxAttribute", 0)) <= int(creation.get("baseAttribute", 0)):
		_errors.append("数值配置 characterCreation.creationMaxAttribute 必须大于 baseAttribute")
	if int(creation.get("attributeMin", 0)) >= int(creation.get("attributeMax", 0)):
		_errors.append("数值配置 characterCreation.attributeMin 必须小于 attributeMax")
	if int(creation.get("allocatablePoints", 0)) < 0:
		_errors.append("数值配置 characterCreation.allocatablePoints 不能为负")

	# 沉眠年数的上下限必须成序，否则钳制会把结果压成一个常数
	var reinc: Dictionary = _balance.get("reincarnation", {})
	if int(reinc.get("sleepMonthsMinYears", 0)) > int(reinc.get("sleepMonthsMaxYears", 0)):
		_errors.append("数值配置 reincarnation.sleepMonthsMinYears 不能大于 sleepMonthsMaxYears")

	_validate_economy(_balance.get("economy", {}))
	_validate_equipment(_balance.get("equipment", {}))
	_validate_item_instance(_balance.get("itemInstance", {}))
	_validate_lifecycle(_balance.get("lifecycle", {}))


## 寿命与年龄（D-58）。这里查的都是"填错了也不会崩、但会让人物在一开局就寿终"
## 的地方：系数区间的上下限反了，钳制会把所有人压成同一个寿命；暮年比例不在
## 0–1 之间，暮年提示要么永远不出现、要么从出生那天起就挂着；种族的 lifespan
## 缺失或非正，那个人一出生就到期。
func _validate_lifecycle(root: Dictionary) -> void:
	if root.is_empty():
		return
	if float(root.get("soulFactorPerPoint", 0.0)) < 0.0:
		_errors.append("数值配置 lifecycle.soulFactorPerPoint 不能为负")
	var factor_min: float = float(root.get("soulFactorMin", 0.0))
	var factor_max: float = float(root.get("soulFactorMax", 0.0))
	if factor_min <= 0.0:
		_errors.append("数值配置 lifecycle.soulFactorMin 必须为正")
	if factor_min > factor_max:
		_errors.append("数值配置 lifecycle.soulFactorMin 不能大于 soulFactorMax")
	var elder: float = float(root.get("elderRatio", 0.0))
	if elder <= 0.0 or elder >= 1.0:
		_errors.append("数值配置 lifecycle.elderRatio 必须落在 0 与 1 之间（暮年线）")
	if int(root.get("fallbackLifespan", 0)) <= 0:
		_errors.append("数值配置 lifecycle.fallbackLifespan 必须为正")
	for key in ["recordSkillCount", "recordReputationCount"]:
		if int(root.get(key, 0)) < 1:
			_errors.append("数值配置 lifecycle.%s 至少为 1" % key)

	# 种族的寿命是这张表的唯一来源，缺一个人的那份就等于"一出生就寿终"
	for race in _name_pools.get("races", []):
		var race_id: String = str(race.get("raceId", ""))
		if int(race.get("lifespan", 0)) <= 0:
			_errors.append("姓名池配置的种族寿命必须为正：%s.lifespan（raceId=%s）" % [race_id, race_id])


## 物品实例的规则（D-54 ~ D-57）。这里查的都是"填错了也能跑、但玩家体验会歪掉"
## 的地方：条数表漏一个稀有度，那一档的货永远没有词缀；成功率与费用表的长度
## 与强化上限不一致，+4 之后按下回车会取到不存在的下标（那时才炸，且炸在游戏里）；
## 词缀折价漏一个目标，带那条词缀的货就按 0 铜折价，买进来再卖出去白亏。
func _validate_item_instance(root: Dictionary) -> void:
	if root.is_empty():
		return
	if int(root.get("durabilityMax", 0)) <= 0:
		_errors.append("数值配置 itemInstance.durabilityMax 必须为正")

	var enhance_max: int = int(root.get("enhancementMax", 0))
	if enhance_max < 0:
		_errors.append("数值配置 itemInstance.enhancementMax 不能为负")
	if float(root.get("enhancementPerLevelRatio", 0.0)) <= 0.0:
		_errors.append("数值配置 itemInstance.enhancementPerLevelRatio 必须为正（每级加多少）")

	var counts: Variant = root.get("affixCountByRarity", null)
	if not (counts is Dictionary):
		_errors.append("数值配置 itemInstance.affixCountByRarity 必须是对象")
	else:
		for rarity in ITEM_RARITIES:
			if not (counts as Dictionary).has(rarity):
				_errors.append("数值配置的词缀条数缺少稀有度：itemInstance.affixCountByRarity.%s" % rarity)
			elif int((counts as Dictionary)[rarity]) < 0:
				_errors.append("数值配置的词缀条数不能为负：itemInstance.affixCountByRarity.%s" % rarity)

	var per_point: Variant = root.get("affixPricePerPoint", null)
	if not (per_point is Dictionary):
		_errors.append("数值配置 itemInstance.affixPricePerPoint 必须是对象")
	else:
		for target in AFFIX_TARGETS:
			if not (per_point as Dictionary).has(target):
				_errors.append("数值配置的词缀折价缺少目标：itemInstance.affixPricePerPoint.%s" % target)
			elif int((per_point as Dictionary)[target]) <= 0:
				_errors.append("数值配置的词缀折价必须为正：itemInstance.affixPricePerPoint.%s" % target)

	# 两张按等级取值的表，长度必须正好等于强化上限：短了会在高等级取到越界，
	# 长了则意味着配置里写了永远用不到的一档
	for key in ["enhancementChanceBp", "enhancementCostRatio"]:
		var table: Array = _array_of(root.get(key, null))
		if table.size() != enhance_max:
			_errors.append("数值配置 %s 的项数（%d）必须等于 enhancementMax（%d）" % [
				"itemInstance." + key, table.size(), enhance_max
			])
		for value in table:
			if not (value is int or value is float) or float(value) <= 0.0:
				_errors.append("数值配置 %s 的每一项都必须为正数" % ("itemInstance." + key))
				break
	var chances: Array = _array_of(root.get("enhancementChanceBp", null))
	for value in chances:
		if int(value) > 10000:
			_errors.append("数值配置 itemInstance.enhancementChanceBp 的概率不能超过 10000 基点")
			break


## 词缀配置（D-54）。池子是按类别与目标挑的，所以两处拼错都会静默：
## categories 写了未知类别 → 这条词缀永远不会被摇到；target 写了未知目标 →
## 它加在一个没人读的字段上，玩家只看到"（看不出效果）"。
func _validate_affixes(root: Dictionary) -> void:
	var list: Variant = root.get("affixes", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("词缀配置缺少非空的 affixes 数组")
		return

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "affixes[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("词缀配置 %s 必须是对象" % path)
			continue
		var affix: Dictionary = entry

		var affix_id: String = str(affix.get("affixId", ""))
		if affix_id.is_empty():
			_errors.append("词缀配置缺少字段：%s.affixId" % path)
		elif seen.has(affix_id):
			_errors.append("词缀配置 affixId 重复：%s" % affix_id)
		else:
			seen[affix_id] = true
			path = "affixes[%s]" % affix_id

		if str(affix.get("displayName", "")).is_empty():
			_errors.append("词缀配置缺少字段：%s.displayName" % path)

		var target: String = str(affix.get("target", ""))
		if not AFFIX_TARGETS.has(target):
			_errors.append("词缀配置的 target 非法：%s.target = %s（应为 %s 之一）" % [
				path, target, ", ".join(PackedStringArray(AFFIX_TARGETS))
			])

		var min_value: int = int(affix.get("minValue", 0))
		var max_value: int = int(affix.get("maxValue", 0))
		if min_value <= 0:
			_errors.append("词缀配置的数值必须为正：%s.minValue = %d" % [path, min_value])
		if max_value < min_value:
			_errors.append("词缀配置的数值区间反了：%s.maxValue（%d）小于 minValue（%d）" % [
				path, max_value, min_value
			])

		var categories: Array = _array_of(affix.get("categories", null))
		if categories.is_empty():
			_errors.append("词缀配置缺少非空的 categories：%s" % path)
			continue
		for category in categories:
			if not ITEM_EQUIP_CATEGORIES.has(str(category)):
				_errors.append("词缀配置的类别非法：%s.categories 含 %s（应为 %s 之一）" % [
					path, str(category), ", ".join(PackedStringArray(ITEM_EQUIP_CATEGORIES))
				])
	# 武器或防具的池子都不能空：空了的话那一类的货永远摇不出词缀，
	# 而"没有词缀"和"白板货"在界面上长得一模一样
	_affixes = root
	for category in ITEM_EQUIP_CATEGORIES:
		if affixes_for(str(category)).is_empty():
			_errors.append("词缀配置没有任何适用于 %s 的词缀，该类装备永远拿不到词缀" % str(category))


## 某一类装备可用的词缀池，按配置里的书写次序。
func affixes_for(category: String) -> Array:
	var out: Array = []
	for entry in get_affixes():
		if not (entry is Dictionary):
			continue
		if _array_of((entry as Dictionary).get("categories", null)).has(category):
			out.append(entry)
	return out


## 装备槽（D-50）。校验的重点是两张表内部自洽：槽位清单是"界面画几行、什么算合法
## 槽位"的唯一来源，两张表任一处拼错，表现都是"某件装备穿不上"或"某个槽永远空着"，
## 而配置里看不出任何异常。
func _validate_equipment(root: Dictionary) -> void:
	if root.is_empty():
		return
	var slots: Array = _array_of(root.get("slots", null))
	if slots.is_empty():
		_errors.append("数值配置 equipment.slots 必须是非空数组")
		return
	var seen: Dictionary = {}
	for slot in slots:
		var name: String = str(slot)
		if name.is_empty():
			_errors.append("数值配置 equipment.slots 含空槽位名")
			continue
		if seen.has(name):
			_errors.append("数值配置 equipment.slots 槽位重复：%s" % name)
		seen[name] = true

	var labels: Variant = root.get("slotLabels", null)
	if not (labels is Dictionary):
		_errors.append("数值配置 equipment.slotLabels 必须是对象")
	else:
		for slot in slots:
			if str((labels as Dictionary).get(str(slot), "")).is_empty():
				_errors.append("数值配置 equipment.slotLabels 缺少槽位：%s" % str(slot))

	var two_handed: Array = _array_of(root.get("twoHandedSlots", null))
	if two_handed.is_empty():
		_errors.append("数值配置 equipment.twoHandedSlots 必须是非空数组")
		return
	for slot in two_handed:
		if not seen.has(str(slot)):
			_errors.append("数值配置 equipment.twoHandedSlots 含未知槽位：%s" % str(slot))


## 买卖的价格规则（《数值框架》9.3）。这一段里有两张"键名也是规则"的表
## （哪一类商品看哪一维、哪个稀有度要多少发展度），键名拼错的后果是静默的：
## 那一类商品的供需会悄悄退化成缺省维度，或者某个稀有度永远上不了架。
func _validate_economy(root: Dictionary) -> void:
	if root.is_empty():
		return
	var categories: Dictionary = root.get("supplyDimensionByCategory", {})
	if not (categories is Dictionary):
		_errors.append("数值配置 economy.supplyDimensionByCategory 必须是对象")
	else:
		for key in (categories as Dictionary):
			if not ITEM_CATEGORIES.has(str(key)):
				_errors.append("数值配置的供需映射用了未知物品类别：economy.supplyDimensionByCategory.%s" % str(key))
			var dimension: String = str((categories as Dictionary)[key])
			if not City.ALL_DIMENSIONS.has(dimension):
				_errors.append("数值配置的供需映射维度非法：economy.supplyDimensionByCategory.%s = %s" % [
					str(key), dimension
				])
	if not City.ALL_DIMENSIONS.has(str(root.get("supplyDimensionFallback", ""))):
		_errors.append("数值配置的缺省供需维度非法：economy.supplyDimensionFallback = %s" % [
			str(root.get("supplyDimensionFallback", ""))
		])
	if int(root.get("shortageAt", 0)) >= int(root.get("surplusAt", 0)):
		_errors.append("数值配置 economy.shortageAt 必须小于 surplusAt（否则没有「正常」那一档）")

	# 稀有度门槛必须随稀有度单调不减：表里写反了，好货会比普通货更早出现在货架上
	var gates: Dictionary = root.get("rarityMinDevelopment", {})
	if not (gates is Dictionary):
		_errors.append("数值配置 economy.rarityMinDevelopment 必须是对象")
	else:
		var previous: int = -1
		for rarity in ITEM_RARITIES:
			if not (gates as Dictionary).has(rarity):
				_errors.append("数值配置的可得性门槛缺少稀有度：economy.rarityMinDevelopment.%s" % rarity)
				continue
			var value: int = int((gates as Dictionary)[rarity])
			if value < previous:
				_errors.append("数值配置的可得性门槛必须随稀有度递增：economy.rarityMinDevelopment.%s = %d" % [
					rarity, value
				])
			previous = value

	# 卖价比例与黑市系数都必须是正数；比例为 1 就成了"原地倒手套利"
	var sell_ratio: float = float(root.get("sellPriceRatio", 0.0))
	if sell_ratio <= 0.0 or sell_ratio > 1.0:
		_errors.append("数值配置 economy.sellPriceRatio 必须落在 (0, 1]（为 1 时同一座城里买卖不亏）")
	for key in ["blackMarketBuyFactor", "blackMarketSellFactor"]:
		if float(root.get(key, 0.0)) <= 0.0:
			_errors.append("数值配置 economy.%s 必须为正" % key)


func _validate_cities(root: Dictionary) -> void:
	if not root.has("cities"):
		_errors.append("城市配置缺少 cities 数组")
		return
	var list: Variant = root["cities"]
	if not (list is Array):
		_errors.append("城市配置 cities 必须是数组")
		return
	if list.is_empty():
		_errors.append("城市配置 cities 为空，至少需要一座城市")
		return

	var grid: Dictionary = _balance.get("worldGrid", {})
	var grid_w: int = int(grid.get("width", 120))
	var grid_h: int = int(grid.get("height", 120))
	var dim: Dictionary = _balance.get("cityDimension", {})
	var dim_min: int = int(dim.get("min", DEFAULT_DIM_MIN))
	var dim_max: int = int(dim.get("max", DEFAULT_DIM_MAX))

	var seen_ids: Dictionary = {}
	for i in range(list.size()):
		var path: String = "cities[%d]" % i
		var entry: Variant = list[i]
		if not (entry is Dictionary):
			_errors.append("城市配置 %s 必须是对象" % path)
			continue
		var city: Dictionary = entry

		var city_id: String = str(city.get("cityId", ""))
		if city_id.is_empty():
			_errors.append("城市配置缺少字段：%s.cityId" % path)
		elif seen_ids.has(city_id):
			_errors.append("城市配置 cityId 重复：%s" % city_id)
		else:
			seen_ids[city_id] = true

		if str(city.get("displayName", "")).is_empty():
			_errors.append("城市配置缺少字段：%s.displayName" % path)

		var cx: int = int(city.get("coordX", -1))
		var cy: int = int(city.get("coordY", -1))
		if cx < 0 or cx >= grid_w or cy < 0 or cy >= grid_h:
			_errors.append("城市配置坐标越界（网格 %d×%d）：%s 为 (%d, %d)" % [
				grid_w, grid_h, path, cx, cy
			])

		for dim_name in City.ALL_DIMENSIONS:
			if not city.has(dim_name):
				_errors.append("城市配置缺少维度：%s.%s" % [path, dim_name])
				continue
			var value: int = int(city[dim_name])
			if value < dim_min or value > dim_max:
				_errors.append("城市配置维度越界（允许 %d-%d）：%s.%s = %d" % [
					dim_min, dim_max, path, dim_name, value
				])

		# 地区溢价是物价公式的最后一个因子，缺了它整座城的物价会悄悄按 1.0 算
		if not city.has("pricePremium"):
			_errors.append("城市配置缺少字段：%s.pricePremium（《数值框架》9.3 的地区溢价）" % path)
		elif float(city["pricePremium"]) <= 0.0:
			_errors.append("城市配置的地区溢价必须为正：%s.pricePremium = %s" % [
				path, str(city["pricePremium"])
			])

		_city_configs.append(city)

	# 龙魂装备的产地（economy.dragonforgedCityId）必须真的存在，否则那一类货永远上不了架
	var forge_city: String = str(_balance.get("economy", {}).get("dragonforgedCityId", ""))
	if not forge_city.is_empty() and not seen_ids.has(forge_city):
		_errors.append("数值配置 economy.dragonforgedCityId 指向不存在的城市：%s" % forge_city)


func _validate_professions(root: Dictionary) -> void:
	var list: Variant = root.get("professions", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("职业配置缺少非空的 professions 数组")
		return

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "professions[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("职业配置 %s 必须是对象" % path)
			continue
		var profession: Dictionary = entry
		var profession_id: String = str(profession.get("professionId", ""))
		if profession_id.is_empty():
			_errors.append("职业配置缺少字段：%s.professionId" % path)
		elif seen.has(profession_id):
			_errors.append("职业配置 professionId 重复：%s" % profession_id)
		else:
			seen[profession_id] = true
		var category: String = str(profession.get("category", ""))
		if not PROFESSION_CATEGORIES.has(category):
			_errors.append("职业配置 category 非法：%s.category = %s（应为 %s 之一）" % [
				path, category, ", ".join(PackedStringArray(PROFESSION_CATEGORIES))
			])
		if not profession.has("baseWeight"):
			_errors.append("职业配置缺少字段：%s.baseWeight" % path)

	for city_id in root.get("citySpecialty", {}):
		var specialty: String = str(root["citySpecialty"][city_id])
		if not seen.has(specialty):
			_errors.append("城市特色职业指向不存在的职业：citySpecialty.%s = %s" % [city_id, specialty])

	for i in range(root.get("positionTemplates", []).size()):
		var position: Dictionary = root["positionTemplates"][i]
		var position_path: String = "positionTemplates[%d]" % i
		if str(position.get("positionId", "")).is_empty():
			_errors.append("职业配置缺少字段：%s.positionId" % position_path)
		var from_profession: String = str(position.get("fromProfession", ""))
		if not seen.has(from_profession):
			_errors.append("职位指向不存在的职业：%s.fromProfession = %s" % [
				position_path, from_profession
			])

	_professions = root


func _validate_name_pools(root: Dictionary) -> void:
	var list: Variant = root.get("races", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("姓名池配置缺少非空的 races 数组")
		return

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "races[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("姓名池配置 %s 必须是对象" % path)
			continue
		var race: Dictionary = entry
		var race_id: String = str(race.get("raceId", ""))
		if race_id.is_empty():
			_errors.append("姓名池配置缺少字段：%s.raceId" % path)
		elif seen.has(race_id):
			_errors.append("姓名池配置 raceId 重复：%s" % race_id)
		else:
			seen[race_id] = true
		if int(race.get("lifespan", 0)) <= 0:
			_errors.append("姓名池配置寿命必须为正：%s.lifespan" % path)
		if race.get("givenNames", []).is_empty():
			_errors.append("姓名池配置缺少名字：%s.givenNames" % path)
		if race.get("familyNames", []).is_empty():
			_errors.append("姓名池配置缺少姓氏：%s.familyNames" % path)

		# 属性偏移是 M3.1 自由生成的输入，缺一个维度就会让某个属性悄悄少加一次
		var offsets: Variant = race.get("attributeOffsets", null)
		if offsets == null:
			_errors.append("姓名池配置缺少字段：%s.attributeOffsets（M3.1 自由生成需要种族属性偏移）" % path)
		elif not (offsets is Dictionary):
			_errors.append("姓名池配置 attributeOffsets 必须是对象：%s" % path)
		else:
			for attr in PlayerAvatar.ALL_ATTRIBUTES:
				if not (offsets as Dictionary).has(attr):
					_errors.append("姓名池配置属性偏移缺少维度：%s.attributeOffsets.%s" % [path, attr])
				elif not ((offsets as Dictionary)[attr] is int or (offsets as Dictionary)[attr] is float):
					_errors.append("姓名池配置属性偏移必须是数字：%s.attributeOffsets.%s" % [path, attr])
		if race.has("playable") and not (race["playable"] is bool):
			_errors.append("姓名池配置 playable 必须是布尔：%s.playable" % path)

	var city_ids: Dictionary = {}
	for cfg in _city_configs:
		city_ids[str(cfg.get("cityId", ""))] = true
	for city_id in root.get("cityTendency", {}):
		var race_ref: String = str(root["cityTendency"][city_id])
		if not seen.has(race_ref):
			_errors.append("城市种族倾向指向不存在的种族：cityTendency.%s = %s" % [city_id, race_ref])
		if not city_ids.has(str(city_id)):
			_errors.append("城市种族倾向指向不存在的城市：cityTendency.%s" % city_id)

	_name_pools = root
	if _playable_race_count() == 0:
		_errors.append("姓名池配置没有任何 playable 为 true 的种族，M3.1 自由生成将无可选项")


func _playable_race_count() -> int:
	var count: int = 0
	for entry in _name_pools.get("races", []):
		if bool(entry.get("playable", false)):
			count += 1
	return count


## 预置贸易路线。这里不只是校验格式，还把 9.3 / 9.4 的判定条件原样跑一遍——
## 上游文档的 9.5 节正是在这一步被查出有 4 条路线不成立（技术设计文档第 9 章）。
## 与其等世界跑起来才发现某条路线建不上，不如在启动期就指名报出。
func _validate_trade_routes(root: Dictionary) -> void:
	var list: Variant = root.get("routes", null)
	if not (list is Array):
		_errors.append("贸易路线配置缺少 routes 数组")
		return

	var trade: Dictionary = _balance.get("trade", {})
	var regular_max: int = int(trade.get("regularMaxDistance", 40))
	var bonus_max: int = int(trade.get("regularBonusMaxDistance", 60))
	var bonus_min_dev: int = int(trade.get("regularBonusMinDevelopment", 60))
	var regular_min_sec: int = int(trade.get("regularMinSecurity", 40))
	var regular_cap: int = int(trade.get("regularMaxPerCity", 3))
	var multi_dev: int = int(trade.get("regularMultiRouteMinDevelopment", 60))
	var smuggle_max: int = int(trade.get("smugglingMaxDistance", 60))
	var smuggle_cap: int = int(trade.get("smugglingMaxPerCity", 2))

	var regular_count: Dictionary = {}
	var smuggling_count: Dictionary = {}
	var seen: Dictionary = {}

	for i in range((list as Array).size()):
		var path: String = "routes[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("贸易路线配置 %s 必须是对象" % path)
			continue
		var route: Dictionary = entry
		var city_a_id: String = str(route.get("cityA", ""))
		var city_b_id: String = str(route.get("cityB", ""))
		var kind: String = str(route.get("kind", ""))
		var a: Dictionary = get_city_config(city_a_id)
		var b: Dictionary = get_city_config(city_b_id)
		if a.is_empty():
			_errors.append("贸易路线配置指向不存在的城市：%s.cityA = %s" % [path, city_a_id])
			continue
		if b.is_empty():
			_errors.append("贸易路线配置指向不存在的城市：%s.cityB = %s" % [path, city_b_id])
			continue
		if not TradeRoute.ALL_KINDS.has(kind):
			_errors.append("贸易路线配置 kind 非法：%s.kind = %s" % [path, kind])
			continue

		var route_id: String = TradeRoute.route_id_for(city_a_id, city_b_id)
		if seen.has(route_id):
			_errors.append("贸易路线配置重复：%s 与 routes[%d]" % [path, seen[route_id]])
			continue
		seen[route_id] = i

		var dist: int = absi(int(a.get("coordX", 0)) - int(b.get("coordX", 0))) \
			+ absi(int(a.get("coordY", 0)) - int(b.get("coordY", 0)))
		var dev_a: int = int(a.get(City.DIM_DEVELOPMENT, 0))
		var dev_b: int = int(b.get(City.DIM_DEVELOPMENT, 0))
		var sec_a: int = int(a.get(City.DIM_SECURITY, 0))
		var sec_b: int = int(b.get(City.DIM_SECURITY, 0))

		if kind == TradeRoute.KIND_REGULAR:
			var limit: int = bonus_max if (dev_a >= bonus_min_dev and dev_b >= bonus_min_dev) else regular_max
			if dist > limit:
				_errors.append("预置正规商路不满足距离条件：%s 距离 %d > 上限 %d" % [path, dist, limit])
			if sec_a < regular_min_sec or sec_b < regular_min_sec:
				_errors.append("预置正规商路不满足治安门槛：%s 治安 %d/%d < %d" % [
					path, sec_a, sec_b, regular_min_sec
				])
			for city_id in [city_a_id, city_b_id]:
				var held: int = int(regular_count.get(city_id, 0))
				if held >= regular_cap:
					_errors.append("预置正规商路超过每城上限：%s 已建 %d 条（上限 %d）" % [
						path, held, regular_cap
					])
				elif held >= 1 and int(get_city_config(city_id).get(City.DIM_DEVELOPMENT, 0)) < multi_dev:
					_errors.append("预置正规商路违反发展度条件：%s 的 %s 已有路线，建第 2 条需发展度 ≥ %d" % [
						path, city_id, multi_dev
					])
				regular_count[city_id] = held + 1
		else:
			if dist > smuggle_max:
				_errors.append("预置走私航线不满足距离条件：%s 距离 %d > 上限 %d" % [
					path, dist, smuggle_max
				])
			if not (bool(a.get("hasBlackMarket", false)) or bool(b.get("hasBlackMarket", false))):
				_errors.append("预置走私航线缺少黑市渠道：%s 两端均无黑市" % path)
			for city_id in [city_a_id, city_b_id]:
				var held_s: int = int(smuggling_count.get(city_id, 0))
				if held_s >= smuggle_cap:
					_errors.append("预置走私航线超过每城上限：%s 已建 %d 条（上限 %d）" % [
						path, held_s, smuggle_cap
					])
				smuggling_count[city_id] = held_s + 1

		_trade_routes.append({
			"cityA": city_a_id,
			"cityB": city_b_id,
			"kind": kind,
		})


## 技能配置。校验的重点不是格式，而是那些"填错了也能跑、但战斗结算会悄悄错"的字段：
## 被动技能的 AP、主动技能的倍率与法术的基础伤害，缺一个都只会表现为伤害偏低。
func _validate_skills(root: Dictionary) -> void:
	var list: Variant = root.get("skills", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("技能配置缺少非空的 skills 数组")
		return

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "skills[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("技能配置 %s 必须是对象" % path)
			continue
		var skill: Dictionary = entry

		var skill_id: String = str(skill.get("skillId", ""))
		if skill_id.is_empty():
			_errors.append("技能配置缺少字段：%s.skillId" % path)
		elif seen.has(skill_id):
			_errors.append("技能配置 skillId 重复：%s" % skill_id)
		else:
			seen[skill_id] = true

		if str(skill.get("displayName", "")).is_empty():
			_errors.append("技能配置缺少字段：%s.displayName" % path)

		var category: String = str(skill.get("category", ""))
		if not SKILL_CATEGORIES.has(category):
			_errors.append("技能配置 category 非法：%s.category = %s（应为 %s 之一）" % [
				path, category, ", ".join(PackedStringArray(SKILL_CATEGORIES))
			])
		if not SKILL_TIERS.has(str(skill.get("tier", ""))):
			_errors.append("技能配置 tier 非法：%s.tier = %s（应为 %s 之一）" % [
				path, str(skill.get("tier", "")), ", ".join(PackedStringArray(SKILL_TIERS))
			])
		if not DAMAGE_TYPES.has(str(skill.get("damageType", ""))):
			_errors.append("技能配置 damageType 非法：%s.damageType = %s（应为 %s 之一）" % [
				path, str(skill.get("damageType", "")), ", ".join(PackedStringArray(DAMAGE_TYPES))
			])

		for key in ["apCost", "cooldown", "multiplier", "baseDamage"]:
			if not skill.has(key):
				_errors.append("技能配置缺少字段：%s.%s" % [path, key])

		var ap_cost: int = int(skill.get("apCost", 0))
		if ap_cost < 0:
			_errors.append("技能配置 apCost 不能为负：%s.apCost = %d" % [path, ap_cost])
		elif category == "passive" and ap_cost != 0:
			_errors.append("技能配置被动技能的 apCost 必须为 0：%s.apCost = %d" % [path, ap_cost])
		elif category != "passive" and ap_cost < 1:
			_errors.append("技能配置主动技能的 apCost 至少为 1，否则战斗里可无限行动：%s.apCost = %d" % [
				path, ap_cost
			])

		if int(skill.get("cooldown", 0)) < 0:
			_errors.append("技能配置 cooldown 不能为负：%s.cooldown" % path)

		# 武器技能必须有倍率，否则挥出去等于空挥。法术不查这一条：
		# 治疗与增益类法术本来就没有伤害，baseDamage 为 0 是正常的。
		if category == "weapon" and float(skill.get("multiplier", 0.0)) <= 0.0:
			_errors.append("武器技能的 multiplier 必须为正：%s.multiplier = %f" % [
				path, float(skill.get("multiplier", 0.0))
			])

	_skills = root


## 物品配置。武器必须有攻击力，防具的护甲与魔抗不能同时为 0——两者都是
## "填了 0 不报错、但穿了等于没穿"的静默错误。
func _validate_items(root: Dictionary) -> void:
	var list: Variant = root.get("items", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("物品配置缺少非空的 items 数组")
		return

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "items[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("物品配置 %s 必须是对象" % path)
			continue
		var item: Dictionary = entry

		var template_id: String = str(item.get("templateId", ""))
		if template_id.is_empty():
			_errors.append("物品配置缺少字段：%s.templateId" % path)
		elif seen.has(template_id):
			_errors.append("物品配置 templateId 重复：%s" % template_id)
		else:
			seen[template_id] = true

		if str(item.get("displayName", "")).is_empty():
			_errors.append("物品配置缺少字段：%s.displayName" % path)

		var category: String = str(item.get("category", ""))
		if not ITEM_CATEGORIES.has(category):
			_errors.append("物品配置 category 非法：%s.category = %s（应为 %s 之一）" % [
				path, category, ", ".join(PackedStringArray(ITEM_CATEGORIES))
			])
		if not ITEM_RARITIES.has(str(item.get("rarity", ""))):
			_errors.append("物品配置 rarity 非法：%s.rarity = %s（应为 %s 之一）" % [
				path, str(item.get("rarity", "")), ", ".join(PackedStringArray(ITEM_RARITIES))
			])

		if int(item.get("price", -1)) < 0:
			_errors.append("物品配置价格不能为负：%s.price" % path)
		if int(item.get("weight", -1)) < 0:
			_errors.append("物品配置负重不能为负：%s.weight" % path)

		_validate_item_slot(item, path, category)

		match category:
			"weapon":
				if int(item.get("attack", 0)) <= 0:
					_errors.append("武器攻击力必须为正：%s.attack = %d" % [path, int(item.get("attack", 0))])
				if int(item.get("attackRange", 0)) <= 0:
					_errors.append("武器攻击距离必须为正：%s.attackRange" % path)
			"armor":
				if int(item.get("armor", 0)) <= 0 and int(item.get("magicResist", 0)) <= 0:
					_errors.append("防具的护甲与魔抗不能同时为 0（穿了等于没穿）：%s" % path)

	_items = root


## 单件物品的槽位与手数（D-50）。三处都是"填错了也能跑、但玩起来才发现"的字段：
## 少一个 slot 的表现是"这件装备永远穿不上"；给消耗品写了 slot 会让它出现在
## 装备动作里；hands 写成 0 或 3 会让弓变成单手武器（双手规则全靠它）。
func _validate_item_slot(item: Dictionary, path: String, category: String) -> void:
	var equipment: Dictionary = _balance.get("equipment", {})
	var slots: Array = _array_of(equipment.get("slots", null))
	var declared: String = str(item.get("slot", ""))
	# 槽位表本身有问题时已经报过一次，这里不再重复报"槽位非法"
	var slots_known: bool = not slots.is_empty()
	var hands: int = int(item.get("hands", 0))

	if not ITEM_EQUIP_CATEGORIES.has(category):
		if not declared.is_empty():
			_errors.append("不占槽位的类别不能声明 slot：%s.slot = %s" % [path, declared])
		if hands != 0:
			_errors.append("非武器的手数必须为 0：%s.hands = %d" % [path, hands])
		return

	if declared.is_empty():
		_errors.append("物品配置缺少字段：%s.slot（装备必须写明进哪个槽）" % path)
	elif slots_known and not slots.has(declared):
		_errors.append("物品配置的槽位非法：%s.slot = %s（应为 %s 之一）" % [
			path, declared, ", ".join(PackedStringArray(slots))
		])

	if category != "weapon":
		if hands != 0:
			_errors.append("防具的手数必须为 0：%s.hands = %d" % [path, hands])
		return
	if hands != 1 and hands != 2:
		_errors.append("武器的手数只能是 1 或 2：%s.hands = %d" % [path, hands])
	elif hands == 2 and not _array_of(equipment.get("twoHandedSlots", null)).has(declared):
		# 双手武器的槽位若不在 twoHandedSlots 里，"占两只手"这条规则永远不会触发
		_errors.append("双手武器的槽位必须落在 equipment.twoHandedSlots 里：%s" % path)


## 天赋与缺陷配置（《数值框架》7 节）。当量的正负必须与分类一致，
## 且两侧都不能为空——否则 M3.1 的"数量相等"配对永远无法满足。
func _validate_talents(root: Dictionary) -> void:
	var list: Variant = root.get("talents", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("天赋配置缺少非空的 talents 数组")
		return

	var seen: Dictionary = {}
	var talent_count: int = 0
	var flaw_count: int = 0
	for i in range((list as Array).size()):
		var path: String = "talents[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("天赋配置 %s 必须是对象" % path)
			continue
		var talent: Dictionary = entry

		var talent_id: String = str(talent.get("talentId", ""))
		if talent_id.is_empty():
			_errors.append("天赋配置缺少字段：%s.talentId" % path)
		elif seen.has(talent_id):
			_errors.append("天赋配置 talentId 重复：%s" % talent_id)
		else:
			seen[talent_id] = true

		if str(talent.get("displayName", "")).is_empty():
			_errors.append("天赋配置缺少字段：%s.displayName" % path)

		var category: String = str(talent.get("category", ""))
		if not TALENT_CATEGORIES.has(category):
			_errors.append("天赋配置 category 非法：%s.category = %s（应为 %s 之一）" % [
				path, category, ", ".join(PackedStringArray(TALENT_CATEGORIES))
			])
			continue

		var weight: int = int(talent.get("weight", 0))
		if category == "talent":
			talent_count += 1
			if weight <= 0:
				_errors.append("天赋配置 category 为 talent 时当量必须为正：%s.weight = %d" % [path, weight])
		else:
			flaw_count += 1
			if weight >= 0:
				_errors.append("天赋配置 category 为 flaw 时当量必须为负：%s.weight = %d" % [path, weight])

		# 属性类的天赋缺陷必须指明作用在哪个维度上，否则效果无处落地
		if str(talent.get("effectKind", "")) == "attribute":
			var attr: String = str(talent.get("effectAttribute", ""))
			if not PlayerAvatar.ALL_ATTRIBUTES.has(attr):
				_errors.append("天赋配置属性类效果的 effectAttribute 非法：%s.effectAttribute = %s" % [
					path, attr
				])

	if talent_count == 0:
		_errors.append("天赋配置没有任何天赋（category=talent），M3.1 配对无法满足")
	if flaw_count == 0:
		_errors.append("天赋配置没有任何缺陷（category=flaw），M3.1 配对无法满足")

	_talents = root


## 出身配置（《游戏设计文档》4.1 节）。这一份的校验最重，因为它横跨
## 物品、技能、职业、城市四份配置的引用，任何一处拼错都只会在创建角色时才炸。
func _validate_backgrounds(root: Dictionary) -> void:
	var list: Variant = root.get("backgrounds", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("出身配置缺少非空的 backgrounds 数组")
		return

	var profession_ids: Dictionary = {}
	for entry in _professions.get("professions", []):
		profession_ids[str(entry.get("professionId", ""))] = true
	var relation_types: Array = [
		NpcGenerator.RELATION_KIN, NpcGenerator.RELATION_COLLEAGUE,
		NpcGenerator.RELATION_FRIEND, NpcGenerator.RELATION_ENEMY,
	]

	var seen: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "backgrounds[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("出身配置 %s 必须是对象" % path)
			continue
		var background: Dictionary = entry

		var background_id: String = str(background.get("backgroundId", ""))
		if background_id.is_empty():
			_errors.append("出身配置缺少字段：%s.backgroundId" % path)
		elif seen.has(background_id):
			_errors.append("出身配置 backgroundId 重复：%s" % background_id)
		else:
			seen[background_id] = true

		if str(background.get("displayName", "")).is_empty():
			_errors.append("出身配置缺少字段：%s.displayName" % path)

		if int(background.get("startAge", 0)) < NpcGenerator.ADULT_AGE:
			_errors.append("出身配置 startAge 不得低于成年年龄 %d：%s.startAge = %d" % [
				NpcGenerator.ADULT_AGE, path, int(background.get("startAge", 0))
			])

		for key in ["initialMoney", "initialDebtCopper", "startCityReputation"]:
			if not background.has(key):
				_errors.append("出身配置缺少字段：%s.%s" % [path, key])
				continue
			var value: int = int(background[key])
			if key != "startCityReputation" and value < 0:
				_errors.append("出身配置 %s 不能为负：%s = %d" % [key, path, value])

		var start_city: String = str(background.get("startCityId", ""))
		if not start_city.is_empty() and get_city_config(start_city).is_empty():
			_errors.append("出身配置指向不存在的城市：%s.startCityId = %s" % [path, start_city])

		for template_id in background.get("initialItems", []):
			if get_item(str(template_id)).is_empty():
				_errors.append("出身配置的初始物品不存在：%s.initialItems 含 %s" % [path, str(template_id)])

		for skill_id in background.get("initialSkills", {}):
			var level: int = int(background["initialSkills"][skill_id])
			if get_skill(str(skill_id)).is_empty():
				_errors.append("出身配置的初始技能不存在：%s.initialSkills 含 %s" % [path, str(skill_id)])
			if level < 0 or level > SKILL_LEVEL_MAX:
				_errors.append("出身配置的初始技能熟练度越界（0-%d）：%s.initialSkills.%s = %d" % [
					SKILL_LEVEL_MAX, path, str(skill_id), level
				])

		for relation in background.get("initialRelations", []):
			var relation_path: String = "%s.initialRelations" % path
			var profession_id: String = str(relation.get("professionId", ""))
			if not profession_ids.has(profession_id):
				_errors.append("出身配置的开局关系指向不存在的职业：%s.professionId = %s" % [
					relation_path, profession_id
				])
			var relation_type: String = str(relation.get("relationType", ""))
			if not relation_types.has(relation_type):
				_errors.append("出身配置的开局关系类型非法：%s.relationType = %s（应为 %s 之一）" % [
					relation_path, relation_type, ", ".join(PackedStringArray(relation_types))
				])

	_backgrounds = root


## 委托任务配置（《世界模拟量化规则》10.1–10.3 + 《委托任务剧本》QT-01~06）。
##
## 校验的重点是"填错了也能跑、但玩家会拿到一份错的报酬"的字段：维度名、触发阈值、
## 三档状态增量、分支后果、延迟后果。战斗分支的 outcome 键必须落在 M5.4 的四种
## 倒地处理上——战场上选的那一项若在配置里没有对应后果，玩家的选择就落空了。
func _validate_quests(root: Dictionary) -> void:
	var dim_min: int = int(_balance.get("dimension", {}).get("min", DEFAULT_DIM_MIN))
	var dim_max: int = int(_balance.get("dimension", {}).get("max", DEFAULT_DIM_MAX))

	var tiers: Variant = root.get("tiers", null)
	if not (tiers is Array) or (tiers as Array).is_empty():
		_errors.append("委托任务配置缺少非空的 tiers 数组")
		return
	var tier_ids: Array = []
	for i in range((tiers as Array).size()):
		var path: String = "tiers[%d]" % i
		var entry: Variant = (tiers as Array)[i]
		if not (entry is Dictionary):
			_errors.append("委托档位 %s 必须是对象" % path)
			continue
		var tier: Dictionary = entry
		var tier_id: String = str(tier.get("tierId", ""))
		if tier_id.is_empty():
			_errors.append("委托档位缺少字段：%s.tierId" % path)
			continue
		if tier_ids.has(tier_id):
			_errors.append("委托档位重复：%s" % tier_id)
			continue
		tier_ids.append(tier_id)
		if int(tier.get("moneyCopper", 0)) <= 0:
			_errors.append("委托档位 %s 的 moneyCopper 必须为正" % tier_id)
		if int(tier.get("deadlineMonths", 0)) <= 0:
			_errors.append("委托档位 %s 的 deadlineMonths 必须为正" % tier_id)

	var list: Variant = root.get("quests", null)
	if not (list is Array) or (list as Array).is_empty():
		_errors.append("委托任务配置缺少非空的 quests 数组")
		return

	var seen_types: Dictionary = {}
	for i in range((list as Array).size()):
		var path: String = "quests[%d]" % i
		var entry: Variant = (list as Array)[i]
		if not (entry is Dictionary):
			_errors.append("委托任务配置 %s 必须是对象" % path)
			continue
		var quest: Dictionary = entry

		var type_id: String = str(quest.get("questTypeId", ""))
		if type_id.is_empty():
			_errors.append("委托任务配置缺少字段：%s.questTypeId" % path)
		elif seen_types.has(type_id):
			_errors.append("委托任务类型重复：%s" % type_id)
		else:
			seen_types[type_id] = true
			path = "quests[%s]" % type_id

		if str(quest.get("displayName", "")).is_empty():
			_errors.append("委托任务配置缺少字段：%s.displayName" % path)
		if str(quest.get("giverLabel", "")).is_empty():
			_errors.append("委托任务配置缺少委托人：%s.giverLabel" % path)

		var dimension: String = str(quest.get("dimension", ""))
		if not City.ALL_DIMENSIONS.has(dimension):
			_errors.append("委托任务配置的维度非法：%s.dimension = %s（应为 %s 之一）" % [
				path, dimension, ", ".join(PackedStringArray(City.ALL_DIMENSIONS))
			])
		var trigger: int = int(quest.get("triggerBelow", -1))
		if trigger < dim_min or trigger > dim_max:
			_errors.append("委托任务配置的触发阈值越界（%d-%d）：%s.triggerBelow = %d" % [
				dim_min, dim_max, path, trigger
			])

		# 三档状态增量缺一档的后果是"某一档的任务交付后城市纹丝不动"
		var gains: Variant = quest.get("stateGain", null)
		if not (gains is Dictionary):
			_errors.append("委托任务配置缺少 stateGain：%s" % path)
		else:
			for tier_id in tier_ids:
				if not (gains as Dictionary).has(tier_id):
					_errors.append("委托任务配置的 stateGain 缺少档位 %s：%s" % [tier_id, path])
				elif int((gains as Dictionary)[tier_id]) == 0:
					_errors.append("委托任务配置的 stateGain 不能为 0：%s.%s" % [path, tier_id])

		var dialogue: Variant = quest.get("dialogue", null)
		if not (dialogue is Array) or (dialogue as Array).is_empty():
			_errors.append("委托任务配置缺少非空的 dialogue：%s" % path)

		_validate_quest_branches(quest, path)
		_validate_quest_combat(quest, path)

	_quests = root


## 分支与延迟后果。分支只给修正系数，所以必须显式写出——缺 moneyMultiplier 会被
## 当成 0，玩家接下一条分支后一分钱没有，而配置里看不出任何异常。
func _validate_quest_branches(quest: Dictionary, path: String) -> void:
	var branches: Variant = quest.get("branches", null)
	if not (branches is Array) or (branches as Array).is_empty():
		_errors.append("委托任务配置缺少非空的 branches：%s" % path)
		return
	var seen: Dictionary = {}
	for i in range((branches as Array).size()):
		var bpath: String = "%s.branches[%d]" % [path, i]
		var entry: Variant = (branches as Array)[i]
		if not (entry is Dictionary):
			_errors.append("委托分支 %s 必须是对象" % bpath)
			continue
		var branch: Dictionary = entry
		var branch_id: String = str(branch.get("branchId", ""))
		if branch_id.is_empty():
			_errors.append("委托分支缺少字段：%s.branchId" % bpath)
		elif seen.has(branch_id):
			_errors.append("委托分支重复：%s.%s" % [path, branch_id])
		else:
			seen[branch_id] = true
			bpath = "%s.branches[%s]" % [path, branch_id]

		if str(branch.get("label", "")).is_empty():
			_errors.append("委托分支缺少选项文字：%s.label" % bpath)
		for key in ["stateMultiplier", "moneyMultiplier"]:
			if not branch.has(key):
				_errors.append("委托分支缺少字段：%s.%s" % [bpath, key])
		if branch.has("flags"):
			if not (branch["flags"] is Array):
				_errors.append("委托分支的 flags 必须是数组：%s.flags" % bpath)
		var delayed: Variant = branch.get("delayed", null)
		if delayed == null:
			continue
		if not (delayed is Dictionary):
			_errors.append("委托分支的 delayed 必须是对象：%s.delayed" % bpath)
			continue
		var delay: Dictionary = delayed
		if int(delay.get("months", 0)) <= 0:
			_errors.append("延迟后果的月数必须为正：%s.delayed.months" % bpath)
		if not City.ALL_DIMENSIONS.has(str(delay.get("dimension", ""))):
			_errors.append("延迟后果的维度非法：%s.delayed.dimension = %s" % [
				bpath, str(delay.get("dimension", ""))
			])
		if int(delay.get("delta", 0)) == 0:
			_errors.append("延迟后果的 delta 不能为 0：%s.delayed.delta" % bpath)
		if str(delay.get("text", "")).is_empty():
			_errors.append("延迟后果缺少事件文案：%s.delayed.text" % bpath)


## 战斗分支。除了 defeat 之外，每个 outcome 键都是一次倒地处理，键名必须与
## Combat.ALL_DOWNED_CHOICES 一致，否则玩家在战场上选的那一项没有对应后果。
func _validate_quest_combat(quest: Dictionary, path: String) -> void:
	var combat: Variant = quest.get("combat", null)
	if combat == null:
		return
	if not (combat is Dictionary):
		_errors.append("委托战斗段必须是对象：%s.combat" % path)
		return
	var cfg: Dictionary = combat
	if str(cfg.get("label", "")).is_empty():
		_errors.append("委托战斗段缺少选项文字：%s.combat.label" % path)
	var outcomes: Variant = cfg.get("outcomes", null)
	if not (outcomes is Dictionary):
		_errors.append("委托战斗段缺少 outcomes：%s.combat" % path)
		return
	var outcome_keys: Array = (outcomes as Dictionary).keys()
	if not outcome_keys.has("defeat"):
		_errors.append("委托战斗段缺少 defeat 结局：%s.combat.outcomes" % path)
	for key in outcome_keys:
		var name: String = str(key)
		if name == "defeat":
			continue
		if not Combat.ALL_DOWNED_CHOICES.has(name):
			_errors.append("委托战斗结局名非法：%s.combat.outcomes.%s（应为 defeat 或 %s 之一）" % [
				path, name, ", ".join(PackedStringArray(Combat.ALL_DOWNED_CHOICES))
			])

