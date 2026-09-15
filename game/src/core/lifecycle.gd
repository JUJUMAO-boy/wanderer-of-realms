class_name Lifecycle
extends RefCounted

## 寿命与年龄（M9，跨世转生循环的上半截）。
##
## 文档在"一个人能活多久"这件事上只有两句话：《数值框架》2.2 节的种族寿命表
## （人类约 80、精灵约 500……）与返魂者的「灵魂每 20 点维持躯壳约 10 年」。至于
## 「活到几岁算寿终」「几岁算暮年」，一处也没写。本类把它们收成一条可判定的规则，
## 取舍记在《技术设计文档》9.12 节（D-58 / D-60）。
##
##   - 寿命 = race_lifespan × 魂力系数，系数 = clamp(1 + (SOU − base) × perPoint, min, max)
##   - SOU 10 是普通成年的基准，所以普通人正好活到种族寿命那一年，魂力越高越久
##   - 暮年只是界面提示，不参与任何判定；寿终是"当前年龄 ≥ 寿命"
##
## **年龄不落盘，而是从"这一世开始的月份"推算**。理由是快进：按 G 一跳十年，
## 逐年的年龄自增要有人替这十年各加一次，而快进这条路是绕过时钟信号的
## （WorldSim.fast_forward 自己结算）。存一个起点月份、每次要用时现算，
## 无论中间跨了多少年、存读多少次，结果都一样。
##
## 与其它规则类同一条边界：只看玩家自己的寿命与年龄，不碰世界状态。

## 没有起点月份时的哨兵值。读到旧存档（那时还没有这个字段）时用它，
## 此时年龄退回化身自己存的那个数——与这个模块进来之前的行为一致。
const UNSET_MONTH: int = -1

## 没有这段配置时的兜底系数区间，免得配置缺失时把所有人算成寿命 0。
const FALLBACK_FACTOR_MIN: float = 0.5
const FALLBACK_FACTOR_MAX: float = 2.0
const FALLBACK_ELDER_RATIO: float = 0.8
const FALLBACK_LIFESPAN: int = 80

var _cfg: Dictionary = {}
var _lifespans: Dictionary = {}


static func create() -> Lifecycle:
	return Lifecycle.new(
		ContentLoader.get_balance_section("lifecycle"),
		ContentLoader.race_lifespans()
	)


func _init(cfg: Dictionary = {}, lifespans: Dictionary = {}) -> void:
	_cfg = cfg
	_lifespans = lifespans


# --- 寿命 ---

## 魂力系数。SOU 低于基准会短命，但不会低到活不完一个童年——这就是下限存在的理由。
func soul_factor(soul_value: int) -> float:
	var base: int = int(_cfg.get("soulFactorBase", 10))
	var per_point: float = float(_cfg.get("soulFactorPerPoint", 0.005))
	var low: float = float(_cfg.get("soulFactorMin", FALLBACK_FACTOR_MIN))
	var high: float = float(_cfg.get("soulFactorMax", FALLBACK_FACTOR_MAX))
	if low > high:
		low = high
	return clampf(1.0 + float(soul_value - base) * per_point, low, high)


## 这个种族的寿命上限。种族没有配置寿命时退回一个保底值——拼错一个 raceId
## 不该让人一出生就寿终。
func lifespan(race_id: String, soul_value: int) -> int:
	var base: int = int(_lifespans.get(race_id, 0))
	if base <= 0:
		base = int(_cfg.get("fallbackLifespan", FALLBACK_LIFESPAN))
	return maxi(1, roundi(float(base) * soul_factor(soul_value)))


## 化身这一世的寿命上限。读的是**当前**的魂力——魂力是灵魂的属性，随这一世成长，
## 所以寿命不是一个出生就定死的数。
func lifespan_of(avatar: PlayerAvatar) -> int:
	if avatar == null:
		return int(_cfg.get("fallbackLifespan", FALLBACK_LIFESPAN))
	return lifespan(avatar.race, avatar.get_attribute(PlayerAvatar.ATTR_SOUL))


# --- 年龄 ---

## 从起点月份推算当前年龄。整年才加一岁（月龄不足一年不算）。
func age_at(start_age: int, start_month: int, now_month: int) -> int:
	if start_month == UNSET_MONTH:
		return start_age
	@warning_ignore("integer_division")
	var years: int = (now_month - start_month) / 12
	return start_age + maxi(0, years)


func current_age(avatar: PlayerAvatar, now_month: int) -> int:
	if avatar == null:
		return 0
	# 旧存档没有起点：age 就是它自己那个数，与这个模块进来之前一致
	if avatar.life_start_month == PlayerAvatar.LIFE_START_UNSET:
		return avatar.age
	var start_age: int = avatar.life_start_age if avatar.life_start_age > 0 else avatar.age
	return age_at(start_age, avatar.life_start_month, now_month)


## 这一世已经活了几个月。享年写"活了 37 年"时要的就是它。
func months_lived(avatar: PlayerAvatar, now_month: int) -> int:
	if avatar == null or avatar.life_start_month == UNSET_MONTH:
		return 0
	return maxi(0, now_month - avatar.life_start_month)


# --- 暮年与寿终 ---

func elder_ratio() -> float:
	return float(_cfg.get("elderRatio", FALLBACK_ELDER_RATIO))


func elder_age(lifespan_value: int) -> int:
	return maxi(1, int(ceil(float(lifespan_value) * elder_ratio())))


func is_elder(age: int, lifespan_value: int) -> bool:
	return age >= elder_age(lifespan_value)


## 还剩几年。已经过了寿命线就是 0，不返回负数。
func remaining_years(age: int, lifespan_value: int) -> int:
	return maxi(0, lifespan_value - age)


func has_reached(age: int, lifespan_value: int) -> bool:
	return age >= lifespan_value


## 这一世应当寿终的月份。起点月份未知（旧存档）时返回 -1。
##
## 它的用处是让快进十年的那一跳不撒谎：跳过十年之后才发现的寿终，
## 真正发生在半路上，档案里该记的是那个月，不是发现它的那个月。
func death_month(start_age: int, start_month: int, lifespan_value: int) -> int:
	if start_month == UNSET_MONTH:
		return UNSET_MONTH
	return start_month + maxi(0, lifespan_value - start_age) * 12
