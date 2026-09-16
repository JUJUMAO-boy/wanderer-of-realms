class_name ItemInstance
extends RefCounted

## 物品实例层（《技术设计文档》3.3 节 ITEM_INSTANCE）。
##
## 模板与实例分离的理由文档里写得很清楚：同一把"铁剑"的模板唯一，但每个实例的
## 耐久、强化、词缀不同。文档只列了三个字段名，怎么取值、从哪来、按什么口径
## 折算成钱，一处也没写（见《技术设计文档》D-54 ~ D-57）。这一层把它们收拢：
##   - 词缀：从 affixes.json 的池子里按类别与稀有度摇，数量由 8 节的「附带词条数」定
##   - 强化：每级按**模板基础值**的百分比加，上限与成功率、费用写在 balance.itemInstance
##   - 耐久：只记录与显示，不磨损（D-55）
##
## 与 Equipment 同一条边界：这里只看玩家自己的物品实例，不碰城市六维、不提交
## StateChange。它是纯函数层——除 forge 会就地改传进来的那份实例字典之外，
## 没有任何状态。
##
## **为什么词缀由种子决定而不是由调用方给随机数**：世界的随机数序列不该因为玩家
## 买了一件货而改变。买货、掉落、出生三处各自派生一个种子（卖出前是"城市 + 渠道 +
## 模板"，这样货架上报的价与到手的货是同一件），存档里存的是摇好的结果，
## 于是读档重放不会摇出第二套词缀。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_PRECONDITION_FAILED: String = "PRECONDITION_FAILED"

const STAT_ATTACK: String = "attack"
const STAT_ARMOR: String = "armor"
const STAT_MAGIC_RESIST: String = "magicResist"
const STAT_ATTACK_RANGE: String = "attackRange"
const STAT_HANDS: String = "hands"

## 加在装备自身数值上的目标；其余目标一律当七维，加在佩戴者身上。
const EQUIP_TARGETS: Array = [STAT_ATTACK, STAT_ARMOR, STAT_MAGIC_RESIST]

## 会摇词缀的类别。消耗品没有词缀——一艘船不会因为面包"锋锐"而变快。
const AFFIX_CATEGORIES: Array = ["weapon", "armor"]

const TARGET_LABELS: Dictionary = {
	STAT_ATTACK: "攻击", STAT_ARMOR: "护甲", STAT_MAGIC_RESIST: "魔抗",
	"strength": "力量", "dexterity": "敏捷", "constitution": "体质",
	"intelligence": "智力", "perception": "感知", "charisma": "魅力", "soul": "灵魂",
}

const BP_FULL: int = 10000

var _affixes: Array = []
var _templates: Dictionary = {}
var _durability_max: int = 100
var _affix_count_by_rarity: Dictionary = {}
var _price_per_point: Dictionary = {}
var _enhancement_max: int = 0
var _per_level: float = 0.0
var _chance_bp: Array = []
var _cost_ratio: Array = []
var _repair: Dictionary = {}


## 规则取 ContentLoader，模板表由调用方给。模板表外传的理由与 Equipment、
## AvatarViewModel 一致：测试可以塞一份小样本，不必背完整配置。
static func create(templates: Dictionary) -> ItemInstance:
	return ItemInstance.new(
		ContentLoader.get_balance_section("itemInstance"),
		ContentLoader.get_affixes(),
		templates
	)


## 直接用当前配置里的模板表。CharacterCreation.add_item 这类不持有任何配置的
## 静态入口走这一条。
static func create_from_config() -> ItemInstance:
	var templates: Dictionary = {}
	for entry in ContentLoader.get_items():
		if entry is Dictionary:
			templates[str((entry as Dictionary).get("templateId", ""))] = entry
	return create(templates)


## 直接用当前配置生成一件实例。出身装配、战斗掉落、买卖入库三处都不持有配置，
## 走这一条会各自新建一个规则对象——它们一次只做几件，不值得为此让调用方
## 多养一个成员。
static func new_instance(template_id: String, seed_text: String) -> Dictionary:
	return create_from_config().roll_instance(template_id, seed_text)


func _init(cfg: Dictionary = {}, affixes: Array = [], templates: Dictionary = {}) -> void:
	_affixes = affixes
	_templates = templates
	_durability_max = maxi(1, int(cfg.get("durabilityMax", 100)))
	_affix_count_by_rarity = _dict_of(cfg.get("affixCountByRarity", null))
	_price_per_point = _dict_of(cfg.get("affixPricePerPoint", null))
	_enhancement_max = maxi(0, int(cfg.get("enhancementMax", 0)))
	_per_level = maxf(0.0, float(cfg.get("enhancementPerLevelRatio", 0.0)))
	_chance_bp = _array_of(cfg.get("enhancementChanceBp", null))
	_cost_ratio = _array_of(cfg.get("enhancementCostRatio", null))
	_repair = _dict_of(cfg.get("repair", null))


# --- 规则查询 ---

func durability_max() -> int:
	return _durability_max


func enhancement_max() -> int:
	return _enhancement_max


## 某一档稀有度附带几条词缀（《数值框架》8 节的「附带词条数」）。
func affix_count(rarity: String) -> int:
	return maxi(0, int(_affix_count_by_rarity.get(rarity, 0)))


## 某一类装备可用的词缀池，按配置里的书写次序。次序是内容的一部分：
## 调整 affixes.json 里条目的先后，同一件货就会摇出不同的词缀。
func affix_pool(category: String) -> Array:
	if not AFFIX_CATEGORIES.has(category):
		return []
	var out: Array = []
	for entry in _affixes:
		if not (entry is Dictionary):
			continue
		if _array_of((entry as Dictionary).get("categories", null)).has(category):
			out.append(entry)
	return out


func template_of(template_id: String) -> Dictionary:
	var value: Variant = _templates.get(template_id, null)
	return value if value is Dictionary else {}


# --- 生成 ---

## 白板实例：满耐久、零强化、无词缀。出身配置里的初始物品走这一条——
## 那是"这个人本来就带着的东西"，不该靠运气决定它锋不锋利。
func bare_instance(template_id: String) -> Dictionary:
	return {
		"templateId": template_id,
		"durability": _durability_max,
		"enhancement": 0,
		"modifiers": [],
	}


## 摇一件实例。同一段 seed_text 永远得到同一件货——存档里存的是摇好的结果，
## 但"从存档里读回来的那一件"与"当初摇出来的那一件"必须对得上。
func roll_instance(template_id: String, seed_text: String) -> Dictionary:
	return roll_instance_with(template_id, DeterministicRNG.new(seed_from_text(seed_text)))


func roll_instance_with(template_id: String, rng: DeterministicRNG) -> Dictionary:
	var out: Dictionary = bare_instance(template_id)
	out["modifiers"] = roll_modifiers(template_id, rng)
	return out


## 按稀有度摇词缀：先从该类别可用的池里等概率不重复地取，再在区间里摇一个值。
## 两件同为"稀有"的剑因此可能一条词缀相同、另一条不同，数值也可能差一点——
## 这正是"实例各不相同"的全部来源。
func roll_modifiers(template_id: String, rng: DeterministicRNG) -> Array:
	if rng == null:
		return []
	var template: Dictionary = template_of(template_id)
	var count: int = affix_count(str(template.get("rarity", "")))
	if count <= 0:
		return []
	var pool: Array = affix_pool(str(template.get("category", "")))
	var out: Array = []
	for _i in range(count):
		if pool.is_empty():
			break
		var index: int = rng.next_int(pool.size())
		var affix: Dictionary = pool[index]
		pool.remove_at(index)
		out.append({
			"affixId": str(affix.get("affixId", "")),
			"target": str(affix.get("target", "")),
			"value": rng.range_int(int(affix.get("minValue", 0)), int(affix.get("maxValue", 0))),
		})
	return out


## 从一段文本派生种子（FNV-1a，32 位）。不用 String.hash()：那是引擎实现，
## 换一个引擎版本就可能变，而"同一件货摇出同样的词缀"要跨版本成立。
static func seed_from_text(text: String) -> int:
	var h: int = 0x811C9DC5
	for i in range(text.length()):
		h = (h ^ text.unicode_at(i)) & DeterministicRNG.MASK32
		h = (h * 16777619) & DeterministicRNG.MASK32
	return h


# --- 词缀 ---

func modifiers(instance: Dictionary) -> Array:
	var value: Variant = instance.get("modifiers", null)
	return value if value is Array else []


## 实例上作用在某一项的词缀之和。装备数值与七维走同一个函数——
## 目标名写在词缀上，加到哪里由名字决定。
func affix_bonus(instance: Dictionary, target: String) -> int:
	var total: int = 0
	for modifier in modifiers(instance):
		if not (modifier is Dictionary):
			continue
		if str((modifier as Dictionary).get("target", "")) == target:
			total += int((modifier as Dictionary).get("value", 0))
	return total


## 七维加成，只有非零项。只作用于这一件——"身上一共加多少"由 Equipment 汇总。
func attribute_bonus(instance: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for attribute in PlayerAvatar.ALL_ATTRIBUTES:
		var value: int = affix_bonus(instance, attribute)
		if value != 0:
			out[attribute] = value
	return out


## 词缀逐条写出来，界面按它画行。
func affix_rows(instance: Dictionary) -> Array:
	var out: Array = []
	for modifier in modifiers(instance):
		if not (modifier is Dictionary):
			continue
		var target: String = str((modifier as Dictionary).get("target", ""))
		var value: int = int((modifier as Dictionary).get("value", 0))
		out.append({
			"affixId": str((modifier as Dictionary).get("affixId", "")),
			"target": target,
			"targetLabel": str(TARGET_LABELS.get(target, target)),
			"value": value,
			"text": "%s +%d %s" % [
				_affix_name(str((modifier as Dictionary).get("affixId", ""))),
				value, str(TARGET_LABELS.get(target, target)),
			],
		})
	return out


func affix_text(instance: Dictionary) -> String:
	var parts: Array = []
	for row in affix_rows(instance):
		parts.append(str(row["text"]))
	return " · ".join(PackedStringArray(parts))


# --- 数值 ---

func enhancement(instance: Dictionary) -> int:
	return clampi(int(instance.get("enhancement", 0)), 0, _enhancement_max)


## 强化带来的加值：模板基础值 × 每级幅度 × 等级。
##
## 加在**基础值**上，不乘词缀：两者各管一段，玩家算得清——"这把剑基础 16，
## +3 是 16×1.3 = 21，锋锐再 +3，一共 24"。若强化乘在词缀上，同一级的收益
## 会随运气浮动，铁匠铺的价目也就没法先写在牌子上。
func enhancement_bonus(instance: Dictionary, base_value: int) -> int:
	if base_value <= 0:
		return 0
	return roundi(float(base_value) * _per_level * float(enhancement(instance)))


## 一件装备某一项的实际数值 = 模板基础值 + 强化加成 + 词缀加成。
func effective_stat(instance: Dictionary, stat: String) -> int:
	var template: Dictionary = template_of(str(instance.get("templateId", "")))
	var base: int = int(template.get(stat, 0))
	return maxi(0, base + enhancement_bonus(instance, base) + affix_bonus(instance, stat))


## 战斗与面板都读这一份。射程与手数是"这件东西是什么"，不随强化与词缀变——
## 词缀表里也没有它们，"锋锐的弓变成单手武器"这种事不该发生。
func effective_stats(instance: Dictionary) -> Dictionary:
	var template: Dictionary = template_of(str(instance.get("templateId", "")))
	return {
		STAT_ATTACK: effective_stat(instance, STAT_ATTACK),
		STAT_ARMOR: effective_stat(instance, STAT_ARMOR),
		STAT_MAGIC_RESIST: effective_stat(instance, STAT_MAGIC_RESIST),
		STAT_ATTACK_RANGE: int(template.get(STAT_ATTACK_RANGE, 0)),
		STAT_HANDS: int(template.get(STAT_HANDS, 0)),
	}


## 界面上写的名字。有强化等级就带上："精良长剑 +2"。
func display_name(instance: Dictionary) -> String:
	var template: Dictionary = template_of(str(instance.get("templateId", "")))
	var name: String = str(template.get("displayName", instance.get("templateId", "")))
	var level: int = enhancement(instance)
	return name if level <= 0 else "%s +%d" % [name, level]


# --- 耐久 ---

## 修理的三档（D-64）：便携工具就地、工匠回九成、满修回满。
const REPAIR_PORTABLE: String = "portable"
const REPAIR_CRAFTSMAN: String = "craftsman"
const REPAIR_FULL: String = "full"
const ALL_REPAIR_TIERS: Array = [REPAIR_PORTABLE, REPAIR_CRAFTSMAN, REPAIR_FULL]

const REPAIR_LABELS: Dictionary = {
	REPAIR_PORTABLE: "便携",
	REPAIR_CRAFTSMAN: "工匠",
	REPAIR_FULL: "满修",
}

func durability(instance: Dictionary) -> int:
	var value: Variant = instance.get("durability", null)
	if value == null:
		return _durability_max
	return clampi(int(value), 0, _durability_max)


func durability_text(instance: Dictionary) -> String:
	if broken(instance):
		return "耐久 %d/%d·损坏" % [durability(instance), _durability_max]
	return "耐久 %d/%d" % [durability(instance), _durability_max]


## 归零即失效（D-63）：损坏的武器不算攻击、损坏的护甲不算护甲。
## Equipment.loadout 与买卖两处都先看它——"坏了"与"没坏"是两件不同的东西。
func broken(instance: Dictionary) -> bool:
	return int(instance.get("durability", _durability_max)) <= 0


## 磨损一次（D-62）：按类别概率决定这次掉不掉 1 点，**就地扣**，返回是否真掉了。
## 满耐久也能被扣——"刚抽出的这把剑连修都没修过就打仗"也应磨损。概率钳在 0–10000 基点。
func wear(instance: Dictionary, weapon: bool, rng: DeterministicRNG) -> bool:
	if instance.get("durability", null) == null:
		instance["durability"] = _durability_max
	if int(instance["durability"]) <= 0:
		return false
	var key: String = "weaponWearChanceBp" if weapon else "armorWearChanceBp"
	var bp: int = clampi(int(_repair.get(key, 0)), 0, BP_FULL)
	if rng != null and rng.next_int(BP_FULL) >= bp:
		return false
	instance["durability"] = maxi(0, int(instance["durability"]) - int(_repair.get("wearAmount", 1)))
	return true


## 修到多少是"修得动"：目标耐久 = 当前 + 本档的回量，便携还要被"不超过 N 成"卡住。
## 已满或已满足下一档回量时返回与当前相同（调用方据此说"不需要修"）。
func repair_target(instance: Dictionary, tier: String) -> int:
	var current: int = durability(instance)
	var ceiling: int = _durability_max
	match tier:
		REPAIR_PORTABLE:
			# 便携每次在当前上回 5 成，但总耐久不超过上限的 9 成
			var restore: int = roundi(float(_durability_max) \
				* float(_repair.get("portableRestoreRatio", 0.0)))
			ceiling = roundi(float(_durability_max) \
				* float(_repair.get("portableDoesNotExceed", 0.0)))
			return clampi(current + restore, 0, ceiling)
		REPAIR_CRAFTSMAN:
			return maxi(current, roundi(float(_durability_max) \
				* float(_repair.get("craftsmanRestoreRatio", 0.0))))
		REPAIR_FULL:
			return _durability_max
	return current


func repair_cost(instance: Dictionary, tier: String) -> int:
	# 便携是背包里的工具（D-64），就地用、不花钱；只有铁匠铺的工匠/满修收工钱。
	# 这是个"要不要付铜"的分界，不能靠 per-point 退到 0 去凑——明确写死。
	if tier == REPAIR_PORTABLE:
		return 0
	var target: int = repair_target(instance, tier)
	var gap: int = target - durability(instance)
	if gap <= 0:
		return 0
	var per: int = int(_repair.get("craftsmanPerPointCopper", 0))
	if tier == REPAIR_FULL:
		per = int(_repair.get("fullPerPointCopper", 0))
		# 满修按强化等级加价：强化越高，回城满修越得付得起且越划算
		per = roundi(float(per) * (1.0 \
			+ float(enhancement(instance)) * float(_repair.get("fullEnhancementSurchargeRatio", 0.0))))
	return maxi(0, gap) * per


func can_repair(instance: Dictionary, tier: String, money: int) -> Dictionary:
	if instance.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这一件东西")
	if not ALL_REPAIR_TIERS.has(tier):
		return _fail(ERROR_INVALID_ARGUMENT, "没有这种修理：%s" % str(tier))
	if not broken(instance) and repair_target(instance, tier) <= durability(instance):
		return _fail(ERROR_PRECONDITION_FAILED, "「%s」目前不需这个档次的修理" % display_name(instance))
	if tier == REPAIR_CRAFTSMAN or tier == REPAIR_FULL:
		var cost: int = repair_cost(instance, tier)
		if cost > 0 and money < cost:
			return _fail(ERROR_PRECONDITION_FAILED, "钱不够：这次修理要 %d 铜，你只有 %d 铜" % [
				cost, money
			])
	return {"ok": true, "errorCode": ERROR_NONE, "error": ""}


## 就地修到 `tier` 的目标耐久。便携工具的数量由调用方扣（那是另一件东西），
## 这里只改这一件——与 forge 同一条边界。返回 {ok, tier, before, after, cost}。
func apply_repair(instance: Dictionary, tier: String) -> Dictionary:
	if not ALL_REPAIR_TIERS.has(tier):
		return _fail(ERROR_INVALID_ARGUMENT, "没有这种修理：%s" % str(tier))
	var before: int = durability(instance)
	var after: int = repair_target(instance, tier)
	if after <= before:
		return _fail(ERROR_PRECONDITION_FAILED, "这件目前不需要修")
	instance["durability"] = after
	return {
		"ok": true, "errorCode": ERROR_NONE, "error": "",
		"tier": tier, "before": before, "after": after,
		"cost": repair_cost(instance, tier),
	}


func repair_tier_label(tier: String) -> String:
	return str(REPAIR_LABELS.get(tier, tier))


# --- 价格 ---

## 词缀折价（铜）：逐条按"数值 × 该目标的每点折价"算。卖出时列得出来
## "锋锐 +3 = 75 铜"，这一项就是"带词缀的货比裸货贵"的全部依据。
func affix_price_bonus(instance: Dictionary) -> int:
	var total: int = 0
	for modifier in modifiers(instance):
		if not (modifier is Dictionary):
			continue
		var target: String = str((modifier as Dictionary).get("target", ""))
		total += int((modifier as Dictionary).get("value", 0)) \
			* int(_price_per_point.get(target, 0))
	return total


## 强化折价（铜）：与强化加成同一个口径（模板基准价 × 每级幅度 × 等级），
## 所以"强化花掉的钱"能按与买卖同一条比例回收一部分。
func enhancement_price_bonus(instance: Dictionary) -> int:
	var template: Dictionary = template_of(str(instance.get("templateId", "")))
	return roundi(float(maxi(0, int(template.get("price", 0)))) * _per_level \
		* float(enhancement(instance)))


func price_bonus(instance: Dictionary) -> int:
	return affix_price_bonus(instance) + enhancement_price_bonus(instance)


## 货架上某件货的**期望**词缀折价：该类别词缀池里每条的平均折价 × 这一档的条数。
##
## 买入侧只能用期望值：货架的报价每次刷新都要一样，不能按当场摇出来的词缀算。
## 成交时摇出的词缀才是实际值，两者口径相同——运气好只是把这份溢价用得更足，
## 不存在"运气好就赚了"的套利（收价仍是一半）。
func typical_affix_price_bonus(template_id: String) -> int:
	var template: Dictionary = template_of(template_id)
	var pool: Array = affix_pool(str(template.get("category", "")))
	if pool.is_empty():
		return 0
	var sum: int = 0
	for affix in pool:
		var entry: Dictionary = affix
		var target: String = str(entry.get("target", ""))
		var average: int = _round_div(
			int(entry.get("minValue", 0)) + int(entry.get("maxValue", 0)), 2
		)
		sum += average * int(_price_per_point.get(target, 0))
	return _round_div(sum, pool.size()) * affix_count(str(template.get("rarity", "")))


# --- 强化 ---

## 升到下一级的成功率（基点）。已到顶返回 0——调用方据此把这一行画成不可动。
func enhancement_chance_bp(instance: Dictionary) -> int:
	var level: int = enhancement(instance)
	if level >= _enhancement_max or level >= _chance_bp.size():
		return 0
	return int(_chance_bp[level])


func enhancement_cost(instance: Dictionary) -> int:
	var level: int = enhancement(instance)
	if level >= _enhancement_max or level >= _cost_ratio.size():
		return 0
	var template: Dictionary = template_of(str(instance.get("templateId", "")))
	var price: int = maxi(1, int(template.get("price", 0)))
	return maxi(1, roundi(float(price) * float(_cost_ratio[level])))


## 这一件现在能不能强化。不能的每一种都给出各自的理由——铁匠铺页脚要写的
## 不是"操作失败"，而是"钱不够"还是"已经到顶"。
func can_enhance(instance: Dictionary, money: int) -> Dictionary:
	if instance.is_empty():
		return _fail(ERROR_NOT_FOUND, "没有这一件东西")
	var template: Dictionary = template_of(str(instance.get("templateId", "")))
	if template.is_empty():
		return _fail(ERROR_NOT_FOUND, "找不到它的模板：%s" % str(instance.get("templateId", "")))
	if not AFFIX_CATEGORIES.has(str(template.get("category", ""))):
		return _fail(ERROR_INVALID_ARGUMENT, "%s 不是能进炉子的东西" % display_name(instance))
	var level: int = enhancement(instance)
	if level >= _enhancement_max:
		return _fail(ERROR_PRECONDITION_FAILED, "「%s」已经强化到顶（+%d）" % [
			display_name(instance), _enhancement_max
		])
	var cost: int = enhancement_cost(instance)
	if money < cost:
		return _fail(ERROR_PRECONDITION_FAILED, "钱不够：这一炉要 %d 铜，你只有 %d 铜" % [
			cost, money
		])
	return {
		"ok": true,
		"errorCode": ERROR_NONE,
		"error": "",
		"cost": cost,
		"chanceBp": enhancement_chance_bp(instance),
	}


## 敲一炉。**就地改传进来的那份实例**（调用方通常是 avatar.item_instances 里
## 的那一份），扣钱与写回由调用方做——与 Economy 同一条边界：钱与背包归玩家自己，
## 但"谁扣钱"只该有一处。
##
## 失败掉一级（0 级不再掉），钱照扣：钱是这一炉的成本，不是买那一级的价格。
## 归零就损毁的写法不在这里——那会让"装备打着打着没了"这种挫折提前出现（D-55）。
func forge(instance: Dictionary, money: int, rng: DeterministicRNG) -> Dictionary:
	var check: Dictionary = can_enhance(instance, money)
	if not check.get("ok", false):
		return check
	var before: int = enhancement(instance)
	var cost: int = int(check.get("cost", 0))
	var chance: int = int(check.get("chanceBp", 0))
	var success: bool = rng != null and rng.next_int(BP_FULL) < chance
	var after: int = before + 1 if success else maxi(0, before - 1)
	instance["enhancement"] = after
	return {
		"ok": true,
		"errorCode": ERROR_NONE,
		"error": "",
		"upgraded": success,
		"levelBefore": before,
		"levelAfter": after,
		"cost": cost,
		"chanceBp": chance,
	}


# --- 内部 ---

func _affix_name(affix_id: String) -> String:
	for entry in _affixes:
		if entry is Dictionary and str((entry as Dictionary).get("affixId", "")) == affix_id:
			return str((entry as Dictionary).get("displayName", affix_id))
	return affix_id


static func _fail(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "errorCode": error_code, "error": message}


## 配置里显式写 null 时 Dictionary.get 的缺省值不生效，所以判型要显式做一次。
static func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array_of(value: Variant) -> Array:
	return value if value is Array else []


## 四舍五入的整数除法（避开浮点，也避开 GDScript 整数除法朝零截断）。
static func _round_div(numerator: int, denominator: int) -> int:
	if denominator == 0:
		return 0
	return int(round(float(numerator) / float(denominator)))
