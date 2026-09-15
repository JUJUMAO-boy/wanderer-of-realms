class_name City
extends RefCounted

## 城市。六个状态维度取自《世界模拟量化规则》第 2.1 节。
##
## 存档只保存**可变状态**（六维、势力归属、城中 NPC 列表）。名称、坐标、
## 是否有黑市渠道这些属于配置，读档时从配置合并回来。这样调整配置不需要
## 迁移存档，也不会出现"存档里留着旧坐标"的问题。
##
## tier（城市阶段）同样是派生值，不落盘：它由发展度与人口决定，落盘会
## 出现"六维更新了但 tier 没更新"的不同步。

const DIM_POPULATION: String = "population"
const DIM_WEALTH: String = "wealth"
const DIM_DEVELOPMENT: String = "development"
const DIM_SECURITY: String = "security"
const DIM_CULTURE: String = "culture"
const DIM_FACTION: String = "faction"

const ALL_DIMENSIONS: Array = [
	DIM_POPULATION, DIM_WEALTH, DIM_DEVELOPMENT, DIM_SECURITY, DIM_CULTURE, DIM_FACTION,
]

const DIMENSION_LABELS: Dictionary = {
	DIM_POPULATION: "人口",
	DIM_WEALTH: "财富",
	DIM_DEVELOPMENT: "发展度",
	DIM_SECURITY: "治安",
	DIM_CULTURE: "文化",
	DIM_FACTION: "势力控制",
}

## 城市阶段，由发展度与人口共同决定（《世界模拟量化规则》3.1）。
enum Tier { RUINS, VILLAGE, TOWN, CITY, METROPOLIS }

const TIER_LABELS: Array = ["废墟", "村落", "城镇", "城市", "大城"]

## 各阶段在单一维度上的**上限**（含）。索引即 Tier。
## 阈值只此一处，判定与"还差多少升阶"的提示都从这里推，避免两处各写一套
## 数字而慢慢对不上。
const TIER_DEVELOPMENT_MAX: Array = [15, 40, 65, 85]
const TIER_POPULATION_MAX: Array = [20, 40, 60, 80]

# --- 配置字段（来自 cities.json，不进存档）---
var city_id: String = ""
var display_name: String = ""
var coord_x: int = 0
var coord_y: int = 0
var has_black_market: bool = false
## 地区溢价（《数值框架》9.3 物价公式的最后一项）。配置字段而非状态：一座城的
## 物价基准不该随六维漂移——六维已经通过供需与治安两个因子进公式了。
var price_premium: float = 1.0

# --- 可变状态（进存档）---
var population: int = 0
var wealth: int = 0
var development: int = 0
var security: int = 0
var culture: int = 0
var faction: int = 0
var dominant_faction_id: String = ""
var npc_ids: Array[String] = []

## 演化余数（千分位，键为维度名）。月度演化与贸易收益算出来的增量常不足 1，
## 余数攒在这里，够一个整数单位才落到六维上。见 CityEvolution 的说明。
var evolution_carry: Dictionary = {}


## 从配置构造。六维初值也来自配置，作为世界开局状态。
static func from_config(cfg: Dictionary) -> City:
	var c := City.new()
	c.city_id = str(cfg.get("cityId", ""))
	c.display_name = str(cfg.get("displayName", c.city_id))
	c.coord_x = int(cfg.get("coordX", 0))
	c.coord_y = int(cfg.get("coordY", 0))
	c.has_black_market = bool(cfg.get("hasBlackMarket", false))
	c.price_premium = float(cfg.get("pricePremium", 1.0))
	c.population = int(cfg.get(DIM_POPULATION, 0))
	c.wealth = int(cfg.get(DIM_WEALTH, 0))
	c.development = int(cfg.get(DIM_DEVELOPMENT, 0))
	c.security = int(cfg.get(DIM_SECURITY, 0))
	c.culture = int(cfg.get(DIM_CULTURE, 0))
	c.faction = int(cfg.get(DIM_FACTION, 0))
	c.dominant_faction_id = str(cfg.get("dominantFactionId", ""))
	return c


func get_dimension(dimension: String) -> int:
	match dimension:
		DIM_POPULATION:
			return population
		DIM_WEALTH:
			return wealth
		DIM_DEVELOPMENT:
			return development
		DIM_SECURITY:
			return security
		DIM_CULTURE:
			return culture
		DIM_FACTION:
			return faction
	return 0


## 直接写入，不做钳制。钳制由世界模拟在每次月度结算后统一执行
## （设计文档 2.3 节：城市状态只有月度结算这一个落账点）。
func set_dimension(dimension: String, value: int) -> void:
	match dimension:
		DIM_POPULATION:
			population = value
		DIM_WEALTH:
			wealth = value
		DIM_DEVELOPMENT:
			development = value
		DIM_SECURITY:
			security = value
		DIM_CULTURE:
			culture = value
		DIM_FACTION:
			faction = value


func clamp_all(min_value: int, max_value: int) -> void:
	for dim in ALL_DIMENSIONS:
		set_dimension(dim, clampi(get_dimension(dim), min_value, max_value))


## 城市阶段 = 发展度所属阶段与人口所属阶段中较低的那个。
## 取较低值而非较高值：一座发展度很高但居民已散尽的城市，应当表现为废墟，
## 而不是继续显示为繁华都市。
func get_tier() -> Tier:
	return mini(_tier_from_development(development), _tier_from_population(population))


func get_tier_label() -> String:
	return TIER_LABELS[get_tier()]


func to_dict() -> Dictionary:
	return {
		"cityId": city_id,
		DIM_POPULATION: population,
		DIM_WEALTH: wealth,
		DIM_DEVELOPMENT: development,
		DIM_SECURITY: security,
		DIM_CULTURE: culture,
		DIM_FACTION: faction,
		"dominantFactionId": dominant_faction_id,
		"npcIds": npc_ids.duplicate(),
		"evolutionCarry": evolution_carry.duplicate(),
	}


## 把存档中的可变状态覆盖到已有对象上。对象必须先由 from_config 构造，
## 以保证配置字段存在。
func apply_dict(data: Dictionary) -> void:
	population = int(data.get(DIM_POPULATION, population))
	wealth = int(data.get(DIM_WEALTH, wealth))
	development = int(data.get(DIM_DEVELOPMENT, development))
	security = int(data.get(DIM_SECURITY, security))
	culture = int(data.get(DIM_CULTURE, culture))
	faction = int(data.get(DIM_FACTION, faction))
	dominant_faction_id = str(data.get("dominantFactionId", dominant_faction_id))
	npc_ids.clear()
	for id in data.get("npcIds", []):
		npc_ids.append(str(id))
	evolution_carry.clear()
	var carry: Dictionary = data.get("evolutionCarry", {})
	for key in carry:
		evolution_carry[str(key)] = int(carry[key])


## 曼哈顿距离（《世界模拟量化规则》9.2）。
func distance_to(other: City) -> int:
	return absi(coord_x - other.coord_x) + absi(coord_y - other.coord_y)


func _tier_from_development(value: int) -> int:
	return _tier_from_threshold(value, TIER_DEVELOPMENT_MAX)


func _tier_from_population(value: int) -> int:
	return _tier_from_threshold(value, TIER_POPULATION_MAX)


static func _tier_from_threshold(value: int, thresholds: Array) -> int:
	for tier in range(thresholds.size()):
		if value <= int(thresholds[tier]):
			return tier
	return Tier.METROPOLIS


## 距离升阶还差多少。返回结构供界面直接展示，不含任何格式化成文字的加工。
##
## 阶段取"发展度档"与"人口档"中较低者，所以升阶条件是**两者同时**够格——
## 只看其中一项会让提示变成空头支票（"发展度够了"但人口还差得远）。
## ratio 用于画进度条，按当前卡住的那一项在其档位区间内的位置计算。
func tier_progress() -> Dictionary:
	var current: int = get_tier()
	if current >= Tier.METROPOLIS:
		return {
			"tier": current,
			"tierLabel": get_tier_label(),
			"nextTier": -1,
			"nextLabel": "",
			"needDevelopment": 0,
			"needPopulation": 0,
			"gapDevelopment": 0,
			"gapPopulation": 0,
			"binding": "",
			"bindingLabel": "",
			"ratio": 1.0,
			"downgradeRisk": false,
		}

	var next_tier: int = current + 1
	var need_development: int = int(TIER_DEVELOPMENT_MAX[current]) + 1
	var need_population: int = int(TIER_POPULATION_MAX[current]) + 1
	var gap_development: int = maxi(0, need_development - development)
	var gap_population: int = maxi(0, need_population - population)

	# 卡住的那一项：差得多的是真瓶颈；一样时以发展度为准（它由财富驱动，
	# 是玩家更容易看见因果链条的那一项）
	var binding: String = DIM_DEVELOPMENT
	var binding_label: String = "发展度"
	var gap: int = gap_development
	if gap_population > gap_development:
		binding = DIM_POPULATION
		binding_label = "人口"
		gap = gap_population

	var lower: int = 0 if current == 0 else int(_threshold_for(binding, current - 1)) + 1
	var upper: int = int(_threshold_for(binding, current))
	var value: int = get_dimension(binding)
	var span: int = maxi(1, upper - lower + 1)
	var ratio: float = clampf(float(value - lower + 1) / float(span), 0.0, 1.0)

	return {
		"tier": current,
		"tierLabel": get_tier_label(),
		"nextTier": next_tier,
		"nextLabel": str(TIER_LABELS[next_tier]),
		"needDevelopment": need_development,
		"needPopulation": need_population,
		"gapDevelopment": gap_development,
		"gapPopulation": gap_population,
		"binding": binding,
		"bindingLabel": binding_label,
		"bindingGap": gap,
		"ratio": ratio,
		"downgradeRisk": value - lower <= 2,
	}


static func _threshold_for(dimension: String, tier: int) -> int:
	var table: Array = TIER_DEVELOPMENT_MAX if dimension == DIM_DEVELOPMENT else TIER_POPULATION_MAX
	return int(table[clampi(tier, 0, table.size() - 1)])
