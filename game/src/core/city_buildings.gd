class_name CityBuildings
extends RefCounted

## 城市建筑实体的纯逻辑（D-69 ~ D-72）。
##
## 建筑是"城市 → 建筑"关系中的独立实体，来源 _City特色建筑与人口设定.md__（8 城各
## 1 地标 + 4 功能，共 40 个）。它由两个正交的部分拼成一个生效等级：
##   - **可用等级 available_level**：由城市阶段与关联维度派生，**不落盘**（与 3.6
##     节、City.tier 同口径）。城市阶段低于存在门槛 → 建筑关闭；否则同档内按关联
##     维度细化出一个 1..(1+maxRefine) 的自然等级。
##   - **投资等级 invested_level**：玩家花钱升级出来的，**必须落盘**——它是玩家
##     私有状态，像传奇航线一样不可由城市状态反推，存在
##     WorldState.building_investments[cityId][buildingId]。
##
## 生效等级 = 可用 + 投资，受全局上限钳制。月度贡献按生效等级折给该城维度（像贸易
## 路线一样折进 deltas）；玩家每月按**投资部分**收钱（城市自然等级不白给玩家钱）。
##
## 本类全部是静态纯函数（配置注入 + `_geti` 缺省回退，风格对齐 DerivedStats），唯一
## 的可变入口是 invest()——它只改 building_investments 与 avatar.money，不动城市六维，
## 因此不经过 applyStateChange。

const ERROR_NONE: String = ""
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_CLOSED: String = "CLOSED"
const ERROR_MAX_LEVEL: String = "MAX_LEVEL"
const ERROR_NO_AVATAR: String = "NO_AVATAR"
const ERROR_INSUFFICIENT_FUNDS: String = "INSUFFICIENT_FUNDS"

## 与 City.Tier 枚举同序（RUINS..METROPOLIS）的配置名，供 minTier 解析与校验。
const TIER_NAMES: Array = ["ruins", "village", "town", "city", "metropolis"]


static func _geti(cfg: Dictionary, key: String, fallback: int) -> int:
	if not cfg.has(key):
		return fallback
	return int(cfg[key])


## 配置里的 tier 名（"city"/"metropolis"）转成 City.Tier 枚举值。未知名回退到 CITY。
static func tier_from_name(name: String) -> int:
	var key: String = str(name).to_lower()
	for i in range(TIER_NAMES.size()):
		if key == str(TIER_NAMES[i]):
			return i
	return City.Tier.CITY


## 建筑的存在门槛。城市阶段低于它则建筑关闭，available 归 0。
static func min_tier(cfg: Dictionary) -> int:
	return tier_from_name(str(cfg.get("minTier", "city")))


## 当前阶段 t 在给定维度上的档下界（0-based 档位的下边缘）。
##
## 城市阶段由发展度与人口共同决定，但只有这两维有阈值表。建筑的存在门槛与细化都
## 锚定 tier，而 tier 主要被发展度驱动，所以发展度档下界对所有非人口维度都适用；
## 人口自己看人口档。档 t 的下界 = 档 t-1 的上限 + 1（档 0 从 0 开始）。
static func _tier_floor(dimension: String, tier: int) -> int:
	if tier <= 0:
		return 0
	var table: Array = (
		City.TIER_POPULATION_MAX
		if dimension == City.DIM_POPULATION
		else City.TIER_DEVELOPMENT_MAX
	)
	return int(table[clampi(tier - 1, 0, table.size() - 1)]) + 1


## 可用等级（派生，不落盘）：
##   city 阶段 < 存在门槛 → 0（建筑关闭/废墟，不贡献、不给玩家收益）
##   否则 1 + clamp(floor((scaleDim - 档下界) / scaleStep), 0, maxRefine)
##
## 那 1 是"建筑存在"本身；超出档下界每 scaleStep 点关联维度再细化一级，
## 封顶 maxRefine。数值放 balance.buildings。
static func available_level(cfg: Dictionary, city: City, balance: Dictionary) -> int:
	if city.get_tier() < min_tier(cfg):
		return 0
	var dimension: String = str(cfg.get("scaleDimension", City.DIM_DEVELOPMENT))
	var floor_dim: int = _tier_floor(dimension, city.get_tier())
	var step: int = maxi(1, _geti(balance, "scaleStep", 10))
	var refine: int = _geti(balance, "maxRefine", 4)
	var raw: int = (city.get_dimension(dimension) - floor_dim) / step
	return 1 + clampi(raw, 0, refine)


## 从世界读玩家在 (cityId, buildingId) 上的投资等级（落盘部分）。
static func invested_level(world: WorldState, city_id: String, building_id: String) -> int:
	var per_city: Dictionary = world.building_investments.get(city_id, {})
	return int(per_city.get(building_id, 0))


## 生效等级 = 可用 + 投资，受全局上限钳制。投资不能无限堆：城市自然撑起来的
## 等级越高，留给玩家投资的空间越小，最终都封在 maxLevel。
static func effective_level(
	cfg: Dictionary, city: City, invested: int, balance: Dictionary
) -> int:
	var avail: int = available_level(cfg, city, balance)
	return clampi(avail + invested, 0, _geti(balance, "maxLevel", 10))


## 本月该建筑给所属城市某维的月度贡献（千分位，milli）。dimensionBonus 是
## {维度: 每级系数}，贡献 = 系数 × 生效等级。返回值形如 {维度名: milli}。
static func monthly_contribution(cfg: Dictionary, effective: int) -> Dictionary:
	var out: Dictionary = {}
	var bonus: Dictionary = cfg.get("dimensionBonus", {})
	for dimension in bonus:
		out[str(dimension)] = int(bonus[dimension]) * effective
	return out


## 投资部分每月带给玩家的铜币收入。只看 invested：城市自然等级不白给玩家钱，
## 否则没投过钱的城也会发钱，玩家收益与经营行为脱钩。
static func player_income(invested: int, balance: Dictionary) -> int:
	return _geti(balance, "playerReturnPerLevel", 300) * invested


## 投资到下一档花的铜币：investCostBase + perLevel × 当前生效等级（档位递增）。
static func invest_cost(balance: Dictionary, current_effective: int) -> int:
	return (
		_geti(balance, "investCostBase", 5000)
		+ _geti(balance, "investCostPerLevel", 2500) * current_effective
	)


## 投资一档：即时扣 avatar.money，并落盘 building_investments。
##
## 投资是玩家私有状态，不是城市六维，所以不经过 applyStateChange——这里直接改
## 世界两份数据：building_investments 与 avatar.money。非破坏性：任何校验失败都
## 不改状态。返回 {ok, error, cost, level}。
static func invest(
	world: WorldState, city_id: String, building_id: String,
	cfg: Dictionary, balance: Dictionary
) -> Dictionary:
	var city: City = world.get_city(city_id)
	if city == null:
		return _fail(ERROR_NOT_FOUND, 0, 0)
	var invested: int = invested_level(world, city_id, building_id)
	if available_level(cfg, city, balance) <= 0:
		return _fail(ERROR_CLOSED, 0, 0)
	var effective: int = effective_level(cfg, city, invested, balance)
	if effective >= _geti(balance, "maxLevel", 10):
		return _fail(ERROR_MAX_LEVEL, 0, effective)
	var cost: int = invest_cost(balance, effective)
	var avatar: PlayerAvatar = world.avatar
	if avatar == null:
		return _fail(ERROR_NO_AVATAR, cost, effective)
	if avatar.money < cost:
		return _fail(ERROR_INSUFFICIENT_FUNDS, cost, effective)
	avatar.money -= cost
	if not world.building_investments.has(city_id):
		world.building_investments[city_id] = {}
	world.building_investments[city_id][building_id] = invested + 1
	return {"ok": true, "error": ERROR_NONE, "cost": cost, "level": invested + 1}


## 失败结果构造。独立成静态函数避免在 invest 里写局部 lambda——局部闭包在引用它的
## 语句处被当作方法调用解析时会报 "fail() not found"，拆出来既消除告警又被测试钉住。
static func _fail(err: String, cost: int, level: int) -> Dictionary:
	return {"ok": false, "error": err, "cost": cost, "level": level}