class_name CityEvolution
extends RefCounted

## 城市六维的月度演化（接口 I-03 的算术部分、《世界模拟量化规则》2.2 节）。
##
## 全部用定点整数运算。设计文档 5.1 节要求如此：`× 0.008` 这类系数若走浮点，
## 1200 次累加后的差异会让钳制结果分叉，同一份存档在两台机器上就长不出同一个
## 世界。系数在构造时一次性转成「千分之一的整数」（0.008 → 8），月度循环里
## 不再出现任何浮点。
##
## 另一处细节是**余数累加器**。单月的人口变化常在 0.4 上下（75 人口的富城约
## +0.44），若每月四舍五入到整数，城市人口会永久停滞在 0 变化——这会让
## 「城市空心化」这类核心现象根本发生不了。因此每个维度保留一个千分位的
## 余数，本月的不足一格留到下月，够一格才落账。
##
## 势力控制（faction）不出现在演化里：2.2 节明确它不由时间自然演化，
## 只由政治事件与玩家操作驱动。它的变化走 applyStateChange。

const SCALE: int = 1000

var _birth: int = 8
var _death: int = 5
var _death_sec: int = 500
var _mig_wealth: int = 2000
var _mig_sec: int = 2000
var _industry: int = 10
var _consumption: int = 6
var _construction: int = 1500
var _dev_decay: int = 500
var _gov_wealth: int = 1000
var _gov_faction: int = 500
var _crime: int = 1000
var _culture_invest: int = 800
var _culture_misfortune: int = 300
var _attract_wealth: int = 400
var _attract_sec: int = 400
var _attract_culture: int = 200


func _init(cfg: Dictionary = {}) -> void:
	_birth = _permille(cfg, "birthRate", 0.008)
	_death = _permille(cfg, "baseDeathRate", 0.005)
	_death_sec = _permille(cfg, "deathSecurityFactor", 0.5)
	_mig_wealth = _permille(cfg, "migrationWealthWeight", 2.0)
	_mig_sec = _permille(cfg, "migrationSecurityWeight", 2.0)
	_industry = _permille(cfg, "industryOutput", 0.01)
	_consumption = _permille(cfg, "consumptionRate", 0.006)
	_construction = _permille(cfg, "constructionRate", 1.5)
	_dev_decay = _permille(cfg, "developmentDecay", 0.5)
	_gov_wealth = _permille(cfg, "governanceWealthWeight", 1.0)
	_gov_faction = _permille(cfg, "governanceFactionWeight", 0.5)
	_crime = _permille(cfg, "crimeWeight", 1.0)
	_culture_invest = _permille(cfg, "cultureInvestment", 0.8)
	_culture_misfortune = _permille(cfg, "cultureMisfortune", 0.3)
	_attract_wealth = _permille(cfg, "attractionWealthWeight", 0.4)
	_attract_sec = _permille(cfg, "attractionSecurityWeight", 0.4)
	_attract_culture = _permille(cfg, "attractionCultureWeight", 0.2)


## 一座城市本月的六维自然变化，逐项拆解，单位为千分之一。
##
## 返回 { 维度 -> [{key, label, milli}] }。拆项不是为了算总数（那是
## monthly_deltas 的事），而是为了回答玩家最想问的那个"为什么"——
## 一座城市的财富在跌，是生产不足、消耗过高，还是商路被断了？只给一个
## 净变化数字，玩家永远只能看着它涨跌而无法归因。
##
## 不含贸易收益（那属于 Economy）与势力控制（只由事件驱动）。
func monthly_breakdown(city: City) -> Dictionary:
	var p: int = city.population
	var w: int = city.wealth
	var d: int = city.development
	var s: int = city.security

	# 人口：出生 - 死亡 + 净移民（2.2 节）
	@warning_ignore("integer_division")
	var birth: int = p * _birth * w / 100
	@warning_ignore("integer_division")
	var sec_term: int = (100 - s) * _death_sec / 100
	@warning_ignore("integer_division")
	var death: int = p * _death * (SCALE + sec_term) / SCALE
	@warning_ignore("integer_division")
	var migration: int = (w - 50) * _mig_wealth / 100 + (s - 50) * _mig_sec / 100

	# 财富：生产 - 消耗（贸易项由 Economy.settleRoutes 结算）
	@warning_ignore("integer_division")
	var production: int = p * _industry * d / 100
	var consumption: int = p * _consumption

	# 发展度：建设 - 损耗
	@warning_ignore("integer_division")
	var construction: int = w * _construction / 100
	@warning_ignore("integer_division")
	var decay: int = (100 - s) * _dev_decay / 100

	# 治安：治理 - 犯罪
	@warning_ignore("integer_division")
	var governance: int = (
		w * _gov_wealth / 100 + city.faction * _gov_faction / 100
	)
	@warning_ignore("integer_division")
	var crime: int = (100 - w) * _crime / 100

	# 文化：投入 - 蒙昧
	@warning_ignore("integer_division")
	var invest: int = w * _culture_invest / 100
	@warning_ignore("integer_division")
	var misfortune: int = (100 - d) * _culture_misfortune / 100

	return {
		City.DIM_POPULATION: [
			_item("birth", "出生", birth),
			_item("death", "死亡", -death),
			_item("migration", "净移民", migration),
		],
		City.DIM_WEALTH: [
			_item("production", "生产", production),
			_item("consumption", "消耗", -consumption),
		],
		City.DIM_DEVELOPMENT: [
			_item("construction", "建设", construction),
			_item("decay", "失修", -decay),
		],
		City.DIM_SECURITY: [
			_item("governance", "治理", governance),
			_item("crime", "犯罪", -crime),
		],
		City.DIM_CULTURE: [
			_item("investment", "文化投入", invest),
			_item("misfortune", "蒙昧", -misfortune),
		],
		City.DIM_FACTION: [],
	}


## 由拆解汇总出的净变化。求和的规则只写在这里一次。
func monthly_deltas(city: City) -> Dictionary:
	var breakdown: Dictionary = monthly_breakdown(city)
	var out: Dictionary = {}
	for dimension in breakdown:
		out[dimension] = sum_items(breakdown[dimension])
	return out


static func sum_items(items: Array) -> int:
	var total: int = 0
	for item in items:
		total += int(item["milli"])
	return total


static func _item(key: String, label: String, milli: int) -> Dictionary:
	return {"key": key, "label": label, "milli": milli}


## 城市吸引力（5.4 节），单位为千分之一。迁移决策只比较这个向量，
## 不做 NPC 两两比较——设计文档 5.2 节按此把快进的复杂度压回线性。
func attractiveness(city: City) -> int:
	@warning_ignore("integer_division")
	var score: int = (
		city.wealth * _attract_wealth / 100
		+ city.security * _attract_sec / 100
		+ city.culture * _attract_culture / 100
	)
	return score


## 把一个千分位增量落账到城市维度上，余数留在城市的演化累加器里。
##
## 钳制时清空该维度的余数：一座已经触顶的城市若把「还想再涨」的余数继续
## 攒着，等条件反转时会凭空多撑几个月才下跌，看起来像数值滞后。
## 返回 {whole, clamped, newValue}。
static func apply_milli(
	city: City, dimension: String, delta_milli: int, min_value: int, max_value: int
) -> Dictionary:
	var carry: int = int(city.evolution_carry.get(dimension, 0)) + delta_milli
	@warning_ignore("integer_division")
	var whole: int = carry / SCALE
	var remainder: int = carry % SCALE

	var before: int = city.get_dimension(dimension)
	var target: int = before + whole
	var clamped_value: int = clampi(target, min_value, max_value)
	var clamped: bool = clamped_value != target
	if clamped:
		remainder = 0
	city.evolution_carry[dimension] = remainder
	city.set_dimension(dimension, clamped_value)
	return {"whole": whole, "clamped": clamped, "newValue": clamped_value}


static func _permille(cfg: Dictionary, key: String, fallback: float) -> int:
	var value: float = float(cfg.get(key, fallback))
	return int(round(value * float(SCALE)))
