class_name CharacterCreation
extends RefCounted

## 自由生成开局（M3.1）。
##
## 验收标准（《技术设计文档》8.4 节）：可选种族、出身、属性分配、天赋与缺陷配对；
## 缺陷数与天赋数相等才允许开局。
##
## 天赋与缺陷的配对口径在文档里有三种说法：《数值框架》7 节是「正面总当量不得
## 超过负面总当量」，《游戏设计文档》4.1 节是「正面天赋必须搭配等值缺陷」，
## 本节验收标准是「数量相等」。三者不能同时成立——现有 5 条清单里唯一的 -4
## 当量是「仇家」，而没有任何 +4 的天赋，所以"等值"在现有数据下根本不可实现。
## 实现取「数量相等」为硬门槛（它是验收口径，可判定），叠加「当量不超过」
## 作为平衡约束（它天然兼容数量相等，且是唯一能容纳 -4 仇家的规则）。
##
## 这一模块只做校验与装配，不碰存档、不碰世界状态，因此可以在无头环境下测。

## 属性分配的上下限来自 balance.characterCreation；这里只留字段名常量。
const ATTR_POINTS_KEY: String = "allocations"

var _cfg: Dictionary = {}
var _races: Array = []
var _backgrounds: Array = []
var _talents: Array = []


func _init(
	creation_cfg: Dictionary = {},
	races: Array = [],
	backgrounds: Array = [],
	talents: Array = []
) -> void:
	_cfg = creation_cfg
	_races = races
	_backgrounds = backgrounds
	_talents = talents


# --- 选项 ---

func race_options() -> Array:
	return _races


func background_options() -> Array:
	return _backgrounds


func talent_options() -> Array:
	return _options_of_category("talent")


func flaw_options() -> Array:
	return _options_of_category("flaw")


func base_attribute() -> int:
	return int(_cfg.get("baseAttribute", 10))


func allocatable_points() -> int:
	return int(_cfg.get("allocatablePoints", 20))


func creation_max_attribute() -> int:
	return int(_cfg.get("creationMaxAttribute", 20))


## 创建期单项能加到多少（相对起点）。上限 20 而起点 10，所以单项最多再加 10。
func per_attribute_cap() -> int:
	return maxi(0, creation_max_attribute() - base_attribute())


# --- 规格 ---

## 一份空规格，各字段取合法初值。
func new_spec() -> Dictionary:
	var spec: Dictionary = {
		"race": "",
		"gender": PlayerAvatar.GENDER_DEFAULT,
		"displayName": "",
		"backgroundId": "",
		"startCityId": "",
		"talents": [],
		"flaws": [],
	}
	spec[ATTR_POINTS_KEY] = zero_allocations()
	return spec


## 七维全零的分配表。随机转生也要填这个字段（它不吃创建期分配点），
## 所以做成静态函数供两处共用。
static func zero_allocations() -> Dictionary:
	var out: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		out[attr] = 0
	return out


## 已分配的点数。
func spent_points(spec: Dictionary) -> int:
	var allocations: Dictionary = spec.get(ATTR_POINTS_KEY, {})
	var total: int = 0
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		total += int(allocations.get(attr, 0))
	return total


func remaining_points(spec: Dictionary) -> int:
	return allocatable_points() - spent_points(spec)


## 种族偏移叠加在分配之后，结果钳制在 attributeMin–attributeMax。
## spec.attributeBonuses 是第三条加法通道，专给随机转生的「前世属性继承加成」
## 用——《数值框架》11 节把它定义为「基础属性加成」，与创建期分配点是两套独立机制。
func final_attributes(spec: Dictionary) -> Dictionary:
	var offsets: Dictionary = race_offsets(str(spec.get("race", "")))
	var allocations: Dictionary = spec.get(ATTR_POINTS_KEY, {})
	var bonuses: Dictionary = spec.get("attributeBonuses", {})
	var low: int = int(_cfg.get("attributeMin", 1))
	var high: int = int(_cfg.get("attributeMax", 100))
	var out: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		var value: int = base_attribute() \
			+ int(allocations.get(attr, 0)) \
			+ int(offsets.get(attr, 0)) \
			+ int(bonuses.get(attr, 0))
		out[attr] = clampi(value, low, high)
	return out


func race_offsets(race_id: String) -> Dictionary:
	for race in _races:
		if str(race.get("raceId", "")) == race_id:
			return race.get("attributeOffsets", {})
	return {}


# --- 校验 ---

## 校验一份规格。返回 {ok, errors: [文案]}。错误全部收集后再返回，
## 让界面能一次列全问题，而不是让玩家改一个报一个。
func validate(spec: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	var race_id: String = str(spec.get("race", ""))
	if race_id.is_empty():
		errors.append("未选择种族")
	elif _find(_races, "raceId", race_id).is_empty():
		errors.append("种族不存在或不可选：%s" % race_id)

	var background_id: String = str(spec.get("backgroundId", ""))
	if background_id.is_empty():
		errors.append("未选择出身")
	elif _find(_backgrounds, "backgroundId", background_id).is_empty():
		errors.append("出身不存在：%s" % background_id)

	var gender: String = str(spec.get("gender", ""))
	if gender != PlayerAvatar.GENDER_MALE and gender != PlayerAvatar.GENDER_FEMALE:
		errors.append("性别非法：%s" % gender)

	errors.append_array(_validate_allocations(spec))
	errors.append_array(_validate_pairing(spec))

	return {"ok": errors.is_empty(), "errors": errors}


func _validate_allocations(spec: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var allocations: Variant = spec.get(ATTR_POINTS_KEY, null)
	if not (allocations is Dictionary):
		errors.append("属性分配必须是对象")
		return errors

	var cap: int = per_attribute_cap()
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		if not (allocations as Dictionary).has(attr):
			errors.append("属性分配缺少维度：%s" % attr)
			continue
		var value: int = int((allocations as Dictionary)[attr])
		if value < 0:
			errors.append("%s 的分配点数不能为负：%d" % [attr, value])
		elif value > cap:
			errors.append("%s 的分配点数超过创建期上限（单项最多 %d）：%d" % [attr, cap, value])

	var remaining: int = remaining_points(spec)
	if remaining > 0:
		errors.append("还有 %d 点未分配" % remaining)
	elif remaining < 0:
		errors.append("超出可分配点数 %d 点" % (-remaining))
	return errors


## 配对校验：数量必须相等（M3.1 验收口径），且正面总当量不得超过负面总当量
## （《数值框架》7 节的平衡约束）。
func _validate_pairing(spec: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var talents: Array = spec.get("talents", [])
	var flaws: Array = spec.get("flaws", [])

	var seen: Dictionary = {}
	var talent_weight: int = 0
	for talent_id in talents:
		var entry: Dictionary = _find(_talents, "talentId", str(talent_id))
		if entry.is_empty():
			errors.append("天赋不存在：%s" % str(talent_id))
			continue
		if str(entry.get("category", "")) != "talent":
			errors.append("「%s」不是天赋" % str(entry.get("displayName", talent_id)))
		if seen.has(str(talent_id)):
			errors.append("天赋重复选择：%s" % str(talent_id))
		seen[str(talent_id)] = true
		talent_weight += int(entry.get("weight", 0))

	var flaw_weight: int = 0
	for flaw_id in flaws:
		var entry: Dictionary = _find(_talents, "talentId", str(flaw_id))
		if entry.is_empty():
			errors.append("缺陷不存在：%s" % str(flaw_id))
			continue
		if str(entry.get("category", "")) != "flaw":
			errors.append("「%s」不是缺陷" % str(entry.get("displayName", flaw_id)))
		if seen.has(str(flaw_id)):
			errors.append("缺陷重复选择：%s" % str(flaw_id))
		seen[str(flaw_id)] = true
		flaw_weight += int(entry.get("weight", 0))

	if talents.size() != flaws.size():
		errors.append("天赋与缺陷数量必须相等（当前 %d 天赋 / %d 缺陷）" % [
			talents.size(), flaws.size()
		])
	# flaw_weight 是负数，取绝对值后比较
	if talent_weight > absi(flaw_weight):
		errors.append("正面天赋的总当量（%d）不得超过负面缺陷的总当量（%d）" % [
			talent_weight, absi(flaw_weight)
		])
	return errors


# --- 装配 ---

## 按规格装配一具化身。自由生成时调用前必须先 validate 通过；
## 随机转生走的是另一条路（规格由宿主推导，没有出身），因此这里对
## 空 backgroundId 是容错的：出身取不到，初始金钱与物品就都是零。
func build_avatar(spec: Dictionary, avatar_id: String, soul_id: String) -> PlayerAvatar:
	var background: Dictionary = _find(
		_backgrounds, "backgroundId", str(spec.get("backgroundId", ""))
	)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = avatar_id
	avatar.soul_id = soul_id
	avatar.display_name = str(spec.get("displayName", ""))
	avatar.gender = str(spec.get("gender", PlayerAvatar.GENDER_DEFAULT))
	avatar.race = str(spec.get("race", ""))
	avatar.background_id = str(spec.get("backgroundId", ""))
	avatar.age = int(spec.get("startAge", background.get("startAge", 20)))
	avatar.host_avatar_id = str(spec.get("hostAvatarId", ""))
	avatar.legacy = spec.get("legacy", {}).duplicate(true)

	avatar.attributes = final_attributes(spec)

	for talent_id in spec.get("talents", []):
		avatar.talents.append(str(talent_id))
	for flaw_id in spec.get("flaws", []):
		avatar.flaws.append(str(flaw_id))
	_apply_talent_effects(avatar, avatar.talents)
	_apply_talent_effects(avatar, avatar.flaws)

	avatar.money = int(background.get("initialMoney", 0))
	avatar.debt_copper = int(background.get("initialDebtCopper", 0))
	avatar.debt_copper += _talent_debt(avatar.flaws)

	# 初始技能
	var start_skills: Dictionary = background.get("initialSkills", {})
	for skill_id in start_skills:
		avatar.skills[str(skill_id)] = int(start_skills[skill_id])

	# 初始物品：配置给的是模板，这里为每件生成一个实例
	var seq: int = 0
	for template_id in background.get("initialItems", []):
		seq += 1
		add_item(avatar, str(template_id), "%s-item-%03d" % [avatar_id, seq])

	# 起始城市的声誉
	var start_city: String = str(spec.get("startCityId", ""))
	if start_city.is_empty():
		start_city = str(background.get("startCityId", ""))
	if not start_city.is_empty():
		avatar.set_reputation(start_city, int(background.get("startCityReputation", 0)))

	avatar.luck = 0
	avatar.karma = 0
	return avatar


## 往化身背包里放一件物品，返回实例 ID。静态：出生装配、战斗战利品、买卖入库
## 三处都用它，各自新建一个 CharacterCreation 只为调这一个函数没有意义。
##
## 实例的词缀与强化由 seed_text 决定（见 ItemInstance 的注释）。不给种子时按
## 实例 ID 派生——同一份存档重放同一次掉落，摇出来的还是那一件。商铺买入另给
## 一个"城市 + 渠道 + 模板"的种子，好让到手的货与货架上报的价对得上。
##
## 出身给的行装现在都是普通货（0 条词缀），所以穿上的确实是一件白板；将来若给
## 某一档出身配了精良以上的行装，它会带着词缀出生——那是"这件东西有来头"，
## 不是 bug。
static func add_item(
	avatar: PlayerAvatar, template_id: String, instance_id: String, seed_text: String = ""
) -> String:
	var seed: String = instance_id if seed_text.is_empty() else seed_text
	avatar.item_instances[instance_id] = ItemInstance.new_instance(template_id, seed)
	avatar.inventory.append(instance_id)
	return instance_id


func _apply_talent_effects(avatar: PlayerAvatar, ids: Array) -> void:
	for talent_id in ids:
		var entry: Dictionary = _find(_talents, "talentId", str(talent_id))
		if entry.is_empty():
			continue
		if str(entry.get("effectKind", "")) != "attribute":
			continue
		var attr: String = str(entry.get("effectAttribute", ""))
		if not PlayerAvatar.ALL_ATTRIBUTES.has(attr):
			continue
		avatar.set_attribute(attr, avatar.get_attribute(attr) + int(entry.get("effectValue", 0)))


func _talent_debt(ids: Array) -> int:
	var total: int = 0
	for talent_id in ids:
		var entry: Dictionary = _find(_talents, "talentId", str(talent_id))
		if str(entry.get("effectKind", "")) == "debt":
			total += int(entry.get("effectValue", 0))
	return total


func _options_of_category(category: String) -> Array:
	var out: Array = []
	for entry in _talents:
		if str(entry.get("category", "")) == category:
			out.append(entry)
	return out


static func _find(list: Array, key: String, value: String) -> Dictionary:
	for entry in list:
		if str(entry.get(key, "")) == value:
			return entry
	return {}
