class_name TectonicEconomy
extends RefCounted

## 地壳变动下的生意连锁（C-3，中件）。M30 的地壳变动不只换大地图图纸，还连锁
## 撼动经济轴：受扰的城货价上浮（I-12/I-13）、商路断航（I-14）、建筑经营减产
## （D-69~D-72），把「世界记代价」从看得见的地图伸进玩家做买卖的那本账。
##
## 三件事在这里被统一成一个原点：扰动**每城确定性派生、不落盘**。它同源 WorldSeen
## 的纪年折盐（era_seed），所以同一世界同一纪元，受扰的是同一批城、幅度一样——
## 读档回到「离场那一年」就回到同一张扰动图，也守得住「能派生就不落盘」的铁则。
##
## severitity 0 = 不受扰（第 1 年 / 原初纪元恒为 0，新开局零行为变化）。倍率数值
## 全走 balance.tectonicEconomy，这里只留「这城受不受扰、扰多扰少」的规则形状。

const _SALT: int = 0x7B5A9E31


## 纪元换算：由世界累计月数推导派生纪元，与 main.gd 的 `_current_seen_era()`
## （Clock.now().year − 1 = elapsed_months / monthsPerYear）逐位对齐。
## era <= 0 视为原初纪元（第 1 年），经济不受任何扰动。
static func era_for_month(month: int, months_per_year: int) -> int:
	return maxi(0, int(month / maxi(1, months_per_year)))


## 与 WorldSeen.era_seed 同源：同一世界同一纪元逐位一致。
static func era_seed(world_seed: int, era: int) -> int:
	return WorldSeen.era_seed(world_seed, era)


var _severity_max: int = 2
var _disruption_chance: float = 0.3
var _price_factors: Array = [1.0, 1.25, 1.5]
var _yield_factors: Array = [1.0, 0.85, 0.7]


func _init(cfg: Dictionary = {}) -> void:
	_severity_max = maxi(1, int(cfg.get("severityMax", 2)))
	_disruption_chance = clampf(float(cfg.get("disruptionChance", 0.3)), 0.0, 1.0)
	# 倍率表直接按下标==severity 取档（severity 0 = 不受扰 = 1.0）。只需把配置表
	# 规格化到 severity_max+1 档、并把下标 0 钳成 1.0——不要再额外垫一个 1.0 头，
	# 那会按 severity 索引时整体错一位。
	_price_factors = _normalize(cfg.get("priceFactorBySeverity", [1.0, 1.25, 1.5]), _severity_max)
	_yield_factors = _normalize(cfg.get("yieldFactorBySeverity", [1.0, 0.85, 0.7]), _severity_max)


## 把按 severity 索引的倍率表规格化：长度至少 severity_max+1，下标 0（不受扰）恒为 1.0，
## 越界按表尾补。
static func _normalize(arr: Array, severity_max: int) -> Array:
	var out: Array = []
	if arr.is_empty():
		out = [1.0]
	else:
		for i in range(severity_max + 1):
			var v: float = float(arr[i]) if i < arr.size() else float(arr[arr.size() - 1])
			out.append(maxf(0.0, v))
		out[0] = 1.0
	return out


## 这城在本纪元的扰动档（0..severityMax）。**只依赖于 (世界种子⊕纪元⊕城)**，
## 与城在列表里的位置无关——所以 WorldSim（商路/经营）与 Economy/ViewModel（货价）
## 各处都能用同一组入参算出同一个答案，不必共享一份城市清单。
func severity_for(world_seed: int, era: int, city_id: String) -> int:
	if era <= 0:
		return 0
	var base := era_seed(world_seed, era)
	var rng := DeterministicRNG.new(
		(base ^ String(city_id).hash() ^ _SALT) & DeterministicRNG.MASK32
	)
	if not rng.chance(_disruption_chance):
		return 0
	return 1 + rng.next_int(_severity_max)


func price_factor(severity: int) -> float:
	return _factor(_price_factors, severity)


func yield_factor(severity: int) -> float:
	return _factor(_yield_factors, severity)


func is_disrupted(severity: int) -> bool:
	return severity > 0


## 一次取齐的便捷面：给定世界/纪元/城，直接得到受扰与否 + 两档倍率。
## 供 WorldSim 在结算时对若干城批量求值。
func shock_for(world_seed: int, era: int, city_id: String) -> Dictionary:
	var sev: int = severity_for(world_seed, era, city_id)
	return {
		"severity": sev,
		"priceFactor": price_factor(sev),
		"yieldFactor": yield_factor(sev),
	}


static func _factor(factors: Array, severity: int) -> float:
	if factors.is_empty():
		return 1.0
	if severity <= 0:
		return 1.0
	var idx: int = clampi(severity, 0, factors.size() - 1)
	return float(factors[idx])